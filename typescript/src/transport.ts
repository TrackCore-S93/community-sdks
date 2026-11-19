import {
  AbortError,
  ConfigurationError,
  ConnectionError,
  ProtocolError,
  TimeoutError,
  apiErrorFor,
  isErrorCode,
  type CommunityAPIError,
} from "./errors.js";
import { DEFAULT_RETRY_POLICY, type CommunityOptions, type Diagnostic, type FetchLike, type RetryPolicy, type Warn } from "./options.js";
import { detectRuntime, env, type Runtime } from "./runtime.js";
import type { Session } from "./generated/types.js";

export const DEFAULT_BASE_URL = "https://api.community.trackcore.app";
export const SESSION_HEADER = "X-Community-Session";
export const EXTERNAL_ID_HEADER = "X-External-Id";
export const IDEMPOTENCY_HEADER = "Idempotency-Key";
export const MAX_EXTERNAL_ID_LENGTH = 255;
const MAX_SESSION_TTL = 86_400;
const MIN_SESSION_TTL = 60;
/** A session this close to its end is renewed before it is used. */
const RENEW_WITHIN_MS = 60_000;

const KEY_SHAPE = /^cm_(sk|pk)_(live|test)_[A-Za-z0-9_-]{8,}$/;
const SESSION_SHAPE = /^cm_st_[A-Za-z0-9_-]{43}$/;

/** Who a request acts for, which decides the headers it carries. */
export type Audience = "any_key" | "member" | "creator" | "member_or_creator" | "session";

/** One request, as a namespace describes it. */
export interface RequestSpec {
  method: "GET" | "POST" | "PUT" | "PATCH" | "DELETE";
  path: string;
  audience: Audience;
  query?: Record<string, string | number | boolean | undefined | null>;
  body?: unknown;
  idempotencyKey?: string;
  /** True when sending this request twice has the same effect as sending it once. */
  repeatable?: boolean;
  signal?: AbortSignal;
}

/** Checks a user id against the API's rule, so a bad one fails here and not on the server. */
export function assertValidExternalId(externalId: string): void {
  if (typeof externalId !== "string" || externalId === "") {
    throw new ConfigurationError("external_id_empty", "The user id is empty.");
  }
  if (externalId !== externalId.trim()) {
    throw new ConfigurationError("external_id_untrimmed", "The user id has leading or trailing spaces.");
  }
  if (new TextEncoder().encode(externalId).length > MAX_EXTERNAL_ID_LENGTH) {
    throw new ConfigurationError("external_id_too_long", `The user id is longer than ${MAX_EXTERNAL_ID_LENGTH} bytes.`);
  }
}

const sleep = (ms: number, signal?: AbortSignal): Promise<void> =>
  new Promise((resolve, reject) => {
    if (signal?.aborted) return reject(new AbortError());
    const timer = setTimeout(() => {
      signal?.removeEventListener("abort", onAbort);
      resolve();
    }, ms);
    const onAbort = (): void => {
      clearTimeout(timer);
      reject(new AbortError());
    };
    signal?.addEventListener("abort", onAbort, { once: true });
  });

function positive(name: string, value: number | undefined, fallback: number): number {
  if (value === undefined) return fallback;
  if (!Number.isFinite(value) || value <= 0) {
    throw new ConfigurationError("option_invalid", `${name} must be a positive number.`);
  }
  return value;
}

/**
 * The request layer: one place that knows the key, who the user is, when to
 * retry and how to read a reply. The key is held in a closure and is not
 * reachable from the object, so it cannot leak through JSON.stringify or an
 * error reporter walking the object graph.
 */
export class Transport {
  readonly baseUrl: string;
  readonly environment: "live" | "test";
  readonly keyKind: "secret" | "publishable";
  readonly runtime: Runtime;
  readonly timeoutMs: number;
  readonly deadlineMs: number;
  readonly retry: Readonly<RetryPolicy>;
  readonly sessionTtlSeconds: number;

  readonly #authorize: (headers: Record<string, string>) => void;
  readonly #masked: string;
  readonly #fetch: FetchLike;
  readonly #extraHeaders: Record<string, string>;
  readonly #diagnostic: ((d: Diagnostic) => void) | undefined;
  readonly warn: Warn;

  #externalId: string | null = null;
  #session: { token: string; expiresAt: number | null; owned: boolean } | null = null;
  #minting: Promise<void> | null = null;

