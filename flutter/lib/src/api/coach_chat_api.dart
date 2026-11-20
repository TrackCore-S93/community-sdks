/// The coaching chat: a member's one-to-one chat with their coach.
library;

import 'dart:typed_data';

import '../errors/exceptions.dart';
import '../generated/models.dart';
import '../http/transport.dart';
import 'apis.dart' show newIdempotencyKey;

Map<String, Object?> _object(Object? json) =>
    (json! as Map).cast<String, Object?>();

String _enc(String value) => Uri.encodeComponent(value);

void _required(String field, String value) {
  if (value.isEmpty) {
    throw CommunityValidationException(field, '$field is required.');
  }
}

Map<String, Object?> _given(Map<String, Object?> values) => {
      for (final entry in values.entries)
        if (entry.value != null) entry.key: entry.value,
    };

/// What a file on a chat message is.
enum CoachFileKind {
  /// A voice note, to play.
  voice,

  /// A document, to open or save.
  file,
}

/// The coaching chat.
///
/// Every member has one chat; it needs no id and is made by its first
/// message. A member sends text and images. Voice notes and documents come
/// from the coach's side only.
///
/// [chats], [memberMessages], [markMemberRead], [startFile], [completeFile],
/// [uploadFile] and [sendAsCoach] are the coach's side. They need a secret
/// key, on a Dart server, and the coach named with `setUser`: a member of
/// the community whose role is coach or creator.
final class CoachChatApi {
  CoachChatApi(this._transport);
  final Transport _transport;

  /// The chat at a glance: the unread count for a badge, and when the last
  /// message was sent.
  Future<CoachChat> get() async => CoachChat.fromJson(_object(await _transport
      .request('GET', '/v1/coach-chat', audience: Audience.member)));

  /// One page of the chat, oldest first. With no cursor, the newest messages.
  ///
  /// Pass at most one of [before] (an `olderCursor`: the messages above),
  /// [after] (a `newerCursor`: the ones below, and how to catch up after a
  /// live event) and [around] (a message id: the page with that message in
  /// the middle, for a search result).
  Future<CoachMessagePage> messages(
      {int? limit, String? before, String? after, String? around}) async {
    final set = [before, after, around]
        .where((value) => value != null && value.isNotEmpty)
        .length;
    if (set > 1) {
      throw const CommunityValidationException(
          'before', 'Pass at most one of before, after and around.');
    }
    return CoachMessagePage.fromJson(_object(await _transport.request(
        'GET', '/v1/coach-chat/messages', audience: Audience.member, query: {
      'limit': limit,
      'before': before,
      'after': after,
      'around': around
    })));
  }

  /// Sends a message to the coach: text, images, or both. A retry cannot
  /// send twice: the SDK sends an idempotency key, its own unless you pass
  /// one. Sending also marks the chat read for the member.
  Future<CoachMessage> send(
          {String? body,
          List<String>? mediaIds,
          String? idempotencyKey}) async =>
      CoachMessage.fromJson(_object(await _transport.request(
          'POST', '/v1/coach-chat/messages',
          audience: Audience.member,
          idempotencyKey: idempotencyKey ?? newIdempotencyKey(),
          body: _given({'body': body, 'media_ids': mediaIds}))));

  /// Changes the text of one of the user's own messages. Its images stay.
  Future<CoachMessage> edit(String messageId, String body) async {
    _required('messageId', messageId);
    return CoachMessage.fromJson(_object(await _transport.request(
        'PATCH', '/v1/coach-chat/messages/${_enc(messageId)}',
        audience: Audience.member, body: {'body': body})));
  }

  /// Deletes one of the user's own messages for good, with its images.
  Future<Deleted> delete(String messageId) async {
    _required('messageId', messageId);
    return Deleted.fromJson(_object(await _transport.request(
        'DELETE', '/v1/coach-chat/messages/${_enc(messageId)}',
        audience: Audience.member)));
  }

  /// The user has seen the chat: call it while the chat is open and a
  /// message from the coach is on screen.
  Future<CoachChat> markRead() async => CoachChat.fromJson(_object(
      await _transport.request('POST', '/v1/coach-chat/read',
          audience: Audience.member, repeatable: true)));

  /// Finds messages by the words in their text, newest first. Jump to one
  /// with `messages(around: id)`.
  Future<CoachSearchResults> search(String q,
      {int? limit, String? before}) async {
    final text = q.trim();
    if (text.runes.length < 2) {
      throw const CommunityValidationException(
          'q', 'q must be at least 2 characters.');
    }
    return CoachSearchResults.fromJson(_object(await _transport.request(
        'GET', '/v1/coach-chat/search',
        audience: Audience.member,
        query: {'q': text, 'limit': limit, 'before': before})));
  }

  // ---- the coach's side ----

