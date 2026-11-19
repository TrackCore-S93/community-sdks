import type { Runtime } from "./runtime.js";

/** A fetch function. The global `fetch` fits. */
export type FetchLike = (input: string, init?: RequestInit) => Promise<Response>;

/** Where a warning goes. `console.warn` fits. */
export type Warn = (message: string) => void;

/** When a failed attempt is tried again. */
export interface RetryPolicy {
  /** The most attempts one call makes, the first included. 1 never retries. */
  maxAttempts: number;
  /** The most attempts for a 502, the first included. 1 never retries one. */
  max502Attempts: number;
  /** The first backoff, in milliseconds. It doubles each attempt. */
  baseDelayMs: number;
  /** The longest backoff, in milliseconds. */
  maxDelayMs: number;
}

/** The retry policy used when none is given. */
export const DEFAULT_RETRY_POLICY: Readonly<RetryPolicy> = Object.freeze({
  maxAttempts: 3,
  max502Attempts: 2,
  baseDelayMs: 250,
  maxDelayMs: 4000,
});

/** What happened inside a call. Never carries a key or a session token. */
export type Diagnostic =
  | { type: "retry"; method: string; path: string; attempt: number; delayMs: number; reason: string }
  | { type: "session_minted"; externalId: string; expiresAt: string }
  | { type: "session_renewed"; externalId: string; expiresAt: string }
  | { type: "session_ended" }
  | { type: "live"; status: "connecting" | "open" | "closed" | "reconnecting"; attempt: number };

/** How a client is built. The same options work for `configure` and `new Community`. */
export interface CommunityOptions {
  /** A `cm_sk_…` key on a server, a `cm_pk_…` key in an app or a browser. Falls back to COMMUNITY_API_KEY. */
  apiKey?: string;
  /** Where the API answers. Falls back to COMMUNITY_BASE_URL, then https://api.community.trackcore.app. */
  baseUrl?: string;
  /** How long a session minted by `initialize` lives, 60 to 86400 seconds. 86400 by default. */
  sessionTtlSeconds?: number;
  /** The time allowed for one attempt, in milliseconds. 10 000 by default. */
  timeoutMs?: number;
  /** The time allowed for the whole call, retries and backoff included. 30 000 by default. */
  deadlineMs?: number;
  /** Partial overrides of the retry policy. */
  retry?: Partial<RetryPolicy>;
  /** A fetch to use instead of the global one. */
  fetch?: FetchLike;
  /** Extra headers on every request. Cannot override Authorization or the user headers. */
  headers?: Record<string, string>;
  /** Called with retry, session and live events. Never receives a credential. */
  onDiagnostic?: (diagnostic: Diagnostic) => void;
  /** Where a warning goes. `console.warn` by default. */
  warn?: Warn;
  /** Opens a WebSocket for live updates. Needed only where the runtime's own cannot send headers. */
  webSocket?: WebSocketFactory;
  /** Overrides runtime detection. For SDKs built on this one. */
  runtime?: Runtime;
}

/** Options every call takes. */
export interface CallOptions {
  /** An AbortSignal. When it fires the call rejects with AbortError. */
  signal?: AbortSignal;
}

/** The part of a WebSocket the SDK uses. */
export interface WebSocketLike {
  onopen: ((event: unknown) => void) | null;
  onmessage: ((event: { data: unknown }) => void) | null;
  onclose: ((event: unknown) => void) | null;
  onerror: ((event: unknown) => void) | null;
  send(data: string): void;
  close(code?: number, reason?: string): void;
}

/** Opens a WebSocket to `url` with the given request headers. */
export type WebSocketFactory = (url: string, headers: Record<string, string>) => WebSocketLike;
