import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:trackcore_community/trackcore_community.dart';

import 'helpers.dart';

CommunityConfigurationReason? reasonOf(void Function() build) {
  try {
    build();
  } on CommunityConfigurationException catch (e) {
    return e.reason;
  }
  return null;
}

void main() {
  test('a client says what it was built with and never shows its key', () {
    final c = creator(FakeAdapter([]));
    expect(c.keyKind, CommunityKeyKind.secret);
    expect(c.environment, CommunityEnvironment.test);
    expect(c.baseUrl.toString(), base);
    expect(c.describeCredential(), 'cm_sk_test_…aaa');
    expect(c.toString(), isNot(contains(secretKey)));
  });

  test('bad configuration fails before anything is sent', () {
    final adapter = FakeAdapter([]);
    expect(
        reasonOf(() =>
            CommunityClient.publishable(apiKey: 'nope', httpAdapter: adapter)),
        CommunityConfigurationReason.apiKeyMalformed);
    expect(
        reasonOf(() => CommunityClient.publishable(
            apiKey: secretKey, httpAdapter: adapter)),
        CommunityConfigurationReason.secretKeyInApp);
    expect(
        reasonOf(() => CommunityClient.serverSideSecret(
            apiKey: publishableKey, httpAdapter: adapter)),
        CommunityConfigurationReason.apiKeyMalformed);
    expect(
        reasonOf(() => CommunityClient.publishable(
            apiKey: publishableKey, baseUrl: 'ftp://x', httpAdapter: adapter)),
        CommunityConfigurationReason.baseUrlInvalid);
    expect(
        reasonOf(() => CommunityClient.publishable(
            apiKey: publishableKey,
            baseUrl: 'http://api.example.com',
            httpAdapter: adapter)),
        CommunityConfigurationReason.baseUrlNotHttps);
    for (final local in [
      'http://localhost:8080',
      'http://127.0.0.1:8080',
      'http://10.0.2.2:8080'
    ]) {
      expect(
          reasonOf(() => CommunityClient.publishable(
              apiKey: publishableKey, baseUrl: local, httpAdapter: adapter)),
          isNull);
    }
    expect(
        reasonOf(() => CommunityClient.publishable(
            apiKey: publishableKey,
            sessionTtlSeconds: 90000,
            httpAdapter: adapter)),
        CommunityConfigurationReason.optionInvalid);
    expect(reasonOf(() => Community.instance.posts),
        CommunityConfigurationReason.notConfigured);
    expect(adapter.calls, isEmpty);
  });

  test(
      'the shared instance refuses a secret key unless the server acknowledgement is given',
      () async {
    final adapter = FakeAdapter([
      json(200, {
        'customer_id': 'cm_cus_1',
        'key_id': 'cm_key_1',
        'key_kind': 'secret',
        'environment': 'test'
      })
    ]);
    await expectLater(
        Community.instance
            .configure(apiKey: secretKey, baseUrl: base, httpAdapter: adapter),
        throwsA(isA<CommunityConfigurationException>().having((e) => e.reason,
            'reason', CommunityConfigurationReason.secretKeyInApp)));
    await Community.instance.configure(
        apiKey: secretKey,
        baseUrl: base,
        httpAdapter: adapter,
        iUnderstandThisKeyMustNeverShipInAnAppBinary: true);
    final who = await Community.instance.client.whoAmI();
    expect(who.keyKind, 'secret');
    expect(adapter.calls.single.headers['Authorization'], 'Bearer $secretKey');
  });

  test('with a secret key, initialize names the user and mints nothing',
      () async {
    final adapter = FakeAdapter([
      json(200, {'joined': false, 'profile': null})
    ]);
    final c = creator(adapter);
    expect(reasonOf(() => c.setUser(' ali ')),
        CommunityConfigurationReason.externalIdUntrimmed);
    expect(reasonOf(() => c.setUser('')),
        CommunityConfigurationReason.externalIdEmpty);
    expect(reasonOf(() => c.setUser('x' * 256)),
        CommunityConfigurationReason.externalIdTooLong);
    await expectLater(
        c.community.me(),
        throwsA(isA<CommunityConfigurationException>().having(
            (e) => e.reason, 'reason', CommunityConfigurationReason.noUser)));
    await c.initialize('ali');
    expect(adapter.calls, isEmpty);
    expect((await c.community.me()).joined, isFalse);
    expect(adapter.calls.single.headers['X-External-Id'], 'ali');
    await c.signOut();
    expect(c.externalId, isNull);
    expect(adapter.calls, hasLength(1));
  });

  test('with a publishable key, initialize mints a session and uses it',
      () async {
    final events = <CommunityDiagnostic>[];
    final adapter = FakeAdapter([
      session(ttl: 3600),
      json(200, {'joined': false, 'profile': null}),
      json(204, null)
    ]);
    final c = CommunityClient.publishable(
        apiKey: publishableKey,
        baseUrl: base,
        httpAdapter: adapter,
        sessionTtlSeconds: 3600,
        onDiagnostic: events.add);
    await c.initialize('ali');
    expect('${adapter.calls[0].method} ${adapter.calls[0].path}',
        'POST /v1/auth/session');
    expect(adapter.calls[0].json, {'external_id': 'ali', 'ttl_seconds': 3600});
    expect(c.sessionToken, sessionToken);
    await c.community.me();
    expect(adapter.calls[1].headers['X-Community-Session'], sessionToken);
    expect(adapter.calls[1].headers.containsKey('X-External-Id'), isFalse);
    await c.signOut();
    expect('${adapter.calls[2].method} ${adapter.calls[2].path}',
        'DELETE /v1/auth/session');
    expect(c.sessionToken, isNull);
    expect(events.whereType<SessionDiagnostic>().map((e) => e.event),
        ['minted', 'ended']);
  });

  test(
      'an expired session is renewed once, and a session near its end before use',
      () async {
    var adapter = FakeAdapter([
      session(),
      failure(401, 'session_invalid'),
      session(),
      json(200, {'unread_count': 4})
    ]);
    var c = app(adapter);
    await c.initialize('ali');
    expect(await c.notifications.unreadCount(), 4);
    expect(adapter.calls.map((x) => x.path), [
      '/v1/auth/session',
      '/v1/notifications/unread-count',
      '/v1/auth/session',
      '/v1/notifications/unread-count'
    ]);

    adapter = FakeAdapter([
      session(),
      failure(401, 'session_invalid'),
      session(),
      failure(401, 'session_invalid')
    ]);
    c = app(adapter);
    await c.initialize('ali');
    await expectLater(
        c.notifications.unreadCount(),
        throwsA(isA<CommunityApiException>()
            .having((e) => e.code, 'code', CommunityErrorCode.sessionInvalid)));
    expect(adapter.calls, hasLength(4));

    adapter = FakeAdapter([
      session(ttl: 30),
      session(ttl: 3600),
      json(200, {'blocked': <Object>[]})
    ]);
    c = app(adapter);
    await c.initialize('ali');
    expect(await c.blocks.list(), isEmpty);
    expect(adapter.calls.map((x) => x.path),
        ['/v1/auth/session', '/v1/auth/session', '/v1/blocks']);

    adapter = FakeAdapter([failure(401, 'session_invalid')]);
    c = app(adapter)..setSession(sessionToken);
    await expectLater(c.blocks.list(), throwsA(isA<CommunityApiException>()));
    expect(adapter.calls, hasLength(1));
    expect(reasonOf(() => c.setSession('not-a-token')),
        CommunityConfigurationReason.sessionTokenMalformed);
  });

  test('creator calls need a secret key, checked before sending', () async {
    final adapter = FakeAdapter([session()]);
    final c = app(adapter);
    await c.initialize('ali');
    final calls = <Future<Object?> Function()>[
      () => c.topics.create(name: 'X'),
      () => c.settings.update(searchPageSize: 10),
      () => c.posts.pin('cm_post_1'),
      () => c.members.list(),
      () => c.members.setRole('ali', Role.coach),
      () => c.reports.list(),
      () => c.archive.list(),
      () => c.archive.get('cm_arc_1'),
      () => c.users.delete('ali'),
    ];
    for (final call in calls) {
      await expectLater(
          call(),
          throwsA(isA<CommunityConfigurationException>().having((e) => e.reason,
              'reason', CommunityConfigurationReason.secretKeyRequired)));
    }
    expect(adapter.calls, hasLength(1));
  });

  test('each failure becomes a typed exception with its code', () async {
    final cases = <(int, String, CommunityErrorCode)>[
      (400, 'invalid_request', CommunityErrorCode.invalidRequest),
      (401, 'credential_revoked', CommunityErrorCode.credentialRevoked),
      (
        403,
        'community_join_required',
        CommunityErrorCode.communityJoinRequired
      ),
      (404, 'not_found', CommunityErrorCode.notFound),
      (409, 'username_taken', CommunityErrorCode.usernameTaken),
      (422, 'validation_failed', CommunityErrorCode.validationFailed),
      (500, 'internal_error', CommunityErrorCode.internalError),
    ];
    for (final (status, wire, code) in cases) {
      final adapter = FakeAdapter([
        failure(status, wire,
            extra: wire == 'validation_failed'
                ? {
                    'fields': {'username': 'is too short'}
                  }
                : const {}),
      ]);
      final c = creator(adapter, retryPolicy: CommunityRetryPolicy.none())
        ..setUser('ali');
      try {
        await c.community.join('Annie');
        fail('expected $wire');
      } on CommunityApiException catch (e) {
        expect(e.code, code);
        expect(e.rawCode, wire);
        expect(e.httpStatus, status);
        expect(e.requestId, 'req_1');
        expect(e.docsUrl, endsWith('#$wire'));
        if (wire == 'validation_failed') {
          expect(e.fields, {'username': 'is too short'});
        }
        expect(e.isJoinRequired, wire == 'community_join_required');
      }
    }
    // A code newer than the SDK is still an API exception, with the text kept.
    final c = creator(FakeAdapter([failure(418, 'brand_new_code')]),
        retryPolicy: CommunityRetryPolicy.none());
    await expectLater(
        c.settings.get(),
        throwsA(isA<CommunityApiException>()
            .having((e) => e.code, 'code', CommunityErrorCode.unknown)
            .having((e) => e.rawCode, 'rawCode', 'brand_new_code')));
    expect(
        CommunityErrorCode.values.where((e) => e != CommunityErrorCode.unknown),
        hasLength(28));
  });

  test(
      'a reply that is not from the API is a protocol exception that hides its body',
      () async {
    final page = '<html>captive portal ${'x' * 5000}</html>';
    for (final status in [502, 200]) {
      final adapter = FakeAdapter([
        CommunityRawResponse(
            statusCode: status,
            headers: const {},
            bodyBytes: Uint8List.fromList(page.codeUnits)),
      ]);
      final c = creator(adapter, retryPolicy: CommunityRetryPolicy.none());
      try {
        await c.settings.get();
        fail('expected a protocol exception');
      } on CommunityProtocolException catch (e) {
        expect(e.message, isNot(contains('captive')));
        expect(e.toString(), isNot(contains('captive')));
        expect(e.bodySample.length, lessThanOrEqualTo(2048));
      }
    }
  });

  test('retries: what is tried again and what is not', () async {
    CommunityRawResponse settings() => json(200, settingsJson);
    const dropped = CommunityAdapterException('down',
        kind: CommunityAdapterFailureKind.connectFailed);
    final events = <CommunityDiagnostic>[];

    var adapter =
        FakeAdapter([failure(503, 'service_unavailable'), dropped, settings()]);
    var c = CommunityClient.serverSideSecret(
        apiKey: secretKey,
        baseUrl: base,
        httpAdapter: adapter,
        retryPolicy: quick,
        onDiagnostic: events.add);
    await c.settings.get();
    expect(adapter.calls, hasLength(3));
    expect(events.whereType<RetryDiagnostic>().map((e) => e.reason),
        ['http_503', 'connectFailed']);

    adapter = FakeAdapter([dropped, dropped, dropped]);
    await expectLater(
        creator(adapter).settings.get(),
        throwsA(isA<CommunityTransportException>()
            .having(
                (e) => e.kind, 'kind', CommunityTransportFailure.connectFailed)
            .having((e) => e.attempts, 'attempts', 3)));

    for (final reply in [
      failure(500, 'internal_error'),
      failure(404, 'not_found'),
      failure(401, 'credential_unknown')
    ]) {
      adapter = FakeAdapter([reply, settings()]);
      await expectLater(creator(adapter).settings.get(),
          throwsA(isA<CommunityApiException>()));
      expect(adapter.calls, hasLength(1));
    }

    // 502 is retried once.
    CommunityRawResponse badGateway() => failure(502, 'service_unavailable');
    adapter = FakeAdapter([badGateway(), badGateway(), badGateway()]);
    await expectLater(
        creator(adapter,
                retryPolicy: CommunityRetryPolicy(
                    maxAttempts: 5,
                    backoffBase: const Duration(milliseconds: 1)))
            .settings
            .get(),
        throwsA(isA<CommunityApiException>()));
    expect(adapter.calls, hasLength(2));

    // A post carries a key, so it is safe to repeat; the same key both times.
    adapter =
        FakeAdapter([failure(503, 'service_unavailable'), json(201, postJson)]);
    c = creator(adapter)..setUser('ali');
    await c.posts.create(topicId: 'cm_top_1', body: 'hi');
    expect(adapter.calls, hasLength(2));
    expect(adapter.calls[0].headers['Idempotency-Key'], isNotEmpty);
    expect(adapter.calls[0].headers['Idempotency-Key'],
        adapter.calls[1].headers['Idempotency-Key']);

    // Creating a topic and editing a profile are not, so they are sent once.
    adapter = FakeAdapter(
        [failure(503, 'service_unavailable'), json(201, <String, Object?>{})]);
    await expectLater(creator(adapter).topics.create(name: 'Workout'),
        throwsA(isA<CommunityApiException>()));
    expect(adapter.calls, hasLength(1));
    adapter = FakeAdapter([dropped, json(200, <String, Object?>{})]);
    c = creator(adapter)..setUser('ali');
    await expectLater(c.community.updateProfile(bio: 'x'),
        throwsA(isA<CommunityTransportException>()));
    expect(adapter.calls, hasLength(1));

    // Retry-After from the server sets the wait.
    events.clear();
    adapter = FakeAdapter([
      json(503, {
        'error': {
          'code': 'service_unavailable',
          'message': 'wait',
          'retry_after_seconds': null
        }
      }, headers: {
        'retry-after': '0.05'
      }),
      settings(),
    ]);
    c = CommunityClient.serverSideSecret(
        apiKey: secretKey,
        baseUrl: base,
        httpAdapter: adapter,
        retryPolicy: quick,
        onDiagnostic: events.add);
    await c.settings.get();
    expect(events.whereType<RetryDiagnostic>().single.delay,
        const Duration(milliseconds: 50));
  });

  test('requests are shaped as the API expects', () async {
    final adapter = FakeAdapter(List.generate(7,
        (_) => (Call _) => json(200, <String, Object?>{'topics': <Object>[]})));
    final c = CommunityClient.serverSideSecret(
        apiKey: secretKey,
        baseUrl: '$base/',
        httpAdapter: adapter,
        headers: {'X-App-Version': '1.2.0', 'Authorization': 'Bearer stolen'})
      ..setUser('user 42');
    await c.topics.list(trending: true);
    await c.topics.list();
    expect(adapter.calls[0].uri.toString(), '$base/v1/topics?trending=true');
    expect(adapter.calls[1].uri.toString(), '$base/v1/topics');
    expect(adapter.calls[0].headers['X-External-Id'], 'user 42');
    expect(adapter.calls[0].headers['X-App-Version'], '1.2.0');
    expect(adapter.calls[0].headers['Authorization'], 'Bearer $secretKey');
    // Arguments that cannot be right fail locally.
    await expectLater(
        c.posts.search('a'), throwsA(isA<CommunityValidationException>()));
    await expectLater(c.posts.feed(before: 'a', after: 'b'),
        throwsA(isA<CommunityValidationException>()));
    await expectLater(
        c.posts.get(''), throwsA(isA<CommunityValidationException>()));
    expect(adapter.calls, hasLength(2));
  });

  test('models are read from the API\'s JSON', () async {
    final adapter = FakeAdapter([
      json(200, {
        'pinned': [postJson],
        'posts': <Object>[],
        'next_cursor': null,
        'prev_cursor': null,
        'newest_cursor': 'abc',
        'has_more': false,
        'mode': 'pages',
        'page_size': 20,
      }),
      json(200, settingsJson),
      json(200, {...settingsJson, 'feed_mode': 'carousel'}),
    ]);
    final c = creator(adapter);
    final feed = await c.posts.feed(topicId: 'cm_top_1', limit: 10);
    expect(adapter.calls[0].uri.toString(),
        '$base/v1/posts?topic_id=cm_top_1&limit=10');
    final post = feed.pinned.single;
    expect(post.id, 'cm_post_1');
    expect(post.author.role, Role.coach);
    expect(post.images.single.width, 1024);
    expect(post.images.single.smallUrl, 'https://storage.test/1_512');
    expect(post.images.single.smallWidth, 512);
    expect(post.images.single.smallHeight, 384);
    expect(post.reactions.single.reactedByMe, isFalse);
    expect(post.pinnedAt, DateTime.utc(2026, 11, 16, 10));
    expect(post.createdAt.microsecond, 456);
    expect(feed.mode, FeedMode.pages);
    expect(feed.nextCursor, isNull);
    expect(feed.newestCursor, 'abc');
    final settings = await c.settings.get();
    expect(settings.removedByThreshold, isNull);
    // A value newer than the SDK does not break reading.
    expect((await c.settings.get()).feedMode, FeedMode.unknown);
  });

  test('push: a phone is registered, and signing out unregisters it', () async {
    const token = 'fcm-token:abc';
    final adapter = FakeAdapter([
      session(),
      json(200, {'provider': 'fcm', 'platform': 'android', 'registered': true}),
      json(200, {'enabled': true, 'community_enabled': true, 'devices': 1}),
      json(200, {'enabled': false, 'community_enabled': true, 'devices': 1}),
      json(200, {'removed': true}),
      json(204, null),
    ]);
    final c = CommunityClient.publishable(
        apiKey: publishableKey, baseUrl: base, httpAdapter: adapter);
    await c.initialize('ali');
    await expectLater(
        c.push.register(''), throwsA(isA<CommunityValidationException>()));
    final device = await c.push.register(token, platform: PushPlatform.android);
    expect(device.provider, PushProvider.fcm);
    expect(device.platform, PushPlatform.android);
    expect('${adapter.calls[1].method} ${adapter.calls[1].path}',
        'PUT /v1/push/devices');
    expect(adapter.calls[1].json, {'token': token, 'platform': 'android'});
    expect(c.push.registeredToken, token);
    expect((await c.push.preference()).devices, 1);
    expect((await c.push.setEnabled(false)).enabled, isFalse);
    expect(adapter.calls[3].json, {'enabled': false});
    // Signing out forgets the phone first, while the session still works.
    await c.signOut();
    expect('${adapter.calls[4].method} ${adapter.calls[4].path}',
        'POST /v1/push/devices/unregister');
    expect(adapter.calls[4].json, {'token': token});
    expect(adapter.calls[4].headers['X-Community-Session'], sessionToken);
    expect(adapter.calls[5].method, 'DELETE');
    expect(c.push.registeredToken, isNull);
    expect(c.sessionToken, isNull);
  });

  test('community.summary returns the member count and a few photos', () async {
    final adapter = FakeAdapter([
      session(),
      json(200, {
        'members_count': 124,
        'avatar_urls': ['https://img/a.webp', 'https://img/b.webp']
      }),
    ]);
    final c = CommunityClient.publishable(
        apiKey: publishableKey, baseUrl: base, httpAdapter: adapter);
    await c.initialize('ali');
    final summary = await c.community.summary();
    expect(summary.membersCount, 124);
    expect(summary.avatarUrls, ['https://img/a.webp', 'https://img/b.webp']);
    expect('${adapter.calls[1].method} ${adapter.calls[1].path}',
        'GET /v1/community/summary');
  });

  test('the moderation archive is read with a secret key', () async {
    final item = {
      'id': 'cm_arc_1',
      'kind': 'post',
      'target_id': 'cm_post_1',
      'post_id': 'cm_post_1',
      'parent_comment_id': null,
      'topic_id': 'cm_top_1',
      'body': 'spam',
      'images': <Object?>[],
      'author': {'external_id': 'author', 'username': 'Author'},
      'reason': 'reports',
      'reports': 5,
      'threshold': 5,
      'reported_by': [
        {
          'external_id': 'm0',
          'username': 'Mo',
          'reason': 'Spam content',
          'created_at': '2026-11-17T10:00:00Z'
        }
      ],
      'created_at': '2026-11-17T09:00:00Z',
      'archived_at': '2026-11-17T10:00:01Z',
    };
    final adapter = FakeAdapter([
      json(200, {
        'archived': [item],
        'next_cursor': 'abc'
      }),
      json(200, item),
    ]);
    final c = CommunityClient.serverSideSecret(
        apiKey: secretKey, baseUrl: base, httpAdapter: adapter);
    final page = await c.archive.list(limit: 2, before: 'xyz');
    expect(page.archived.single.id, 'cm_arc_1');
    expect(page.archived.single.reportedBy.single.reason, 'Spam content');
    expect(page.nextCursor, 'abc');
    final one = await c.archive.get('cm_arc_1');
    expect(one.body, 'spam');
    expect(one.author.externalId, 'author');
    expect(adapter.calls.map((x) => '${x.method} ${x.path}'), [
      'GET /v1/moderation/archive?limit=2&before=xyz',
      'GET /v1/moderation/archive/cm_arc_1',
    ]);
    expect(
        () => c.archive.get(''), throwsA(isA<CommunityValidationException>()));
  });

  test("a profile carries the member's post and comment counts", () async {
    final profile = {
      'external_id': 'ali',
      'username': 'Annie',
      'avatar_url': '',
      'cover_url': '',
      'bio': '',
      'role': 'user',
      'version': 1,
      'joined_at': '2026-11-17T09:00:00Z',
      'updated_at': '2026-11-17T09:00:00Z',
      'posts_count': 12,
      'comments_count': 48,
    };
    final adapter = FakeAdapter([
      session(),
      json(200, {'joined': true, 'profile': profile}),
      json(200, {...profile, 'is_me': false}),
    ]);
    final c = CommunityClient.publishable(
        apiKey: publishableKey, baseUrl: base, httpAdapter: adapter);
    await c.initialize('sara');
    final me = await c.community.me();
    expect(me.profile!.postsCount, 12);
    expect(me.profile!.commentsCount, 48);
    final other = await c.community.member('ali');
    expect(other.postsCount, 12);
    expect(other.commentsCount, 48);
  });

  test('the SDK has a call for every route in the contract', () {
    expect(operations, hasLength(55));
    expect(operations.map((o) => o.sdk).toSet(), implemented);
  });

  test(
      'a reaction chip tapped fast sends one request at a time and ends where the user left it',
      () async {
    final gates = <Completer<void>>[];
    final sent = <String>[];
    Future<CommunityRawResponse> answer(Call call) async {
      sent.add(call.method);
      final gate = Completer<void>();
      gates.add(gate);
      await gate.future;
      return json(200, {
        'post_id': 'cm_post_1',
        'reactions': call.method == 'PUT'
            ? [
                {'emoji': '🔥', 'count': 1, 'reacted_by_me': true},
              ]
            : <Object>[],
      });
    }

    final c = creator(FakeAdapter(List.generate(6, (_) => answer)))
      ..setUser('ali');
    final taps = [true, false, true, false, true]
        .map((on) => c.reactions.setOnPost('cm_post_1', '🔥', on: on))
        .toList();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(sent, ['PUT'], reason: 'more than one request was in flight');
    gates.removeAt(0).complete();
    final results = await Future.wait(taps);
    expect(sent, ['PUT'], reason: 'the final state matched what was sent');
    expect(results.every((r) => r.reactions.single.count == 1), isTrue);

    sent.clear();
    final two = [
      c.reactions.setOnPost('cm_post_1', '🔥', on: true),
      c.reactions.setOnPost('cm_post_1', '🔥', on: false)
    ];
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(sent, ['PUT']);
    gates.removeAt(0).complete();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(sent, ['PUT', 'DELETE']);
    gates.removeAt(0).complete();
    expect((await Future.wait(two)).every((r) => r.reactions.isEmpty), isTrue);
  });

  test('applyReaction works out the list to show at once', () {
    const before = [
      Reaction(emoji: '❤️', count: 2, reactedByMe: false),
      Reaction(emoji: '🔥', count: 1, reactedByMe: true)
    ];
    String show(List<Reaction> list) => list
        .map((r) => '${r.emoji}${r.count}${r.reactedByMe ? '*' : ''}')
        .join(' ');
    expect(show(applyReaction(before, '❤️', on: true)), '❤️3* 🔥1*');
    expect(show(applyReaction(before, '🚀', on: true)), '❤️2 🔥1* 🚀1*');
    expect(show(applyReaction(before, '🔥', on: false)), '❤️2');
    expect(show(applyReaction(before, '🔥', on: true)), show(before));
    expect(show(applyReaction(before, '❤️', on: false)), show(before));
  });

  test('upload asks for a link, sends the bytes, and finishes', () async {
    final adapter = FakeAdapter([
      json(201, {
        'id': 'cm_med_1',
        'status': 'pending',
        'upload': {
          'method': 'PUT',
          'url': 'https://storage.test/put?sig=1',
          'expires_at': '2030-01-01T00:00:00Z'
        },
        'max_bytes': 100,
      }),
      CommunityRawResponse(
          statusCode: 200, headers: const {}, bodyBytes: Uint8List(0)),
      json(200, {
        'id': 'cm_med_1',
        'status': 'ready',
        'url': 'https://storage.test/get',
        'width': 10,
        'height': 10,
        'bytes': 5,
        'attached': false
      }),
    ]);
    final c = creator(adapter)..setUser('ali');
    final image = await c.media
        .upload(Uint8List.fromList([1, 2, 3]), contentType: 'image/png');
    expect(image.status, MediaStatus.ready);
    expect(adapter.calls[1].uri.toString(), 'https://storage.test/put?sig=1');
    expect(adapter.calls[1].method, 'PUT');
    expect(adapter.calls[1].headers.containsKey('Authorization'), isFalse,
        reason: 'the key was sent to storage');
    expect(adapter.calls[1].headers['Content-Type'], 'image/png');
    expect(adapter.calls[2].path, '/v1/media/cm_med_1/complete');
    await expectLater(c.media.upload(Uint8List(0)),
        throwsA(isA<CommunityValidationException>()));
  });
}

