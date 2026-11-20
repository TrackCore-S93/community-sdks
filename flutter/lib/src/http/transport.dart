/// The request layer: one place that knows the key, who the user is, when to
/// retry and how to read a reply.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../errors/exceptions.dart';
import '../generated/error_code.dart';
import '../generated/models.dart';
import 'http_adapter.dart';
import 'retry_policy.dart';

const String communityDefaultBaseUrl = 'https://api.community.trackcore.app';
const String communitySessionHeader = 'X-Community-Session';
const String communityExternalIdHeader = 'X-External-Id';
const String communityIdempotencyHeader = 'Idempotency-Key';
const int communityMaxExternalIdLength = 255;

final RegExp _keyShape = RegExp(r'^cm_(sk|pk)_(live|test)_[A-Za-z0-9_-]{8,}$');
final RegExp _sessionShape = RegExp(r'^cm_st_[A-Za-z0-9_-]{43}$');

/// A session this close to its end is renewed before it is used.
const Duration _renewWithin = Duration(minutes: 1);

/// Who a request acts for, which decides the headers it carries.
enum Audience {
  anyKey,
  member,
  creator,

  /// The creator's backend acting as one named member: a secret key, and a
  /// user set with `setUser`.
  coach,
  memberOrCreator,
}

/// `live` or `test`, from the key.
enum CommunityEnvironment { live, test }

/// `secret` or `publishable`, from the key.
enum CommunityKeyKind { secret, publishable }

/// What happened inside a call. Never carries a key or a session token.
sealed class CommunityDiagnostic {
  const CommunityDiagnostic();
}

/// An attempt failed and another will be made.
final class RetryDiagnostic extends CommunityDiagnostic {
  const RetryDiagnostic(
      {required this.method,
      required this.path,
      required this.attempt,
      required this.delay,
      required this.reason});
  final String method;
  final String path;
  final int attempt;
  final Duration delay;
  final String reason;
}

/// The SDK's own session was minted, renewed or ended.
final class SessionDiagnostic extends CommunityDiagnostic {
  const SessionDiagnostic(this.event, {this.externalId, this.expiresAt});

  /// `minted`, `renewed` or `ended`.
  final String event;
  final String? externalId;
  final DateTime? expiresAt;
}

/// The live connection opened, dropped, retried or closed.
final class LiveDiagnostic extends CommunityDiagnostic {
  const LiveDiagnostic(this.status, this.attempt);
  final String status;
  final int attempt;
}

/// Checks a user id against the API's rule, so a bad one fails here and not
/// on the server.
void assertValidExternalId(String externalId) {
  if (externalId.isEmpty) {
    throw const CommunityConfigurationException(
        CommunityConfigurationReason.externalIdEmpty, 'The user id is empty.');
  }
  if (externalId != externalId.trim()) {
    throw const CommunityConfigurationException(
        CommunityConfigurationReason.externalIdUntrimmed,
        'The user id has leading or trailing spaces.');
  }
  if (utf8.encode(externalId).length > communityMaxExternalIdLength) {
    throw const CommunityConfigurationException(
        CommunityConfigurationReason.externalIdTooLong,
        'The user id is longer than $communityMaxExternalIdLength bytes.');
  }
}

final class _OwnSession {
  _OwnSession(this.token, this.expiresAt, {required this.owned});
  final String token;
  final DateTime? expiresAt;

  /// True when this SDK minted it, and so may mint another.
  final bool owned;
}

final class Transport {
  Transport({
    required String apiKey,
    required String baseUrl,
    required CommunityHttpAdapter adapter,
    required this.retryPolicy,
    required this.timeout,
    required this.sessionTtlSeconds,
    Map<String, String> headers = const {},
    this.onDiagnostic,
    Future<void> Function(Duration)? sleep,
    DateTime Function()? now,
  })  : _apiKey = apiKey,
        _adapter = adapter,
        _extraHeaders = Map.unmodifiable(headers),
        _sleep = sleep ?? Future<void>.delayed,
        _now = now ?? DateTime.now {
    final shape = _keyShape.firstMatch(apiKey);
    if (shape == null) {
      throw const CommunityConfigurationException(
          CommunityConfigurationReason.apiKeyMalformed,
          'The API key is not a Community key (cm_sk_… or cm_pk_…).');
    }
    keyKind = shape.group(1) == 'sk'
        ? CommunityKeyKind.secret
        : CommunityKeyKind.publishable;
    environment = shape.group(2) == 'live'
        ? CommunityEnvironment.live
        : CommunityEnvironment.test;
    final Uri parsed;
    try {
      parsed = Uri.parse(baseUrl);
    } on FormatException {
      throw const CommunityConfigurationException(
          CommunityConfigurationReason.baseUrlInvalid, 'baseUrl is not a URL.');
    }
    if (!parsed.hasScheme ||
        parsed.host.isEmpty ||
        !(parsed.isScheme('https') || parsed.isScheme('http'))) {
      throw const CommunityConfigurationException(
          CommunityConfigurationReason.baseUrlInvalid,
          'baseUrl must be an https:// address.');
    }
    if (!parsed.isScheme('https') && !_isLocal(parsed)) {
      throw const CommunityConfigurationException(
          CommunityConfigurationReason.baseUrlNotHttps,
          'baseUrl must be https://. Plain http:// is accepted only for localhost and the Android emulator (10.0.2.2).');
    }
    final path = parsed.path.replaceAll(RegExp(r'/+$'), '');
    this.baseUrl = parsed.replace(path: path, query: null, fragment: null);
    if (sessionTtlSeconds < 60 || sessionTtlSeconds > 86400) {
      throw const CommunityConfigurationException(
          CommunityConfigurationReason.optionInvalid,
          'sessionTtlSeconds must be between 60 and 86400.');
    }
  }

