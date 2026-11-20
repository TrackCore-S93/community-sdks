import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:trackcore_community/trackcore_community.dart';

import 'helpers.dart';

Map<String, Object?> message(
        {String id = 'cm_msg_1',
        bool fromCoach = false,
        String body = 'Hi Coach!',
        Object? author = const {
          'external_id': 'ali',
          'username': 'Annie',
          'avatar_url': '',
          'role': 'user'
        },
        List<Object?> files = const [],
        String? editedAt}) =>
    {
      'id': id,
      'author': author,
      'from_coach': fromCoach,
      'body': body,
      'images': <Object?>[],
      'files': files,
      'is_mine': !fromCoach,
      'is_read': false,
      'edited_at': editedAt,
      'created_at': '2026-11-20T10:00:00Z',
    };

Map<String, Object?> page(List<Object?> messages) => {
      'messages': messages,
      'older_cursor': 'old',
      'newer_cursor': 'new',
      'has_older': true,
      'has_newer': false,
    };

const voice = {
  'id': 'cm_att_1',
  'kind': 'voice',
  'name': 'note.m4a',
  'content_type': 'audio/mp4',
  'bytes': 9000,
  'duration_ms': 15000,
  'url': 'https://files.test/n',
};

/// A socket the test feeds by hand.
class FakeSocket implements LiveSocket {
  final StreamController<String> incoming = StreamController<String>();
  @override
  Stream<String> get messages => incoming.stream;
  @override
  void send(String text) {}
  @override
  Future<void> close() => incoming.close();
}

Future<(CommunityClient, FakeAdapter)> member(List<Object> replies) async {
  final adapter = FakeAdapter([session(), ...replies]);
  final c = app(adapter);
  await c.initialize('ali');
  adapter.calls.clear();
  return (c, adapter);
}