  /// The coach's list of chats: every member's chat that has a message, the
  /// one with the newest message first. Each has the member, how many of
  /// their messages the coach's side has not seen, and the newest message
  /// for a preview line. `nextCursor`, passed as [before], gives the next
  /// page. [unreadOnly] keeps only the chats with something unseen.
  Future<CoachChatList> chats(
          {int? limit, String? before, bool unreadOnly = false}) async =>
      CoachChatList.fromJson(_object(await _transport.request(
          'GET', '/v1/coach-chat/members', audience: Audience.coach, query: {
        'limit': limit,
        'before': before,
        'unread': unreadOnly ? true : null
      })));

  /// One page of one member's chat as the coach's side sees it, oldest
  /// first, with the same cursors as [messages]. `isMine` is true on the
  /// messages the coach's side wrote. Reading does not mark the chat read:
  /// call [markMemberRead] for that.
  Future<CoachMessagePage> memberMessages(String memberId,
      {int? limit, String? before, String? after, String? around}) async {
    assertValidExternalId(memberId);
    final set = [before, after, around]
        .where((value) => value != null && value.isNotEmpty)
        .length;
    if (set > 1) {
      throw const CommunityValidationException(
          'before', 'Pass at most one of before, after and around.');
    }
    return CoachMessagePage.fromJson(_object(await _transport.request(
        'GET', '/v1/coach-chat/members/${_enc(memberId)}/messages',
        audience: Audience.coach,
        query: {
          'limit': limit,
          'before': before,
          'after': after,
          'around': around
        })));
  }

  /// The coach has seen the member's chat: the member's messages show as
  /// read in their app.
  Future<CoachChat> markMemberRead(String memberId) async {
    assertValidExternalId(memberId);
    return CoachChat.fromJson(_object(await _transport.request(
        'POST', '/v1/coach-chat/members/${_enc(memberId)}/read',
        audience: Audience.coach, repeatable: true)));
  }

  /// Step 1 of 3 for a voice note or a document: asks for a link to send it
  /// to. [uploadFile] does all three.
  Future<CoachFileUpload> startFile(
      {required CoachFileKind kind,
      required String fileName,
      required String contentType,
      int? durationMs}) async {
    _required('fileName', fileName);
    _required('contentType', contentType);
    return CoachFileUpload.fromJson(
        _object(await _transport.request('POST', '/v1/coach-chat/files',
            audience: Audience.coach,
            body: _given({
              'kind': kind.name,
              'file_name': fileName,
              'content_type': contentType,
              'duration_ms': durationMs,
            }))));
  }

  /// Step 3 of 3: tells the server the file has arrived.
  Future<CoachFile> completeFile(String fileId) async {
    _required('fileId', fileId);
    return CoachFile.fromJson(_object(await _transport.request(
        'POST', '/v1/coach-chat/files/${_enc(fileId)}/complete',
        audience: Audience.coach, repeatable: true)));
  }

  /// Uploads one voice note or document: asks for a link, sends the bytes to
  /// it, and finishes the upload. The returned file's `id` goes in
  /// [sendAsCoach]'s `fileIds`.
  Future<CoachFile> uploadFile(Uint8List bytes,
      {required CoachFileKind kind,
      required String fileName,
      required String contentType,
      int? durationMs}) async {
    if (bytes.isEmpty) {
      throw const CommunityValidationException('bytes', 'The file is empty.');
    }
    final started = await startFile(
        kind: kind,
        fileName: fileName,
        contentType: contentType,
        durationMs: durationMs);
    if (bytes.length > started.maxBytes) {
      throw CommunityValidationException('bytes',
          'The file is larger than the upload limit of ${started.maxBytes} bytes.');
    }
    final response = await _transport.sendTo(Uri.parse(started.upload.url),
        started.upload.method, bytes, contentType);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CommunityTransportException(
          'Storage refused the file (HTTP ${response.statusCode}).',
          kind: CommunityTransportFailure.other,
          attempts: 1);
    }
    return completeFile(started.id);
  }

  /// Sends a message into one member's chat as the coach: text, images,
  /// files, or any mix. It makes the chat if this is its first message, and
  /// marks the chat read for the coach's side.
  Future<CoachMessage> sendAsCoach(String memberId,
      {String? body,
      List<String>? mediaIds,
      List<String>? fileIds,
      String? idempotencyKey}) async {
    assertValidExternalId(memberId);
    return CoachMessage.fromJson(_object(await _transport.request(
        'POST', '/v1/coach-chat/members/${_enc(memberId)}/messages',
        audience: Audience.coach,
        idempotencyKey: idempotencyKey ?? newIdempotencyKey(),
        body: _given(
            {'body': body, 'media_ids': mediaIds, 'file_ids': fileIds}))));
  }
}