  static bool _isLocal(Uri uri) =>
      uri.host == 'localhost' ||
      uri.host == '127.0.0.1' ||
      uri.host == '10.0.2.2' ||
      uri.host == '::1';

  final String _apiKey;
  final CommunityHttpAdapter _adapter;
  final Map<String, String> _extraHeaders;
  final Future<void> Function(Duration) _sleep;
  final DateTime Function() _now;

  final CommunityRetryPolicy retryPolicy;
  final Duration timeout;
  final int sessionTtlSeconds;
  final void Function(CommunityDiagnostic)? onDiagnostic;

  late final Uri baseUrl;
  late final CommunityKeyKind keyKind;
  late final CommunityEnvironment environment;

  String? _externalId;
  _OwnSession? _session;
  Future<void>? _minting;

  /// The key, masked: safe to log.
  String describeCredential() {
    final prefix = _apiKey.substring(0, _apiKey.indexOf('_', 6) + 1);
    return '$prefix…${_apiKey.substring(_apiKey.length - 3)}';
  }

  String? get externalId => _externalId;
  String? get sessionToken => _session?.token;
  CommunityHttpAdapter get adapter => _adapter;

  void emit(CommunityDiagnostic diagnostic) {
    try {
      onDiagnostic?.call(diagnostic);
    } catch (_) {
      // A diagnostic listener must never break a call.
    }
  }

  void setUser(String externalId) {
    assertValidExternalId(externalId);
    _externalId = externalId;
  }

  void clearUser() => _externalId = null;

  void setSession(String sessionToken) {
    if (!_sessionShape.hasMatch(sessionToken)) {
      throw const CommunityConfigurationException(
          CommunityConfigurationReason.sessionTokenMalformed,
          'That is not a Community session token (cm_st_…).');
    }
    _session = _OwnSession(sessionToken, null, owned: false);
  }

  void clearSession() => _session = null;

  /// Signs a user in. With a secret key this names the user and mints
  /// nothing. With a publishable key it mints a session for them.
  Future<void> initialize(String externalId) async {
    assertValidExternalId(externalId);
    _externalId = externalId;
    if (keyKind == CommunityKeyKind.secret) {
      _session = null;
      return;
    }
    await _mint('minted');
  }

  /// Ends the session on the server, where there is one, and forgets the user.
  Future<void> signOut() async {
    final session = _session;
    _session = null;
    _externalId = null;
    if (session != null && keyKind == CommunityKeyKind.publishable) {
      try {
        await _send('DELETE', '/v1/auth/session',
            identity: {communitySessionHeader: session.token});
      } on CommunityException {
        // The session ends by itself; signing out must not fail because the network did.
      }
      emit(const SessionDiagnostic('ended'));
    }
  }

  Future<void> _mint(String event) {
    // One mint at a time: calls that arrive together wait for the same one.
    return _minting ??= () async {
      final externalId = _externalId;
      try {
        if (externalId == null) {
          throw const CommunityConfigurationException(
              CommunityConfigurationReason.noUser,
              'No user is signed in. Call initialize(userId) first.');
        }
        final reply = await _send('POST', '/v1/auth/session', body: {
          'external_id': externalId,
          'ttl_seconds': sessionTtlSeconds
        });
        final session =
            Session.fromJson((reply! as Map).cast<String, Object?>());
        // Signed out, or signed in as someone else, while this was in flight.
        if (_externalId != externalId) return;
        _session = _OwnSession(session.token, session.expiresAt, owned: true);
        emit(SessionDiagnostic(event,
            externalId: externalId, expiresAt: session.expiresAt));
      } finally {
        _minting = null;
      }
    }();
  }