const Map<String, Object?> settingsJson = {
  'max_images_per_post': 3,
  'reaction_order': 'most_used',
  'comment_replies_enabled': false,
  'feed_mode': 'infinite_scroll',
  'report_threshold': 5,
  'search_page_size': 10,
  'bio_max_length': 300,
  'profile_viewing_enabled': true,
  'push_enabled': true,
  'max_image_upload_bytes': 10485760,
  'image_uploads_enabled': true,
};

/// Every SDK call, by the name the contract gives its route. A route added to
/// the API fails the test above until its call is written and listed here.
const Set<String> implemented = {
  'client.whoAmI',
  'client.currentUser',
  'auth.createSession',
  'auth.endSession',
  'users.delete',
  'community.me',
  'community.usernameAvailable',
  'community.join',
  'community.updateProfile',
  'community.member',
  'community.summary',
  'members.list',
  'members.setRole',
  'topics.list',
  'topics.get',
  'topics.create',
  'topics.update',
  'topics.delete',
  'posts.feed',
  'posts.create',
  'posts.get',
  'posts.delete',
  'posts.pin',
  'posts.unpin',
  'posts.search',
  'reactions.addToPost',
  'reactions.removeFromPost',
  'reactions.addToComment',
  'reactions.removeFromComment',
  'comments.list',
  'comments.replies',
  'comments.create',
  'comments.delete',
  'media.start',
  'media.complete',
  'media.get',
  'blocks.list',
  'blocks.block',
  'blocks.unblock',
  'reports.reportPost',
  'reports.reportComment',
  'reports.list',
  'archive.list',
  'archive.get',
  'notifications.list',
  'notifications.unreadCount',
  'notifications.markAllRead',
  'notifications.markRead',
  'push.register',
  'push.unregister',
  'push.preference',
  'push.setEnabled',
  'settings.get',
  'settings.update',
  'live.connect',
};
