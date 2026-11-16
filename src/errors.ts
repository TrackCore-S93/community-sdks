import { ALL_ERROR_CODES, ERROR_CODE_SPECS, type CommunityErrorCode, type ErrorCodeSpec } from "./generated/errors.js";

/** Where an error code is explained. */
export const DOCS_ERRORS_URL = "https://community.trackcore.app/developer/guide/errors";

/** The root of every error this SDK throws. */
export class CommunityError extends Error {
  constructor(message: string) {
    super(message);
    this.name = new.target.name;
  }
}

/** What the server's error envelope carries. */
export interface APIErrorInit {
  code: CommunityErrorCode;
  status: number;
  message: string;
  requestId: string | null;
  fields: Record<string, string> | null;
  retryAfterSeconds: number | null;
}

/**
 * A non-2xx reply from the API. `code` is one of a closed list: branch on it,
 * never on `message`.
 */
export class CommunityAPIError extends CommunityError {
  /** Which problem this is. */
  readonly code: CommunityErrorCode;
  /** The HTTP status. */
  readonly status: number;
  /** A reference for this request, to quote when reporting a problem. */
  readonly requestId: string | null;
  /** For `validation_failed`: each field that failed, and why. */
  readonly fields: Readonly<Record<string, string>> | null;
  /** How long the server asked the caller to wait, when it said. */
  readonly retryAfterSeconds: number | null;
  /** Where this code is explained. */
  readonly docsUrl: string;

  constructor(init: APIErrorInit) {
    super(init.message);
    this.code = init.code;
    this.status = init.status;
    this.requestId = init.requestId;
    this.fields = init.fields;
    this.retryAfterSeconds = init.retryAfterSeconds;
    this.docsUrl = `${DOCS_ERRORS_URL}#${init.code}`;
  }
}

/** 400, 405, 413: the request itself was not acceptable. */
export class RequestError extends CommunityAPIError {}
/** 401: the key or the session is missing, malformed, unknown, revoked or expired. */
export class AuthenticationError extends CommunityAPIError {}
/** 403: the caller is known but may not do this. */
export class AuthorizationError extends CommunityAPIError {}
/** 404, 409, 422: the thing named does not exist, conflicts, or the values are not valid. */
export class ResourceError extends CommunityAPIError {}
/** 429: too many requests. */
export class RateLimitError extends CommunityAPIError {}
/** 500: a defect on the server. */
export class ServerError extends CommunityAPIError {}
/** 502, 504: something the server depends on failed or took too long. */
export class DependencyError extends CommunityAPIError {}
/** 503: the service is temporarily unavailable. */
export class MaintenanceError extends CommunityAPIError {}

/** Builds the right class for an HTTP status. */
export function apiErrorFor(init: APIErrorInit): CommunityAPIError {
  switch (init.status) {
    case 401: return new AuthenticationError(init);
    case 403: return new AuthorizationError(init);
    case 404: case 409: case 410: case 422: return new ResourceError(init);
    case 429: return new RateLimitError(init);
    case 500: return new ServerError(init);
    case 502: case 504: return new DependencyError(init);
    case 503: return new MaintenanceError(init);
    default: return init.status >= 500 ? new ServerError(init) : new RequestError(init);
  }
}

/** Errors raised by the SDK itself, before or instead of a reply from the API. */
export class CommunityClientError extends CommunityError {}

/** Why a client could not be built or used as asked. */
export type ConfigurationReason =
  | "api_key_missing"
  | "api_key_malformed"
  | "secret_key_in_browser"
  | "secret_key_required"
  | "base_url_invalid"
  | "option_invalid"
  | "not_configured"
  | "no_user"
  | "external_id_empty"
  | "external_id_untrimmed"
  | "external_id_too_long"
  | "session_token_malformed"
  | "live_unsupported";

/** A bad key, a bad base URL, a bad user id, or a call the key cannot make. `reason` says which. */
export class ConfigurationError extends CommunityClientError {
  constructor(readonly reason: ConfigurationReason, message: string) {
    super(message);
  }
}

/** An argument that breaks a published limit, caught before anything is sent. */
export class ValidationError extends CommunityClientError {
  constructor(readonly field: string, message: string) {
    super(message);
  }
}

/** DNS, TLS, connection refused, offline: nothing came back. */
export class ConnectionError extends CommunityClientError {
  constructor(message: string, options?: { cause?: unknown }) {
    super(message);
    if (options?.cause !== undefined) (this as { cause?: unknown }).cause = options.cause;
  }
}

/** One attempt ran out of time, or the whole call passed its deadline. */
export class TimeoutError extends CommunityClientError {
  constructor(readonly kind: "attempt" | "deadline", message: string) {
    super(message);
  }
}

/** The caller's own AbortSignal fired. */
export class AbortError extends CommunityClientError {
  constructor(message = "The request was aborted.") {
    super(message);
  }
}

/** The reply was not something this API sends: a proxy's page, a captive portal. */
export class ProtocolError extends CommunityClientError {
  readonly status: number;
  constructor(status: number, bodySample: string) {
    super(`The reply (HTTP ${status}) was not a Community API response.`);
    this.status = status;
    // Kept off the enumerable surface: there when asked for by name, absent
    // from JSON.stringify(error) and from loggers that walk the object.
    Object.defineProperty(this, "bodySample", { value: bodySample.slice(0, 2048), enumerable: false });
  }
  declare readonly bodySample: string;
}

/** True for any error thrown by this SDK. */
export function isCommunityError(error: unknown): error is CommunityError {
  return error instanceof CommunityError;
}

/** True for a non-2xx reply from the API. */
export function isAPIError(error: unknown): error is CommunityAPIError {
  return error instanceof CommunityAPIError;
}

/** True when the error is an API error with exactly this code. */
export function isErrorOfCode<C extends CommunityErrorCode>(
  error: unknown,
  code: C,
): error is CommunityAPIError & { code: C } {
  return error instanceof CommunityAPIError && error.code === code;
}

/** True when `value` is one of the API's error codes. */
export function isErrorCode(value: unknown): value is CommunityErrorCode {
  return typeof value === "string" && (ALL_ERROR_CODES as readonly string[]).includes(value);
}

/** The API's own description of a code: its status, default message and whether a retry can succeed. */
export function errorCodeSpec(code: CommunityErrorCode): ErrorCodeSpec {
  return ERROR_CODE_SPECS[code];
}

export { ALL_ERROR_CODES, type CommunityErrorCode, type ErrorCodeSpec };
