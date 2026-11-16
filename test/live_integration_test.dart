// The SDK against a real Community server, over the real network adapter.
// Skipped unless these are set:
//
//   COMMUNITY_TEST_BASE_URL     where a test server answers, e.g. http://localhost:8099
//   COMMUNITY_TEST_ADMIN_TOKEN  that server's operator token, used to create a
//                               throwaway customer and its keys
//
// Never point this at a live server: it creates a customer and writes data.
@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:trackcore_community/trackcore_community.dart';

final String? baseUrl = Platform.environment['COMMUNITY_TEST_BASE_URL'];
final String? adminToken = Platform.environment['COMMUNITY_TEST_ADMIN_TOKEN'];

Future<Map<String, Object?>> admin(
    String path, Map<String, Object?> body) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(Uri.parse('$baseUrl$path'));
    request.headers.set('Authorization', 'Bearer $adminToken');
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
    final response = await request.close();
    final text = await utf8.decodeStream(response);
    if (response.statusCode >= 300) {
      throw StateError('$path: ${response.statusCode}');
    }
    return (jsonDecode(text) as Map).cast<String, Object?>();
  } finally {
    client.close();
  }
}

Future<void> until(String what, bool Function() check) async {
  final end = DateTime.now().add(const Duration(seconds: 5));
  while (DateTime.now().isBefore(end)) {
    if (check()) return;
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
  fail('timed out waiting for $what');
}

void main() {
  final skip = baseUrl == null || adminToken == null
      ? 'set COMMUNITY_TEST_BASE_URL and COMMUNITY_TEST_ADMIN_TOKEN to run'
      : null;

  test('a whole community, through the SDK', skip: skip, () async {
    final slug =
        'dart${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    await admin('/admin/v1/customers', {'name': 'Dart test', 'slug': slug});
    final secret = (await admin('/admin/v1/customers/$slug/keys', {
      'kind': 'secret',
      'environment': 'test',
      'name': 'dart'
    }))['key']! as String;
    final publishable = (await admin('/admin/v1/customers/$slug/keys', {
      'kind': 'publishable',
      'environment': 'test',
      'name': 'dart'
    }))['key']! as String;

    // The creator's backend: a secret key.
    final creator =
        CommunityClient.serverSideSecret(apiKey: secret, baseUrl: baseUrl!);
    expect((await creator.whoAmI()).keyKind, 'secret');
    final settings = await creator.settings.update(
        commentRepliesEnabled: true, feedPageSize: 2, feedMode: FeedMode.pages);
    expect(settings.commentRepliesEnabled, isTrue);
    expect(settings.feedMode, FeedMode.pages);
    final workout =
        await creator.topics.create(name: 'Workout', isTrending: true);
    final food = await creator.topics.create(name: 'Food');
    await expectLater(
        creator.topics.create(name: 'workout'),
        throwsA(isA<CommunityApiException>()
            .having((e) => e.code, 'code', CommunityErrorCode.topicNameTaken)));

    // Two apps: a publishable key, each signing its own user in.
    final ali =
        CommunityClient.publishable(apiKey: publishable, baseUrl: baseUrl!);
    final sara =
        CommunityClient.publishable(apiKey: publishable, baseUrl: baseUrl!);
    await ali.initialize('ali');
    await sara.initialize('sara');
    expect((await ali.currentUser()).viaSession, isTrue);

    expect((await ali.community.me()).joined, isFalse);
    await expectLater(
        ali.posts.create(topicId: workout.id, body: 'too early'),
        throwsA(isA<CommunityApiException>()
            .having((e) => e.isJoinRequired, 'isJoinRequired', isTrue)));
    expect((await ali.community.usernameAvailable('Annie')).available, isTrue);
    expect((await ali.community.join('Annie')).profile!.username, 'Annie');
    await expectLater(
        sara.community.join('ANNIE'),
        throwsA(isA<CommunityApiException>()
            .having((e) => e.code, 'code', CommunityErrorCode.usernameTaken)));
    await sara.community.join('Mary');
    try {
      await sara.community.updateProfile(username: 'x');
      fail('a bad username was accepted');
    } on CommunityApiException catch (e) {
      expect(e.code, CommunityErrorCode.validationFailed);
      expect(e.fields.containsKey('username'), isTrue);
    }
    expect((await sara.community.updateProfile(bio: 'Runner')).profile!.bio,
        'Runner');
    expect((await ali.community.member('sara')).username, 'Mary');
    expect((await ali.topics.list(trending: true)).map((t) => t.name),
        ['Workout']);

    // Live: sara's app listens while ali acts.
    final events = <LiveEvent>[];
    final connection = sara.live.connect();
    connection.events.listen(events.add);
    await until(
        'the live connection', () => connection.status == LiveStatus.open);

    final first = await ali.posts.create(
        topicId: workout.id, body: 'Leg day protein', idempotencyKey: 'post-1');
    final again = await ali.posts.create(
        topicId: workout.id, body: 'Leg day protein', idempotencyKey: 'post-1');
    expect(again.id, first.id, reason: 'the same key posted twice');
    await ali.posts.create(topicId: food.id, body: 'protein pancakes');
    await sara.posts.create(topicId: workout.id, body: 'rest day');
    await until(
        'post events',
        () =>
            events.where((e) => e.type == LiveEventType.postCreated).length >=
            3);
    expect(
        events.firstWhere((e) => e.postId == first.id).authorExternalId, 'ali');

    // The feed, a page at a time (the creator set 2 per page, pages mode).
    var page = await sara.posts.feed();
    expect(page.posts.map((p) => p.body), ['rest day', 'protein pancakes']);
    expect(page.mode, FeedMode.pages);
    expect(page.posts.first.isMine, isTrue);
    final older = await sara.posts.feed(before: page.nextCursor);
    expect(older.posts.map((p) => p.body), ['Leg day protein']);
    expect(older.prevCursor, isNotNull);
    expect((await sara.posts.search('prot')).posts.map((p) => p.body),
        ['protein pancakes', 'Leg day protein']);
    expect((await sara.posts.search('nothing here')).posts, isEmpty);

    // Reactions, including a chip tapped fast.
    final shown = applyReaction(first.reactions, '🔥', on: true);
    final taps = await Future.wait([true, false, true, false, true]
        .map((on) => sara.reactions.setOnPost(first.id, '🔥', on: on)));
    expect(taps.last.reactions.single.count, shown.single.count);
    await ali.reactions.addToPost(first.id, '❤️');
    final settled = (await ali.posts.get(first.id)).reactions;
    expect({for (final r in settled) r.emoji: r.count}, {'🔥': 1, '❤️': 1});

    // Comments, replies, notifications.
    final comment = await sara.comments.create(first.id, body: 'Nice work');
    final reply = await ali.comments
        .create(first.id, body: 'Thanks', parentId: comment.id);
    expect(reply.parentId, comment.id);
    expect((await ali.comments.list(first.id)).comments.single.repliesCount, 1);
    expect((await ali.comments.replies(comment.id)).comments.single.body,
        'Thanks');
    final inbox = await ali.notifications.list();
    expect(inbox.notifications.map((n) => n.kind).toSet(),
        {NotificationKind.postReaction, NotificationKind.postComment});
    expect(
        (await ali.notifications.markRead(inbox.notifications.first.id))
            .unreadCount,
        1);
    await ali.notifications.markAllRead();
    expect(await ali.notifications.unreadCount(), 0);
    await until('a live notification',
        () => events.any((e) => e.type == LiveEventType.notificationCreated));

    // The creator's dashboard.
    final members = await creator.members.list();
    expect(members.members.map((m) => m.username), ['Annie', 'Mary']);
    expect((await creator.members.setRole('ali', Role.coach)).role, Role.coach);
    expect((await sara.posts.get(first.id)).author.role, Role.coach);
    expect((await creator.posts.pin(first.id)).isPinned, isTrue);
    page = await sara.posts.feed();
    expect(page.pinned.map((p) => p.id), [first.id]);
    expect((await sara.reports.reportPost(first.id, 'Spam content')).reported,
        isTrue);
    expect(
        (await sara.reports.reportPost(first.id, 'Spam content'))
            .alreadyReported,
        isTrue);
    expect(
        (await creator.reports.list()).reports.single.reason, 'Spam content');

    // Blocking, deleting, signing out, erasing.
    expect((await sara.blocks.block('ali')).username, 'Annie');
    expect((await sara.blocks.list()).map((b) => b.externalId), ['ali']);
    await expectLater(
        sara.community.member('ali'),
        throwsA(isA<CommunityApiException>()
            .having((e) => e.code, 'code', CommunityErrorCode.notFound)));
    expect((await sara.blocks.unblock('ali')).unblocked, isTrue);
    expect((await ali.posts.delete(first.id)).deleted, isTrue);
    await connection.close();
    expect(connection.status, LiveStatus.closed);
    final token = ali.sessionToken!;
    await ali.signOut();
    final stale =
        CommunityClient.publishable(apiKey: publishable, baseUrl: baseUrl!)
          ..setSession(token);
    await expectLater(
        stale.community.me(),
        throwsA(isA<CommunityApiException>()
            .having((e) => e.code, 'code', CommunityErrorCode.sessionInvalid)));
    expect((await creator.users.delete('sara')).deleted, isTrue);
    expect((await creator.members.list()).total, 1);
    for (final client in [creator, ali, sara, stale]) {
      client.close();
    }
  });
}