  /// The headers that say who a request acts for.
  Future<Map<String, String>> _identity(Audience audience) async {
    switch (audience) {
      case Audience.anyKey:
        return const {};
      case Audience.creator:
        if (keyKind != CommunityKeyKind.secret) {
          throw const CommunityConfigurationException(
              CommunityConfigurationReason.secretKeyRequired,
              'This call needs a secret key and belongs on your backend.');
        }
        return const {};
      case Audience.coach:
        if (keyKind != CommunityKeyKind.secret) {
          throw const CommunityConfigurationException(
              CommunityConfigurationReason.secretKeyRequired,
              'This call needs a secret key and belongs on your backend.');
        }
        final coach = _externalId;
        if (coach == null) {
          throw const CommunityConfigurationException(
              CommunityConfigurationReason.noUser,
              'No coach is named. Call setUser(coachId) first.');
        }
        return {communityExternalIdHeader: coach};
      case Audience.member:
      case Audience.memberOrCreator:
        break;
    }
    if (keyKind == CommunityKeyKind.secret) {
      final externalId = _externalId;
      if (externalId != null) return {communityExternalIdHeader: externalId};
      if (audience == Audience.memberOrCreator) return const {};
      throw const CommunityConfigurationException(
          CommunityConfigurationReason.noUser,
          'No user is named. Call initialize(userId) first.');
    }
    var session = _session;
    if (session == null) {
      throw const CommunityConfigurationException(
          CommunityConfigurationReason.noUser,
          'No user is signed in. Call initialize(userId) first.');
    }
    final expiresAt = session.expiresAt;
    if (session.owned &&
        expiresAt != null &&
        expiresAt.difference(_now()) < _renewWithin) {
      await _mint('renewed');
      session = _session ?? session;
    }
    return {communitySessionHeader: session.token};
  }

  /// The headers a live connection opens with.
  Future<Map<String, String>> liveHeaders() async => {
        ...await _identity(Audience.memberOrCreator),
        'Authorization': 'Bearer $_apiKey',
      };

  /// Makes a request for an API: identity, retries, and one renewal of an
  /// expired session. Returns the decoded JSON, or null for an empty reply.
  Future<Object?> request(
    String method,
    String path, {
    required Audience audience,
    Map<String, Object?> query = const {},
    Object? body,
    String? idempotencyKey,
    bool repeatable = false,
  }) async {
    final identity = await _identity(audience);
    try {
      return await _send(method, path,
          identity: identity,
          query: query,
          body: body,
          idempotencyKey: idempotencyKey,
          repeatable: repeatable);
    } on CommunityApiException catch (error) {
      final session = _session;
      if (error.code != CommunityErrorCode.sessionInvalid ||
          session == null ||
          !session.owned) {
        rethrow;
      }
      // The session this SDK minted has ended early. Mint another, once.
      await _mint('renewed');
      return _send(method, path,
          identity: await _identity(audience),
          query: query,
          body: body,
          idempotencyKey: idempotencyKey,
          repeatable: repeatable);
    }
  }

  /// Sends bytes to an address outside the API (a file to storage). No key
  /// is sent: the link carries its own permission.
  Future<CommunityRawResponse> sendTo(
      Uri uri, String method, Uint8List body, String contentType) async {
    try {
      return await _adapter.send(CommunityRawRequest(
        method: method,
        uri: uri,
        headers: {'Content-Type': contentType},
        body: body,
        timeout: const Duration(minutes: 2),
      ));
    } on CommunityAdapterException catch (error) {
      throw CommunityTransportException(
          'The file could not be sent to storage.',
          kind: _failureOf(error.kind),
          attempts: 1,
          cause: error);
    }
  }

  static CommunityTransportFailure _failureOf(
          CommunityAdapterFailureKind kind) =>
      switch (kind) {
        CommunityAdapterFailureKind.connectFailed =>
          CommunityTransportFailure.connectFailed,
        CommunityAdapterFailureKind.timeout =>
          CommunityTransportFailure.timeout,
        CommunityAdapterFailureKind.other => CommunityTransportFailure.other,
      };

