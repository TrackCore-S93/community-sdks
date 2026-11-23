// GENERATED from contract/openapi.json by tool/generate.dart. Do not edit.

/// The closed list of error codes the API answers with.
enum CommunityErrorCode {
  /// HTTP 400. The request is not valid.
  invalidRequest('invalid_request', 400, false),

  /// HTTP 400. Send exactly one credential.
  ambiguousCredentials('ambiguous_credentials', 400, false),

  /// HTTP 401. Authentication is required.
  unauthenticated('unauthenticated', 401, false),

  /// HTTP 401. No API key was provided.
  credentialMissing('credential_missing', 401, false),

  /// HTTP 401. The API key is not in a valid format.
  credentialMalformed('credential_malformed', 401, false),

  /// HTTP 401. The API key is not recognised.
  credentialUnknown('credential_unknown', 401, false),

  /// HTTP 401. The API key is no longer valid.
  credentialRevoked('credential_revoked', 401, false),

  /// HTTP 401. The session token is not valid or has expired.
  sessionInvalid('session_invalid', 401, false),

  /// HTTP 403. This session belongs to a different user.
  userScopeViolation('user_scope_violation', 403, false),

  /// HTTP 403. You do not have permission to do this.
  forbidden('forbidden', 403, false),

  /// HTTP 404. The requested resource was not found.
  notFound('not_found', 404, false),

  /// HTTP 405. This method is not allowed on this resource.
  methodNotAllowed('method_not_allowed', 405, false),

  /// HTTP 409. The request conflicts with the current state of the resource.
  conflict('conflict', 409, false),

  /// HTTP 409. This username is already taken.
  usernameTaken('username_taken', 409, false),

  /// HTTP 409. This user has already joined the community.
  alreadyJoined('already_joined', 409, false),

  /// HTTP 403. Join the community before doing this.
  communityJoinRequired('community_join_required', 403, false),

  /// HTTP 403. Replies to comments are turned off for this community.
  commentRepliesDisabled('comment_replies_disabled', 403, false),

  /// HTTP 403. Viewing other members' profiles is turned off for this community.
  profileViewingDisabled('profile_viewing_disabled', 403, false),

  /// HTTP 403. The coaching chat is turned off for this community.
  coachChatDisabled('coach_chat_disabled', 403, false),

  /// HTTP 409. A topic with this name already exists.
  topicNameTaken('topic_name_taken', 409, false),

  /// HTTP 409. The file has not been uploaded yet.
  mediaNotUploaded('media_not_uploaded', 409, false),

  /// HTTP 413. The image is larger than the upload limit.
  mediaTooLarge('media_too_large', 413, false),

  /// HTTP 422. The file is not an image that can be processed.
  mediaInvalid('media_invalid', 422, false),

  /// HTTP 413. The request body is too large.
  payloadTooLarge('payload_too_large', 413, false),

  /// HTTP 422. Some fields are not valid.
  validationFailed('validation_failed', 422, false),

  /// HTTP 429. Too many requests. Please slow down.
  rateLimited('rate_limited', 429, true),

  /// HTTP 500. Something went wrong on our side.
  internalError('internal_error', 500, false),

  /// HTTP 503. The service is temporarily unavailable.
  serviceUnavailable('service_unavailable', 503, true),

  /// HTTP 504. The request took too long to complete.
  timeout('timeout', 504, true),

  /// A code this version of the SDK does not know. Read `rawCode` on the exception.
  unknown('', 0, false);

  const CommunityErrorCode(this.wire, this.httpStatus, this.retryable);

  /// The code as the API sends it.
  final String wire;

  /// The HTTP status the code is sent with.
  final int httpStatus;

  /// Whether trying the same request again later can succeed.
  final bool retryable;

  /// The member for a code from the API, or [unknown].
  static CommunityErrorCode fromWire(String? value) =>
      values.firstWhere((e) => e.wire == value,
          orElse: () => CommunityErrorCode.unknown);
}