void main() {
  test('a member reads their coaching chat', () async {
    final (c, adapter) = await member([
      json(200, {'unread_count': 2, 'last_message_at': '2026-11-20T10:00:00Z'}),
      json(200, page([message()])),
      json(200, page([])),
      json(200, {'unread_count': 0, 'last_message_at': null}),
    ]);
    final chat = await c.coachChat.get();
    expect(chat.unreadCount, 2);
    expect(adapter.calls[0].path, '/v1/coach-chat');

    final first = await c.coachChat.messages();
    expect(first.messages.single.body, 'Hi Coach!');
    expect(first.messages.single.fromCoach, isFalse);
    expect(first.olderCursor, 'old');

    await c.coachChat.messages(limit: 20, around: 'cm_msg_9');
    expect(adapter.calls[2].path,
        '/v1/coach-chat/messages?limit=20&around=cm_msg_9');

    final read = await c.coachChat.markRead();
    expect(read.unreadCount, 0);
    expect(adapter.calls[3].method, 'POST');
    expect(adapter.calls[3].path, '/v1/coach-chat/read');

    await expectLater(c.coachChat.messages(before: 'a', after: 'b'),
        throwsA(isA<CommunityValidationException>()));
    expect(adapter.calls, hasLength(4));
  });

  test('a member sends, edits, deletes and searches', () async {
    final (c, adapter) = await member([
      json(201, message()),
      json(201, message()),
      json(200, message(body: 'Hi!', editedAt: '2026-11-20T10:05:00Z')),
      json(200, {'id': 'cm_msg_1', 'deleted': true}),
      json(200, {
        'messages': [message()],
        'next_cursor': null,
        'has_more': false
      }),
    ]);
    await c.coachChat.send(body: 'Hi Coach!', mediaIds: ['cm_med_1']);
    expect(adapter.calls[0].json, {
      'body': 'Hi Coach!',
      'media_ids': ['cm_med_1']
    });
    expect(adapter.calls[0].headers[communityIdempotencyHeader], isNotEmpty);

    await c.coachChat.send(body: 'Once', idempotencyKey: 'k1');
    expect(adapter.calls[1].headers[communityIdempotencyHeader], 'k1');

    final edited = await c.coachChat.edit('cm_msg_1', 'Hi!');
    expect(edited.editedAt, isNotNull);
    expect(adapter.calls[2].method, 'PATCH');
    expect(adapter.calls[2].path, '/v1/coach-chat/messages/cm_msg_1');
    expect(adapter.calls[2].json, {'body': 'Hi!'});

    expect((await c.coachChat.delete('cm_msg_1')).deleted, isTrue);
    expect(adapter.calls[3].method, 'DELETE');

    final found = await c.coachChat.search('  plan ', limit: 10);
    expect(found.messages, hasLength(1));
    expect(adapter.calls[4].path, '/v1/coach-chat/search?q=plan&limit=10');

    await expectLater(
        c.coachChat.search('a'), throwsA(isA<CommunityValidationException>()));
    await expectLater(c.coachChat.edit('', 'x'),
        throwsA(isA<CommunityValidationException>()));
    expect(adapter.calls, hasLength(5));
  });

  test("the coach's messages carry voice notes and files", () async {
    final (c, _) = await member([
      json(
          200,
          page([
            message(
                id: 'cm_msg_2',
                fromCoach: true,
                body: '',
                author: null,
                files: [voice])
          ])),
    ]);
    final got = (await c.coachChat.messages()).messages.single;
    expect(got.fromCoach, isTrue);
    expect(got.author, isNull);
    expect(got.files.single.kind, 'voice');
    expect(got.files.single.durationMs, 15000);
    expect(got.files.single.url, 'https://files.test/n');
  });

  test("the coach's side needs a secret key and a named coach", () async {
    final (device, deviceAdapter) = await member([]);
    for (final call in <Future<Object?> Function()>[
      () => device.coachChat.sendAsCoach('ali', body: 'x'),
      () => device.coachChat.startFile(
          kind: CoachFileKind.file,
          fileName: 'a.pdf',
          contentType: 'application/pdf'),
      () => device.coachChat.completeFile('cm_att_1'),
    ]) {
      await expectLater(
          call(),
          throwsA(isA<CommunityConfigurationException>().having((e) => e.reason,
              'reason', CommunityConfigurationReason.secretKeyRequired)));
    }
    expect(deviceAdapter.calls, isEmpty);

    final adapter = FakeAdapter([]);
    final server = creator(adapter);
    await expectLater(
        server.coachChat.sendAsCoach('ali', body: 'x'),
        throwsA(isA<CommunityConfigurationException>().having(
            (e) => e.reason, 'reason', CommunityConfigurationReason.noUser)));
    expect(adapter.calls, isEmpty);
  });

  test('chat events arrive on the live connection, though they name no post',
      () async {
    final socket = FakeSocket();
    final c = CommunityClient.publishable(
        apiKey: publishableKey,
        baseUrl: base,
        httpAdapter: FakeAdapter([session()]),
        retryPolicy: quick,
        liveSocket: (uri, headers) async => socket);
    await c.initialize('ali');
    final connection = c.live.connect();
    final got = <LiveEvent>[];
    final listening = connection.events.listen(got.add);
    await Future<void>.delayed(Duration.zero);

    socket.incoming.add(jsonEncode({'type': 'ready'}));
    socket.incoming.add(jsonEncode({'type': 'watching', 'topic_id': ''}));
    socket.incoming.add(jsonEncode({
      'type': 'coach_message.created',
      'message_id': 'cm_msg_9',
      'author_external_id': 'coach_1'
    }));
    socket.incoming.add(jsonEncode({'type': 'coach_chat.read'}));
    socket.incoming.add(jsonEncode({
      'type': 'post.created',
      'topic_id': 'cm_top_1',
      'post_id': 'cm_post_1',
      'author_external_id': 'sara'
    }));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(got.map((e) => e.type), [
      LiveEventType.coachMessageCreated,
      LiveEventType.coachChatRead,
      LiveEventType.postCreated,
    ]);
    expect(got[0].messageId, 'cm_msg_9');
    expect(got[0].authorExternalId, 'coach_1');
    expect(got[0].postId, isNull);
    expect(got[2].postId, 'cm_post_1');

    await listening.cancel();
    await connection.close();
    c.close();
  });

  test('the coach lists the chats, opens one and marks it read', () async {
    final adapter = FakeAdapter([
      json(200, {
        'chats': [
          {
            'member': {
              'external_id': 'ali',
              'username': 'Annie',
              'avatar_url': '',
              'role': 'user'
            },
            'unread_count': 2,
            'last_message_at': '2026-11-20T10:00:00Z',
            'last_message': {
              'id': 'cm_msg_1',
              'body': 'Hi Coach!',
              'from_coach': false,
              'images_count': 0,
              'files_count': 0
            },
          }
        ],
        'next_cursor': 'more',
        'has_more': true,
      }),
      json(200, {'chats': <Object>[], 'next_cursor': null, 'has_more': false}),
      json(
          200,
          page([
            {...message(), 'is_mine': false}
          ])),
      json(200, {'unread_count': 0, 'last_message_at': '2026-11-20T10:00:00Z'}),
    ]);
    final c = creator(adapter)..setUser('coach_1');

    final list = await c.coachChat.chats();
    expect(list.chats.single.member.externalId, 'ali');
    expect(list.chats.single.unreadCount, 2);
    expect(list.chats.single.lastMessage.body, 'Hi Coach!');
    expect(adapter.calls[0].path, '/v1/coach-chat/members');
    expect(adapter.calls[0].headers[communityExternalIdHeader], 'coach_1');

    await c.coachChat
        .chats(limit: 10, before: list.nextCursor, unreadOnly: true);
    expect(adapter.calls[1].uri.queryParameters,
        {'limit': '10', 'before': 'more', 'unread': 'true'});

    final chat = await c.coachChat.memberMessages('ali', limit: 20);
    expect(chat.messages.single.isMine, isFalse);
    expect(
        adapter.calls[2].path, '/v1/coach-chat/members/ali/messages?limit=20');

    final read = await c.coachChat.markMemberRead('ali');
    expect(read.unreadCount, 0);
    expect(adapter.calls[3].method, 'POST');
    expect(adapter.calls[3].path, '/v1/coach-chat/members/ali/read');

    await expectLater(
        c.coachChat.memberMessages('ali', before: 'a', around: 'b'),
        throwsA(isA<CommunityValidationException>()));
    expect(adapter.calls, hasLength(4));
  });

  test('the coach answers a member, with a file', () async {
    final file = {
      'id': 'cm_att_1',
      'kind': 'file',
      'name': 'plan.pdf',
      'content_type': 'application/pdf',
      'bytes': 4,
      'duration_ms': null,
      'url': 'https://files.test/p',
    };
    final adapter = FakeAdapter([
      json(201, {
        'id': 'cm_att_1',
        'kind': 'file',
        'name': 'plan.pdf',
        'upload': {
          'method': 'PUT',
          'url': 'https://bucket.test/put',
          'expires_at': '2026-11-20T10:15:00Z'
        },
        'max_bytes': 100,
      }),
      json(200, <String, Object?>{}),
      json(200, file),
      json(
          201,
          message(
              id: 'cm_msg_3',
              fromCoach: true,
              body: 'Your plan',
              files: [file])),
    ]);
    final c = creator(adapter)..setUser('coach_1');

    final uploaded = await c.coachChat.uploadFile(
        Uint8List.fromList([1, 2, 3, 4]),
        kind: CoachFileKind.file,
        fileName: 'plan.pdf',
        contentType: 'application/pdf');
    expect(uploaded.id, 'cm_att_1');
    expect(adapter.calls[0].path, '/v1/coach-chat/files');
    expect(adapter.calls[0].headers[communityExternalIdHeader], 'coach_1');
    expect(adapter.calls[0].json, {
      'kind': 'file',
      'file_name': 'plan.pdf',
      'content_type': 'application/pdf'
    });
    // The file goes to the link with its type and without the key.
    expect(adapter.calls[1].uri.toString(), 'https://bucket.test/put');
    expect(adapter.calls[1].method, 'PUT');
    expect(adapter.calls[1].headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('authorization')));
    expect(adapter.calls[2].path, '/v1/coach-chat/files/cm_att_1/complete');

    final sent = await c.coachChat
        .sendAsCoach('ali', body: 'Your plan', fileIds: ['cm_att_1']);
    expect(sent.files.single.name, 'plan.pdf');
    expect(adapter.calls[3].path, '/v1/coach-chat/members/ali/messages');
    expect(adapter.calls[3].headers[communityExternalIdHeader], 'coach_1');
    expect(adapter.calls[3].json, {
      'body': 'Your plan',
      'file_ids': ['cm_att_1']
    });
  });

  test('an empty or oversized file is refused before it is sent', () async {
    final adapter = FakeAdapter([
      json(201, {
        'id': 'cm_att_1',
        'kind': 'voice',
        'name': 'n.m4a',
        'upload': {
          'method': 'PUT',
          'url': 'https://bucket.test/put',
          'expires_at': '2026-11-20T10:15:00Z'
        },
        'max_bytes': 2,
      }),
    ]);
    final c = creator(adapter)..setUser('coach_1');
    await expectLater(
        c.coachChat.uploadFile(Uint8List(0),
            kind: CoachFileKind.voice,
            fileName: 'n.m4a',
            contentType: 'audio/mp4'),
        throwsA(isA<CommunityValidationException>()));
    expect(adapter.calls, isEmpty);
    await expectLater(
        c.coachChat.uploadFile(Uint8List(3),
            kind: CoachFileKind.voice,
            fileName: 'n.m4a',
            contentType: 'audio/mp4',
            durationMs: 1500),
        throwsA(isA<CommunityValidationException>()));
    expect(adapter.calls, hasLength(1));
    expect((adapter.calls[0].json! as Map)['duration_ms'], 1500);
  });
}
