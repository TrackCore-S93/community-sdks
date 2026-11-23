// GENERATED from contract/openapi.yaml by scripts/generate.mjs. Do not edit.

/** Every error code the API can answer with. */
export const ALL_ERROR_CODES = [
  "invalid_request",
  "ambiguous_credentials",
  "unauthenticated",
  "credential_missing",
  "credential_malformed",
  "credential_unknown",
  "credential_revoked",
  "session_invalid",
  "user_scope_violation",
  "forbidden",
  "not_found",
  "method_not_allowed",
  "conflict",
  "username_taken",
  "already_joined",
  "community_join_required",
  "comment_replies_disabled",
  "profile_viewing_disabled",
  "coach_chat_disabled",
  "topic_name_taken",
  "media_not_uploaded",
  "media_too_large",
  "media_invalid",
  "payload_too_large",
  "validation_failed",
  "rate_limited",
  "internal_error",
  "service_unavailable",
  "timeout"
] as const;

/** One of the API's error codes. */
export type CommunityErrorCode = (typeof ALL_ERROR_CODES)[number];

/** What the API says about one error code. */
export interface ErrorCodeSpec {
  code: CommunityErrorCode;
  /** The HTTP status it is sent with. */
  status: number;
  /** The default sentence. */
  message: string;
  /** Whether trying the same request again later can succeed. */
  retryable: boolean;
}

export const ERROR_CODE_SPECS: Readonly<Record<CommunityErrorCode, ErrorCodeSpec>> = {
  invalid_request: { code: "invalid_request", status: 400, message: "The request is not valid.", retryable: false },
  ambiguous_credentials: { code: "ambiguous_credentials", status: 400, message: "Send exactly one credential.", retryable: false },
  unauthenticated: { code: "unauthenticated", status: 401, message: "Authentication is required.", retryable: false },
  credential_missing: { code: "credential_missing", status: 401, message: "No API key was provided.", retryable: false },
  credential_malformed: { code: "credential_malformed", status: 401, message: "The API key is not in a valid format.", retryable: false },
  credential_unknown: { code: "credential_unknown", status: 401, message: "The API key is not recognised.", retryable: false },
  credential_revoked: { code: "credential_revoked", status: 401, message: "The API key is no longer valid.", retryable: false },
  session_invalid: { code: "session_invalid", status: 401, message: "The session token is not valid or has expired.", retryable: false },
  user_scope_violation: { code: "user_scope_violation", status: 403, message: "This session belongs to a different user.", retryable: false },
  forbidden: { code: "forbidden", status: 403, message: "You do not have permission to do this.", retryable: false },
  not_found: { code: "not_found", status: 404, message: "The requested resource was not found.", retryable: false },
  method_not_allowed: { code: "method_not_allowed", status: 405, message: "This method is not allowed on this resource.", retryable: false },
  conflict: { code: "conflict", status: 409, message: "The request conflicts with the current state of the resource.", retryable: false },
  username_taken: { code: "username_taken", status: 409, message: "This username is already taken.", retryable: false },
  already_joined: { code: "already_joined", status: 409, message: "This user has already joined the community.", retryable: false },
  community_join_required: { code: "community_join_required", status: 403, message: "Join the community before doing this.", retryable: false },
  comment_replies_disabled: { code: "comment_replies_disabled", status: 403, message: "Replies to comments are turned off for this community.", retryable: false },
  profile_viewing_disabled: { code: "profile_viewing_disabled", status: 403, message: "Viewing other members' profiles is turned off for this community.", retryable: false },
  coach_chat_disabled: { code: "coach_chat_disabled", status: 403, message: "The coaching chat is turned off for this community.", retryable: false },
  topic_name_taken: { code: "topic_name_taken", status: 409, message: "A topic with this name already exists.", retryable: false },
  media_not_uploaded: { code: "media_not_uploaded", status: 409, message: "The file has not been uploaded yet.", retryable: false },
  media_too_large: { code: "media_too_large", status: 413, message: "The image is larger than the upload limit.", retryable: false },
  media_invalid: { code: "media_invalid", status: 422, message: "The file is not an image that can be processed.", retryable: false },
  payload_too_large: { code: "payload_too_large", status: 413, message: "The request body is too large.", retryable: false },
  validation_failed: { code: "validation_failed", status: 422, message: "Some fields are not valid.", retryable: false },
  rate_limited: { code: "rate_limited", status: 429, message: "Too many requests. Please slow down.", retryable: true },
  internal_error: { code: "internal_error", status: 500, message: "Something went wrong on our side.", retryable: false },
  service_unavailable: { code: "service_unavailable", status: 503, message: "The service is temporarily unavailable.", retryable: true },
  timeout: { code: "timeout", status: 504, message: "The request took too long to complete.", retryable: true },
};
