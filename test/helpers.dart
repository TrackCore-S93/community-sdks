import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:trackcore_community/trackcore_community.dart';

final String secretKey = 'cm_sk_test_${'a' * 43}';
final String publishableKey = 'cm_pk_test_${'b' * 43}';
final String sessionToken = 'cm_st_${'c' * 43}';
const String base = 'https://api.test';

/// One recorded request.
class Call {
  Call(this.method, this.uri, this.headers, this.body);
  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final Uint8List? body;

  Object? get json => body == null ? null : jsonDecode(utf8.decode(body!));
  String get path => uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
}

typedef Reply = FutureOr<CommunityRawResponse> Function(Call call);

CommunityRawResponse json(int status, Object? body,
        {Map<String, String> headers = const {}}) =>
    CommunityRawResponse(
      statusCode: status,
      headers: {'content-type': 'application/json', ...headers},
      bodyBytes: Uint8List.fromList(utf8.encode(jsonEncode(body))),
    );

CommunityRawResponse failure(int status, String code,
        {Map<String, Object?> extra = const {}}) =>
    json(status, {
      'error': {
        'code': code,
        'message': '$code happened',
        'request_id': 'req_1',
        'retry_after_seconds': null,
        ...extra
      },
    });

CommunityRawResponse session({String externalId = 'ali', int ttl = 86400}) =>
    json(201, {
      'token': sessionToken,
      'token_type': 'opaque',
      'header': 'X-Community-Session',
      'external_id': externalId,
      'environment': 'test',
      'issued_at': DateTime.now().toUtc().toIso8601String(),
      'expires_at':
          DateTime.now().toUtc().add(Duration(seconds: ttl)).toIso8601String(),
      'ttl_seconds': ttl,
    });

/// Answers from a queue of replies and records what was sent. An entry is a
/// [CommunityRawResponse], a [CommunityAdapterException] to throw, or a
/// [Reply] function.
class FakeAdapter implements CommunityHttpAdapter {
  FakeAdapter(List<Object> replies) : _queue = List.of(replies);
  final List<Object> _queue;
  final List<Call> calls = [];

  @override
  Future<CommunityRawResponse> send(CommunityRawRequest request) async {
    final call =
        Call(request.method, request.uri, request.headers, request.body);
    calls.add(call);
    if (_queue.isEmpty) {
      throw StateError('no reply queued for ${request.method} ${request.uri}');
    }
    final next = _queue.removeAt(0);
    if (next is CommunityAdapterException) throw next;
    if (next is Reply) return next(call);
    return next as CommunityRawResponse;
  }

  @override
  void close() {}
}

final CommunityRetryPolicy quick = CommunityRetryPolicy(
    backoffBase: const Duration(milliseconds: 1),
    backoffMax: const Duration(milliseconds: 2));

CommunityClient creator(FakeAdapter adapter,
        {CommunityRetryPolicy? retryPolicy}) =>
    CommunityClient.serverSideSecret(
        apiKey: secretKey,
        baseUrl: base,
        httpAdapter: adapter,
        retryPolicy: retryPolicy ?? quick);

CommunityClient app(FakeAdapter adapter,
        {CommunityRetryPolicy? retryPolicy,
        void Function(CommunityDiagnostic)? onDiagnostic}) =>
    CommunityClient.publishable(
        apiKey: publishableKey,
        baseUrl: base,
        httpAdapter: adapter,
        retryPolicy: retryPolicy ?? quick,
        onDiagnostic: onDiagnostic);

const Map<String, Object?> postJson = {
  'id': 'cm_post_1',
  'topic_id': 'cm_top_1',
  'author': {
    'external_id': 'ali',
    'username': 'Annie',
    'avatar_url': '',
    'role': 'coach'
  },
  'body': 'Leg day',
  'images': [
    {
      'id': 'cm_med_1',
      'url': 'https://storage.test/1',
      'width': 1024,
      'height': 768
    },
  ],
  'reactions': [
    {'emoji': '❤️', 'count': 2, 'reacted_by_me': false},
  ],
  'comments_count': 4,
  'is_mine': true,
  'is_pinned': true,
  'pinned_at': '2026-11-16T10:00:00Z',
  'created_at': '2026-11-15T09:30:00.123456Z',
};