  Future<Object?> _send(
    String method,
    String path, {
    Map<String, String> identity = const {},
    Map<String, Object?> query = const {},
    Object? body,
    String? idempotencyKey,
    bool repeatable = false,
  }) async {
    final parameters = <String, String>{
      for (final entry in query.entries)
        if (entry.value != null && entry.value.toString().isNotEmpty)
          entry.key: entry.value.toString(),
    };
    final uri = baseUrl.replace(
      path: '${baseUrl.path}$path',
      queryParameters: parameters.isEmpty ? null : parameters,
    );
    final headers = <String, String>{
      ..._extraHeaders,
      'Accept': 'application/json',
      ...identity
    };
    Uint8List? bytes;
    if (body != null) {
      headers['Content-Type'] = 'application/json';
      bytes = Uint8List.fromList(utf8.encode(jsonEncode(body)));
    }
    if (idempotencyKey != null) {
      headers[communityIdempotencyHeader] = idempotencyKey;
    }
    headers['Authorization'] = 'Bearer $_apiKey';

    // A request that writes is repeated only when repeating it is safe.
    final canRepeat = (method != 'POST' && method != 'PATCH') ||
        idempotencyKey != null ||
        repeatable;
    final deadline = _now().add(retryPolicy.totalDeadline);
    var attempt = 0;
    var badGateways = 0;
    while (true) {
      attempt++;
      final remaining = deadline.difference(_now());
      if (remaining <= Duration.zero) {
        throw CommunityTransportException(
            'The call did not finish within ${retryPolicy.totalDeadline.inSeconds} s.',
            kind: CommunityTransportFailure.deadline,
            attempts: attempt - 1);
      }
      CommunityException failure;
      Duration? retryAfter;
      String reason;
      try {
        final response = await _adapter.send(CommunityRawRequest(
          method: method,
          uri: uri,
          headers: headers,
          body: bytes,
          timeout: remaining < timeout ? remaining : timeout,
        ));
        final status = response.statusCode;
        if (status >= 200 && status < 300) return _read(response);
        final error = _failure(response);
        if (status == 502) badGateways++;
        final ceiling = retryPolicy.attemptCeilingFor(status);
        final again = retryPolicy.shouldRetryStatus(status) &&
            (status == 502 ? badGateways : attempt) < ceiling;
        if (!again || !canRepeat) throw error;
        failure = error;
        reason = 'http_$status';
        // Retry-After wins over the schedule, with the envelope's own value
        // as the fallback for a proxy that stripped the header.
        final header = double.tryParse(response.headers['retry-after'] ?? '');
        retryAfter = header != null && header > 0
            ? Duration(milliseconds: (header * 1000).round())
            : (error is CommunityApiException ? error.retryAfter : null);
      } on CommunityAdapterException catch (error) {
        final wrapped = CommunityTransportException(error.message,
            kind: _failureOf(error.kind),
            attempts: attempt,
            cause: error.cause);
        // Nothing came back, so the server may or may not have acted: a
        // request that is not safe to repeat stops here.
        if (!retryPolicy.shouldRetryTransport(error.kind) || !canRepeat) {
          throw wrapped;
        }
        failure = wrapped;
        reason = error.kind.name;
      }
      if (attempt >= retryPolicy.maxAttempts) throw failure;
      final delay = retryAfter ?? retryPolicy.backoffFor(attempt);
      if (!_now().add(delay).isBefore(deadline)) throw failure;
      emit(RetryDiagnostic(
          method: method,
          path: path,
          attempt: attempt,
          delay: delay,
          reason: reason));
      await _sleep(delay);
    }
  }

  Object? _read(CommunityRawResponse response) {
    if (response.statusCode == 204 || response.bodyBytes.isEmpty) return null;
    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    try {
      return jsonDecode(text);
    } on FormatException {
      throw CommunityProtocolException(response.statusCode, text);
    }
  }

  /// Turns a non-2xx reply into a typed exception. Nothing from an
  /// unrecognised body reaches the message.
  CommunityException _failure(CommunityRawResponse response) {
    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    Object? parsed;
    try {
      parsed = jsonDecode(text);
    } on FormatException {
      return CommunityProtocolException(response.statusCode, text);
    }
    final error = parsed is Map ? parsed['error'] : null;
    if (error is! Map ||
        error['code'] is! String ||
        error['message'] is! String) {
      return CommunityProtocolException(response.statusCode, text);
    }
    final fields = error['fields'];
    final retryAfter = error['retry_after_seconds'];
    return CommunityApiException(
      code: CommunityErrorCode.fromWire(error['code'] as String),
      rawCode: error['code'] as String,
      message: error['message'] as String,
      httpStatus: response.statusCode,
      requestId:
          error['request_id'] is String ? error['request_id'] as String : null,
      retryAfter: retryAfter is num
          ? Duration(milliseconds: (retryAfter * 1000).round())
          : null,
      fields: fields is Map
          ? fields.map((k, v) => MapEntry(k.toString(), v.toString()))
          : const <String, String>{},
    );
  }

  void close() => _adapter.close();
}