  constructor(options: CommunityOptions = {}) {
    const apiKey = options.apiKey ?? env("COMMUNITY_API_KEY");
    if (!apiKey) {
      throw new ConfigurationError("api_key_missing", "No API key. Pass apiKey, or set COMMUNITY_API_KEY.");
    }
    const shape = KEY_SHAPE.exec(apiKey);
    if (!shape) {
      throw new ConfigurationError("api_key_malformed", "The API key is not a Community key (cm_sk_… or cm_pk_…).");
    }
    this.keyKind = shape[1] === "sk" ? "secret" : "publishable";
    this.environment = shape[2] as "live" | "test";
    this.#masked = `${apiKey.slice(0, apiKey.indexOf("_", 6) + 1)}…${apiKey.slice(-3)}`;
    this.warn = options.warn ?? ((message) => console.warn(message));
    this.runtime = options.runtime ?? detectRuntime();

    if (this.keyKind === "secret") {
      if (this.runtime === "browser" || this.runtime === "react-native") {
        throw new ConfigurationError(
          "secret_key_in_browser",
          `A Community secret key (${this.#masked}) was used in ${this.runtime === "browser" ? "a browser" : "an app"}. ` +
            "Anything shipped to a device is readable by whoever holds it, so this key must be treated as compromised: " +
            "revoke it and issue a new one. Use a publishable key (cm_pk_…) here.",
        );
      }
      if (this.runtime === "unknown") {
        this.warn(
          `A Community secret key (${this.#masked}) is in use in a runtime this SDK does not recognise. ` +
            "A secret key belongs on a server only. Set COMMUNITY_RUNTIME=server to confirm.",
        );
      }
    }

    const rawBase = options.baseUrl ?? env("COMMUNITY_BASE_URL") ?? DEFAULT_BASE_URL;
    let parsed: URL;
    try {
      parsed = new URL(rawBase);
    } catch {
      throw new ConfigurationError("base_url_invalid", "baseUrl is not a URL.");
    }
    if (parsed.protocol !== "https:" && parsed.protocol !== "http:") {
      throw new ConfigurationError("base_url_invalid", "baseUrl must start with https:// or http://.");
    }
    this.baseUrl = `${parsed.origin}${parsed.pathname.replace(/\/+$/, "")}`;

    this.timeoutMs = positive("timeoutMs", options.timeoutMs, 10_000);
    this.deadlineMs = positive("deadlineMs", options.deadlineMs, 30_000);
    const retry = { ...DEFAULT_RETRY_POLICY, ...options.retry };
    for (const [name, value] of Object.entries(retry)) {
      if (!Number.isFinite(value) || value < (name.endsWith("Attempts") ? 1 : 0)) {
        throw new ConfigurationError("option_invalid", `retry.${name} is not valid.`);
      }
    }
    this.retry = Object.freeze(retry);
    const ttl = options.sessionTtlSeconds ?? MAX_SESSION_TTL;
    if (!Number.isInteger(ttl) || ttl < MIN_SESSION_TTL || ttl > MAX_SESSION_TTL) {
      throw new ConfigurationError("option_invalid", `sessionTtlSeconds must be between ${MIN_SESSION_TTL} and ${MAX_SESSION_TTL}.`);
    }
    this.sessionTtlSeconds = ttl;

    const fetchImpl = options.fetch ?? (globalThis.fetch as FetchLike | undefined);
    if (typeof fetchImpl !== "function") {
      throw new ConfigurationError("option_invalid", "No fetch is available. Pass one as the fetch option.");
    }
    this.#fetch = options.fetch ? fetchImpl : (input, init) => fetchImpl(input, init);
    this.#extraHeaders = { ...options.headers };
    this.#diagnostic = options.onDiagnostic;
    this.#authorize = (headers) => {
      headers["Authorization"] = `Bearer ${apiKey}`;
    };
  }

  /** The fetch in use, for requests that go somewhere other than the API (a file to storage). */
  get fetch(): FetchLike {
    return this.#fetch;
  }

  /** The key, masked: safe to log. */
  describeCredential(): string {
    return this.#masked;
  }

  /** The user requests act for, or null. */
  get externalId(): string | null {
    return this.#externalId;
  }

  /** The session token in use, or null. */
  get sessionToken(): string | null {
    return this.#session?.token ?? null;
  }

  emit(diagnostic: Diagnostic): void {
    try {
      this.#diagnostic?.(diagnostic);
    } catch {
      // A diagnostic listener must never break a call.
    }
  }

  /** Names the user every later request acts for. No network call. */
  setUser(externalId: string): void {
    assertValidExternalId(externalId);
    this.#externalId = externalId;
  }

  clearUser(): void {
    this.#externalId = null;
  }

  /** Carries a session token minted elsewhere (by your backend). */
  setSession(sessionToken: string): void {
    if (typeof sessionToken !== "string" || !SESSION_SHAPE.test(sessionToken)) {
      throw new ConfigurationError("session_token_malformed", "That is not a Community session token (cm_st_…).");
    }
    this.#session = { token: sessionToken, expiresAt: null, owned: false };
  }

  clearSession(): void {
    this.#session = null;
  }

  /**
   * Signs a user in. With a secret key this names the user and mints
   * nothing. With a publishable key it mints a session for them, which is
   * then renewed when it nears its end.
   */
  async initialize(externalId: string, signal?: AbortSignal): Promise<void> {
    assertValidExternalId(externalId);
    this.#externalId = externalId;
    if (this.keyKind === "secret") {
      this.#session = null;
      return;
    }
    await this.#mint("session_minted", signal);
  }

  /** Ends the session on the server, where there is one, and forgets the user. */
  async signOut(signal?: AbortSignal): Promise<void> {
    const session = this.#session;
    this.#session = null;
    this.#externalId = null;
    if (session && this.keyKind === "publishable") {
      try {
        await this.#send({ method: "DELETE", path: "/v1/auth/session", audience: "any_key", signal }, {
          [SESSION_HEADER]: session.token,
        });
      } catch {
        // The session ends by itself; signing out must not fail because the network did.
      }
      this.emit({ type: "session_ended" });
    }
  }

  #mint(event: "session_minted" | "session_renewed", signal?: AbortSignal): Promise<void> {
    // One mint at a time: calls that arrive together wait for the same one.
    this.#minting ??= (async () => {
      const externalId = this.#externalId;
      if (externalId === null) throw new ConfigurationError("no_user", "No user is signed in. Call initialize(userId) first.");
      try {
        const session = await this.#send<Session>({
          method: "POST",
          path: "/v1/auth/session",
          audience: "any_key",
          body: { external_id: externalId, ttl_seconds: this.sessionTtlSeconds },
          signal,
        });
        // Signed out, or signed in as someone else, while this was in flight.
        if (this.#externalId !== externalId) return;
        this.#session = { token: session.token, expiresAt: Date.parse(session.expires_at), owned: true };
        this.emit({ type: event, externalId, expiresAt: session.expires_at });
      } finally {
        this.#minting = null;
      }
    })();
    return this.#minting;
  }

  /** The headers that say who a request acts for. Throws when the client cannot make this call. */
  async #identity(audience: Audience, signal?: AbortSignal): Promise<Record<string, string>> {
    if (audience === "any_key") return {};
    if (audience === "creator") {
      if (this.keyKind !== "secret") {
        throw new ConfigurationError("secret_key_required", "This call needs a secret key and belongs on your backend.");
      }
      return {};
    }
    if (this.keyKind === "secret") {
      if (this.#externalId !== null) return { [EXTERNAL_ID_HEADER]: this.#externalId };
      if (audience === "member_or_creator") return {};
      throw new ConfigurationError("no_user", "No user is named. Call initialize(userId) or setUser(userId) first.");
    }
    const session = this.#session;
    if (!session) {
      throw new ConfigurationError("no_user", "No user is signed in. Call initialize(userId) first.");
    }
    if (session.owned && session.expiresAt !== null && session.expiresAt - Date.now() < RENEW_WITHIN_MS) {
      await this.#mint("session_renewed", signal);
    }
    return { [SESSION_HEADER]: (this.#session ?? session).token };
  }

  /** The headers a live connection opens with. */
  async liveHeaders(signal?: AbortSignal): Promise<Record<string, string>> {
    const headers: Record<string, string> = { ...(await this.#identity("member_or_creator", signal)) };
    this.#authorize(headers);
    return headers;
  }

  /** Makes a request for a namespace: identity, retries, and one renewal of an expired session. */
  async request<T>(spec: RequestSpec): Promise<T> {
    const identity = await this.#identity(spec.audience, spec.signal);
    try {
      return await this.#send<T>(spec, identity);
    } catch (error) {
      const expired = (error as CommunityAPIError | undefined)?.code === "session_invalid";
      if (!expired || !this.#session?.owned || this.keyKind !== "publishable") throw error;
      // The session this SDK minted has ended early. Mint another, once.
      await this.#mint("session_renewed", spec.signal);
      return this.#send<T>(spec, await this.#identity(spec.audience, spec.signal));
    }
  }

  async #send<T>(spec: RequestSpec, identity: Record<string, string> = {}): Promise<T> {
    const url = new URL(this.baseUrl + spec.path);
    for (const [name, value] of Object.entries(spec.query ?? {})) {
      if (value !== undefined && value !== null && value !== "") url.searchParams.set(name, String(value));
    }
    const headers: Record<string, string> = { ...this.#extraHeaders, Accept: "application/json", ...identity };
    let body: string | undefined;
    if (spec.body !== undefined) {
      headers["Content-Type"] = "application/json";
      body = JSON.stringify(spec.body);
    }
    if (spec.idempotencyKey !== undefined) headers[IDEMPOTENCY_HEADER] = spec.idempotencyKey;
    this.#authorize(headers);

    // A request that writes is repeated only when repeating it is safe.
    const repeatable =
      (spec.method !== "POST" && spec.method !== "PATCH") || spec.idempotencyKey !== undefined || spec.repeatable === true;
    const deadline = Date.now() + this.deadlineMs;
    let attempt = 0;
    let seen502 = 0;
    for (;;) {
      attempt++;
      if (spec.signal?.aborted) throw new AbortError();
      const remaining = deadline - Date.now();
      if (remaining <= 0) throw new TimeoutError("deadline", `The call did not finish within ${this.deadlineMs} ms.`);

      // One attempt ends in a reply to return, an error to give up with, or
      // an error worth another attempt.
      let failure: Error;
      let retryAfterMs: number | null = null;
      let reason: string;
      let response: Response | null = null;
      try {
        response = await this.#attempt(url.toString(), spec.method, headers, body, Math.min(this.timeoutMs, remaining), spec.signal);
      } catch (error) {
        const transient = error instanceof ConnectionError || (error instanceof TimeoutError && error.kind === "attempt");
        // Nothing came back, so the server may or may not have acted: a
        // request that is not safe to repeat stops here.
        if (!transient || !repeatable) throw error;
        failure = error as Error;
        reason = error instanceof TimeoutError ? "timeout" : "connection";
      }
      if (response !== null) {
        if (response.ok) return (await this.#read<T>(response)) as T;
        const status = response.status;
        const error = await this.#failure(response);
        if (status === 502) seen502++;
        const retryableStatus =
          status === 408 || status === 429 || status === 503 || status === 504 || (status === 502 && seen502 < this.retry.max502Attempts);
        if (!retryableStatus || !repeatable) throw error;
        failure = error;
        reason = `http_${status}`;
        // Retry-After wins over the schedule, with the envelope's own value
        // as the fallback for a proxy that stripped the header.
        const header = Number(response.headers.get("Retry-After"));
        const fromBody = (error as CommunityAPIError).retryAfterSeconds ?? null;
        retryAfterMs = Number.isFinite(header) && header > 0 ? header * 1000 : fromBody !== null ? fromBody * 1000 : null;
      }

      if (attempt >= this.retry.maxAttempts) throw failure!;
      const ceiling = Math.min(this.retry.maxDelayMs, this.retry.baseDelayMs * 2 ** (attempt - 1));
      const delayMs = retryAfterMs ?? Math.random() * ceiling; // full jitter
      if (Date.now() + delayMs >= deadline) throw failure!;
      this.emit({ type: "retry", method: spec.method, path: spec.path, attempt, delayMs: Math.round(delayMs), reason: reason! });
      await sleep(delayMs, spec.signal);
    }
  }

  async #attempt(
    url: string,
    method: string,
    headers: Record<string, string>,
    body: string | undefined,
    timeoutMs: number,
    signal: AbortSignal | undefined,
  ): Promise<Response> {
    const controller = new AbortController();
    let timedOut = false;
    const timer = setTimeout(() => {
      timedOut = true;
      controller.abort();
    }, timeoutMs);
    const onAbort = (): void => controller.abort();
    signal?.addEventListener("abort", onAbort, { once: true });
    try {
      return await this.#fetch(url, { method, headers, body, signal: controller.signal });
    } catch (error) {
      if (signal?.aborted) throw new AbortError();
      if (timedOut) throw new TimeoutError("attempt", `No reply within ${timeoutMs} ms.`);
      throw new ConnectionError("The API could not be reached.", { cause: error });
    } finally {
      clearTimeout(timer);
      signal?.removeEventListener("abort", onAbort);
    }
  }

  async #read<T>(response: Response): Promise<T | undefined> {
    if (response.status === 204) return undefined;
    const text = await response.text();
    if (text === "") return undefined;
    try {
      return JSON.parse(text) as T;
    } catch {
      throw new ProtocolError(response.status, text);
    }
  }

  /** Turns a non-2xx reply into a typed error. Nothing from an unrecognised body reaches the message. */
  async #failure(response: Response): Promise<Error> {
    const text = await response.text().catch(() => "");
    let parsed: unknown;
    try {
      parsed = JSON.parse(text);
    } catch {
      return new ProtocolError(response.status, text);
    }
    const body = (parsed as { error?: Record<string, unknown> } | null)?.error;
    if (!body || !isErrorCode(body["code"]) || typeof body["message"] !== "string") {
      return new ProtocolError(response.status, text);
    }
    const fields = body["fields"];
    const retryAfter = body["retry_after_seconds"];
    return apiErrorFor({
      code: body["code"],
      status: response.status,
      message: body["message"],
      requestId: typeof body["request_id"] === "string" ? body["request_id"] : null,
      fields: fields && typeof fields === "object" ? (fields as Record<string, string>) : null,
      retryAfterSeconds: typeof retryAfter === "number" ? retryAfter : null,
    });
  }
}
