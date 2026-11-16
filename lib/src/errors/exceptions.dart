/// Everything this SDK throws.
library;

import '../generated/error_code.dart';

/// Where an error code is explained.
const String communityErrorDocsUrl =
    'https://community.trackcore.app/developer/guide/errors';

/// The root of every exception this SDK throws.
sealed class CommunityException implements Exception {
  const CommunityException(this.message, {this.requestId});

  /// A sentence describing what went wrong.
  final String message;

  /// A reference for the request, to quote when reporting a problem.
  final String? requestId;

  @override
  String toString() {
    final suffix = requestId == null ? '' : ' (request_id: $requestId)';
    return '$runtimeType: $message$suffix';
  }
}

/// A non-2xx reply from the API. Branch on [code], never on [message].
final class CommunityApiException extends CommunityException {
  const CommunityApiException({
    required this.code,
    required this.rawCode,
    required String message,
    required this.httpStatus,
    super.requestId,
    this.retryAfter,
    this.fields = const <String, String>{},
  }) : super(message);

  /// Which problem this is. [CommunityErrorCode.unknown] for a code newer
  /// than this SDK; [rawCode] has the text.
  final CommunityErrorCode code;

  /// The code exactly as the API sent it.
  final String rawCode;

  /// The HTTP status.
  final int httpStatus;

  /// How long the server asked the caller to wait, when it said.
  final Duration? retryAfter;

  /// For `validation_failed`: each field that failed, and why.
  final Map<String, String> fields;

  /// Where this code is explained.
  String get docsUrl => '$communityErrorDocsUrl#$rawCode';

  /// True for 401: the key or the session is missing, wrong or ended.
  bool get isAuthenticationFailure => httpStatus == 401;

  /// True when the user has not joined the community yet.
  bool get isJoinRequired => code == CommunityErrorCode.communityJoinRequired;

  @override
  String toString() {
    final parts = <String>[
      'CommunityApiException($rawCode, HTTP $httpStatus)',
      message,
      if (requestId != null) 'request_id: $requestId',
      'see $docsUrl',
    ];
    return parts.join(' — ');
  }
}

/// Why nothing usable came back.
enum CommunityTransportFailure {
  /// DNS, TLS, connection refused, offline.
  connectFailed,

  /// One attempt ran out of time.
  timeout,

  /// The whole call, retries included, ran out of time.
  deadline,

  /// Anything else that stopped the request.
  other,
}

/// Nothing came back from the API: it could not be reached, or took too long.
final class CommunityTransportException extends CommunityException {
  const CommunityTransportException(
    super.message, {
    required this.kind,
    required this.attempts,
    this.cause,
  });

  /// What went wrong.
  final CommunityTransportFailure kind;

  /// How many attempts were made.
  final int attempts;

  /// The underlying error, when there is one.
  final Object? cause;

  @override
  String toString() =>
      'CommunityTransportException(${kind.name}, $attempts attempt(s)): $message';
}

/// Why a client could not be built or used as asked.
enum CommunityConfigurationReason {
  apiKeyMissing,
  apiKeyMalformed,
  secretKeyInApp,
  secretKeyRequired,
  baseUrlInvalid,
  baseUrlNotHttps,
  optionInvalid,
  notConfigured,
  noUser,
  externalIdEmpty,
  externalIdUntrimmed,
  externalIdTooLong,
  sessionTokenMalformed,
  liveUnsupported,
}

/// A bad key, a bad base URL, a bad user id, or a call the key cannot make.
final class CommunityConfigurationException extends CommunityException {
  const CommunityConfigurationException(this.reason, super.message);

  /// Which rule was broken.
  final CommunityConfigurationReason reason;

  @override
  String toString() =>
      'CommunityConfigurationException(${reason.name}): $message';
}

/// An argument that cannot be right, caught before anything is sent.
final class CommunityValidationException extends CommunityException {
  const CommunityValidationException(this.field, super.message);

  /// The argument at fault.
  final String field;
}

/// The reply was not something this API sends: a proxy's page, a captive
/// portal. The message is fixed text; the body is kept apart in [bodySample].
final class CommunityProtocolException extends CommunityException {
  CommunityProtocolException(this.httpStatus, String body)
      : bodySample = body.length > 2048 ? body.substring(0, 2048) : body,
        super('The reply (HTTP $httpStatus) was not a Community API response.');

  /// The HTTP status of the reply.
  final int httpStatus;

  /// Up to 2 KiB of what came back. Not part of [toString].
  final String bodySample;
}
