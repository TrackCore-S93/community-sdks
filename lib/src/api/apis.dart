/// The feature APIs: one class per namespace of the client.
library;

import 'dart:math';

import '../errors/exceptions.dart';
import '../generated/models.dart';
import '../http/transport.dart';

Map<String, Object?> _object(Object? json) =>
    (json! as Map).cast<String, Object?>();

String _enc(String value) => Uri.encodeComponent(value);

void _required(String field, String value) {
  if (value.isEmpty) {
    throw CommunityValidationException(field, '$field is required.');
  }
}

final Random _random = Random.secure();

/// A key for a request that must not be applied twice when it is retried.
String newIdempotencyKey() {
  const hex = '0123456789abcdef';
  return List.generate(32, (_) => hex[_random.nextInt(16)]).join();
}

/// Removes the entries that were not given, so a partial edit sends only
/// what changes.
Map<String, Object?> _given(Map<String, Object?> values) => {
      for (final entry in values.entries)
        if (entry.value != null) entry.key: entry.value,
    };

/// Sessions. Minting one for a named user is what `initialize` does for you.
final class AuthApi {
  AuthApi(this._transport);
  final Transport _transport;

  /// Mints a session token for one end user. On a server, hand the token to
  /// that user's device.
  Future<Session> createSession(
      {required String externalId, int? ttlSeconds}) async {
    assertValidExternalId(externalId);
    return Session.fromJson(_object(await _transport.request(
        'POST', '/v1/auth/session',
        audience: Audience.anyKey,
        body: _given({'external_id': externalId, 'ttl_seconds': ttlSeconds}))));
  }

  /// Ends the session in use. `signOut` does this and forgets the user too.
  Future<void> endSession() async {
    await _transport.request('DELETE', '/v1/auth/session',
        audience: Audience.member);
  }
}

/// End users. Secret key only.
final class UsersApi {
  UsersApi(this._transport);
  final Transport _transport;

  /// Erases a user and everything stored for them. Erasing an unknown user
  /// is not an error.
  Future<ErasedUser> delete(String externalId) async {
    assertValidExternalId(externalId);
    return ErasedUser.fromJson(_object(await _transport.request(
        'DELETE', '/v1/users/${_enc(externalId)}',
        audience: Audience.creator)));
  }
}

/// Joining the community, and profiles.
final class CommunityApi {
  CommunityApi(this._transport);
  final Transport _transport;

  /// Whether the user has joined, and their own profile.
  Future<Membership> me() async => Membership.fromJson(_object(await _transport
      .request('GET', '/v1/community/me', audience: Audience.member)));

  /// Whether a username is free. A hint for the form; [join] decides.
  Future<UsernameAvailability> usernameAvailable(String username) async {
    _required('username', username);
    return UsernameAvailability.fromJson(_object(await _transport.request(
        'GET', '/v1/community/username-available',
        audience: Audience.member, query: {'username': username})));
  }

  /// Joins the community under a username. Joining again under the same
  /// name is safe.
  Future<Membership> join(String username) async {
    _required('username', username);
    return Membership.fromJson(_object(await _transport.request(
        'POST', '/v1/community/join',
        audience: Audience.member,
        body: {'username': username},
        repeatable: true)));
  }

  /// Edits the user's own profile. Pass only what changes; an empty media id
  /// removes that image.
  Future<Membership> updateProfile(
          {String? username,
          String? bio,
          String? avatarMediaId,
          String? coverMediaId}) async =>
      Membership.fromJson(
          _object(await _transport.request('PATCH', '/v1/community/me',
              audience: Audience.member,
              body: _given({
                'username': username,
                'bio': bio,
                'avatar_media_id': avatarMediaId,
                'cover_media_id': coverMediaId,
              }))));

  /// Another member's profile, read only.
  Future<Member> member(String externalId) async {
    assertValidExternalId(externalId);
    return Member.fromJson(_object(await _transport.request(
        'GET', '/v1/community/members/${_enc(externalId)}',
        audience: Audience.memberOrCreator)));
  }

  /// The community at a glance, for the card that leads into it: how many
  /// members it has, and the profile photos of up to four members who have
  /// one, picked at random on every call. The user need not have joined.
  Future<CommunitySummary> summary() async => CommunitySummary.fromJson(_object(
      await _transport.request('GET', '/v1/community/summary',
          audience: Audience.memberOrCreator)));
}

/// The creator's member list and roles. Secret key only.
final class MembersApi {
  MembersApi(this._transport);
  final Transport _transport;

  /// Everyone who has joined, in username order.
  Future<MemberList> list(
          {String? q, Role? role, int? limit, String? after}) async =>
      MemberList.fromJson(_object(await _transport.request(
          'GET', '/v1/community/members', audience: Audience.creator, query: {
        'q': q,
        'role': role?.wire,
        'limit': limit,
        'after': after
      })));

  /// Changes a member's role.
  Future<Profile> setRole(String externalId, Role role) async {
    assertValidExternalId(externalId);
    return Profile.fromJson(_object(await _transport.request(
        'PATCH', '/v1/community/members/${_enc(externalId)}',
        audience: Audience.creator,
        body: {'role': role.wire},
        repeatable: true)));
  }
}

/// Topics: the sections posts are written in.
final class TopicsApi {
  TopicsApi(this._transport);
  final Transport _transport;

  /// The community's topics. `trending: true` returns only trending ones.
  Future<List<Topic>> list({bool trending = false}) async =>
      TopicList.fromJson(_object(await _transport.request('GET', '/v1/topics',
              audience: Audience.memberOrCreator,
              query: {'trending': trending ? true : null})))
          .topics;

  /// One topic.
  Future<Topic> get(String topicId) async {
    _required('topicId', topicId);
    return Topic.fromJson(_object(await _transport.request(
        'GET', '/v1/topics/${_enc(topicId)}',
        audience: Audience.memberOrCreator)));
  }

  /// Creates a topic. Secret key only.
  Future<Topic> create({
    required String name,
    String? description,
    String? imageUrl,
    String? coverUrl,
    int? sortOrder,
    bool? isLive,
    bool? isTrending,
  }) async {
    _required('name', name);
    return Topic.fromJson(_object(await _transport.request('POST', '/v1/topics',
        audience: Audience.creator,
        body: _given({
          'name': name,
          'description': description,
          'image_url': imageUrl,
          'cover_url': coverUrl,
          'sort_order': sortOrder,
          'is_live': isLive,
          'is_trending': isTrending,
        }))));
  }

  /// Edits a topic. Pass only what changes. Secret key only.
  Future<Topic> update(
    String topicId, {
    String? name,
    String? description,
    String? imageUrl,
    String? coverUrl,
    int? sortOrder,
    bool? isLive,
    bool? isTrending,
  }) async {
    _required('topicId', topicId);
    return Topic.fromJson(
        _object(await _transport.request('PATCH', '/v1/topics/${_enc(topicId)}',
            audience: Audience.creator,
            body: _given({
              'name': name,
              'description': description,
              'image_url': imageUrl,
              'cover_url': coverUrl,
              'sort_order': sortOrder,
              'is_live': isLive,
              'is_trending': isTrending,
            }))));
  }

  /// Deletes a topic and its posts. Secret key only.
  Future<Deleted> delete(String topicId) async {
    _required('topicId', topicId);
    return Deleted.fromJson(_object(await _transport.request(
        'DELETE', '/v1/topics/${_enc(topicId)}',
        audience: Audience.creator)));
  }
}

/// Posts and the feed.
final class PostsApi {
  PostsApi(this._transport);
  final Transport _transport;

  /// One page of the feed, newest first. Pass [before] or [after], not both.
  Future<Feed> feed(
      {String? topicId, int? limit, String? before, String? after}) async {
    if (before != null && after != null) {
      throw const CommunityValidationException(
          'before', 'Pass before or after, not both.');
    }
    return Feed.fromJson(_object(await _transport.request('GET', '/v1/posts',
        audience: Audience.memberOrCreator,
        query: {
          'topic_id': topicId,
          'limit': limit,
          'before': before,
          'after': after
        })));
  }

  /// Writes a post: text, images, or both. A retry cannot post twice: an
  /// idempotency key is sent, the SDK's own unless you pass one.
  Future<Post> create(
      {required String topicId,
      String? body,
      List<String>? mediaIds,
      String? idempotencyKey}) async {
    _required('topicId', topicId);
    return Post.fromJson(_object(await _transport.request('POST', '/v1/posts',
        audience: Audience.member,
        idempotencyKey: idempotencyKey ?? newIdempotencyKey(),
        body: _given(
            {'topic_id': topicId, 'body': body, 'media_ids': mediaIds}))));
  }

  /// One post.
  Future<Post> get(String postId) async {
    _required('postId', postId);
    return Post.fromJson(_object(await _transport.request(
        'GET', '/v1/posts/${_enc(postId)}',
        audience: Audience.memberOrCreator)));
  }

  /// Deletes a post: a member their own, the creator's backend any.
  Future<Deleted> delete(String postId) async {
    _required('postId', postId);
    return Deleted.fromJson(_object(await _transport.request(
        'DELETE', '/v1/posts/${_enc(postId)}',
        audience: Audience.memberOrCreator)));
  }

  /// Pins a post to the top of the feed. Secret key only.
  Future<Post> pin(String postId) async {
    _required('postId', postId);
    return Post.fromJson(_object(await _transport.request(
        'PUT', '/v1/posts/${_enc(postId)}/pin',
        audience: Audience.creator)));
  }

  /// Unpins a post. Secret key only.
  Future<Post> unpin(String postId) async {
    _required('postId', postId);
    return Post.fromJson(_object(await _transport.request(
        'DELETE', '/v1/posts/${_enc(postId)}/pin',
        audience: Audience.creator)));
  }

  /// Posts whose text contains every word of [q]. No match is an empty list.
  Future<SearchResults> search(String q,
      {String? topicId, int? limit, String? before}) async {
    if (q.trim().runes.length < 2) {
      throw const CommunityValidationException(
          'q', 'q must be at least 2 characters.');
    }
    return SearchResults.fromJson(_object(await _transport.request(
        'GET', '/v1/search/posts', audience: Audience.memberOrCreator, query: {
      'q': q,
      'topic_id': topicId,
      'limit': limit,
      'before': before
    })));
  }
}

/// Comments and replies.
final class CommentsApi {
  CommentsApi(this._transport);
  final Transport _transport;

  /// A post's top-level comments, oldest first.
  Future<CommentPage> list(String postId, {int? limit, String? after}) async {
    _required('postId', postId);
    return CommentPage.fromJson(_object(await _transport.request(
        'GET', '/v1/posts/${_enc(postId)}/comments',
        audience: Audience.memberOrCreator,
        query: {'limit': limit, 'after': after})));
  }

  /// A comment's replies, oldest first.
  Future<CommentPage> replies(String commentId,
      {int? limit, String? after}) async {
    _required('commentId', commentId);
    return CommentPage.fromJson(_object(await _transport.request(
        'GET', '/v1/comments/${_enc(commentId)}/replies',
        audience: Audience.memberOrCreator,
        query: {'limit': limit, 'after': after})));
  }

  /// Comments on a post, or replies to a comment with [parentId]. A retry
  /// cannot comment twice.
  Future<Comment> create(String postId,
      {String? body,
      List<String>? mediaIds,
      String? parentId,
      String? idempotencyKey}) async {
    _required('postId', postId);
    return Comment.fromJson(_object(await _transport.request(
        'POST', '/v1/posts/${_enc(postId)}/comments',
        audience: Audience.member,
        idempotencyKey: idempotencyKey ?? newIdempotencyKey(),
        body: _given(
            {'body': body, 'media_ids': mediaIds, 'parent_id': parentId}))));
  }

  /// Deletes a comment: a member their own, the creator's backend any.
  Future<Deleted> delete(String commentId) async {
    _required('commentId', commentId);
    return Deleted.fromJson(_object(await _transport.request(
        'DELETE', '/v1/comments/${_enc(commentId)}',
        audience: Audience.memberOrCreator)));
  }
}

/// Blocking members.
final class BlocksApi {
  BlocksApi(this._transport);
  final Transport _transport;

  /// The members the user has blocked.
  Future<List<BlockedMember>> list() async =>
      BlockList.fromJson(_object(await _transport.request('GET', '/v1/blocks',
              audience: Audience.member)))
          .blocked;

  /// Blocks a member. Blocking again changes nothing.
  Future<BlockedMember> block(String externalId) async {
    assertValidExternalId(externalId);
    return BlockedMember.fromJson(_object(await _transport.request(
        'PUT', '/v1/blocks/${_enc(externalId)}',
        audience: Audience.member)));
  }

  /// Unblocks a member.
  Future<Unblocked> unblock(String externalId) async {
    assertValidExternalId(externalId);
    return Unblocked.fromJson(_object(await _transport.request(
        'DELETE', '/v1/blocks/${_enc(externalId)}',
        audience: Audience.member)));
  }
}

/// Reporting posts and comments.
final class ReportsApi {
  ReportsApi(this._transport);
  final Transport _transport;

  /// Reports a post. One member can report one post once.
  Future<Reported> reportPost(String postId, String reason) async {
    _required('postId', postId);
    _required('reason', reason);
    return Reported.fromJson(_object(await _transport.request(
        'POST', '/v1/posts/${_enc(postId)}/reports',
        audience: Audience.member,
        body: {'reason': reason},
        repeatable: true)));
  }

  /// Reports a comment.
  Future<Reported> reportComment(String commentId, String reason) async {
    _required('commentId', commentId);
    _required('reason', reason);
    return Reported.fromJson(_object(await _transport.request(
        'POST', '/v1/comments/${_enc(commentId)}/reports',
        audience: Audience.member,
        body: {'reason': reason},
        repeatable: true)));
  }

  /// The reports on the community's content. Secret key only.
  Future<ReportList> list() async =>
      ReportList.fromJson(_object(await _transport.request('GET', '/v1/reports',
          audience: Audience.creator)));
}

/// The moderation archive: posts and comments that reached the report
/// threshold. They are not deleted. Members no longer see them, and they are
/// kept here. Secret key only.
final class ArchiveApi {
  ArchiveApi(this._transport);
  final Transport _transport;

  /// One page of the archive, newest first.
  Future<ArchiveList> list({int? limit, String? before}) async =>
      ArchiveList.fromJson(_object(await _transport.request(
          'GET', '/v1/moderation/archive',
          audience: Audience.creator,
          query: {'limit': limit, 'before': before})));

  /// One archived post or comment, by its archive id.
  Future<Archived> get(String archiveId) async {
    _required('archiveId', archiveId);
    return Archived.fromJson(_object(await _transport.request(
        'GET', '/v1/moderation/archive/${_enc(archiveId)}',
        audience: Audience.creator)));
  }
}

/// Notifications: what others did to what the user wrote.
final class NotificationsApi {
  NotificationsApi(this._transport);
  final Transport _transport;

  /// One page of notifications, newest first.
  Future<NotificationList> list({int? limit, String? before}) async =>
      NotificationList.fromJson(_object(await _transport.request(
          'GET', '/v1/notifications',
          audience: Audience.member,
          query: {'limit': limit, 'before': before})));

  /// The number for the bell.
  Future<int> unreadCount() async => UnreadCount.fromJson(_object(
          await _transport.request('GET', '/v1/notifications/unread-count',
              audience: Audience.member)))
      .unreadCount;

  /// Marks every notification read.
  Future<void> markAllRead() async {
    await _transport.request('POST', '/v1/notifications/read',
        audience: Audience.member, repeatable: true);
  }

  /// Marks one notification read: call it when the user opens the notification.
  Future<NotificationRead> markRead(String notificationId) async {
    _required('notificationId', notificationId);
    return NotificationRead.fromJson(_object(await _transport.request(
        'POST', '/v1/notifications/${_enc(notificationId)}/read',
        audience: Audience.member, repeatable: true)));
  }
}

/// Push notifications: the same notifications, sent to the phone while the
/// app is closed. Get a push token from the phone (Firebase's or Expo's
/// library), then register it for the signed-in user.
final class PushApi {
  PushApi(this._transport);
  final Transport _transport;
  String? _token;

  /// The token this client registered and has not unregistered, or null.
  String? get registeredToken => _token;

  /// Registers the phone's push token for the user. Safe to call on every
  /// start: registering the same token again changes nothing. Signing out
  /// unregisters it.
  ///
  /// [provider] is worked out from the token when left out. [platform] is
  /// optional.
  Future<PushDevice> register(String token,
      {PushProvider? provider, PushPlatform? platform}) async {
    _required('token', token);
    final device = PushDevice.fromJson(
        _object(await _transport.request('PUT', '/v1/push/devices',
            audience: Audience.member,
            repeatable: true,
            body: _given({
              'token': token,
              'provider': provider?.wire,
              'platform': platform?.wire,
            }))));
    _token = token;
    return device;
  }

  /// Forgets a push token, so the phone stops getting this user's
  /// notifications. Without a token it forgets the one this client
  /// registered. Completes with whether a token was removed.
  Future<bool> unregister([String? token]) async {
    final target = token ?? _token;
    if (target == null || target.isEmpty) return false;
    final reply = PushUnregistered.fromJson(_object(await _transport.request(
        'POST', '/v1/push/devices/unregister',
        audience: Audience.member, repeatable: true, body: {'token': target})));
    if (target == _token) _token = null;
    return reply.removed;
  }

  /// The user's push switch, the creator's, and how many phones are
  /// registered.
  Future<PushPreference> preference() async =>
      PushPreference.fromJson(_object(await _transport
          .request('GET', '/v1/push/preferences', audience: Audience.member)));

  /// Turns the user's push notifications on or off. The notification list is
  /// not affected.
  Future<PushPreference> setEnabled(bool enabled) async =>
      PushPreference.fromJson(_object(await _transport.request(
          'PUT', '/v1/push/preferences',
          audience: Audience.member,
          repeatable: true,
          body: {'enabled': enabled})));
}

/// The creator's settings.
final class SettingsApi {
  SettingsApi(this._transport);
  final Transport _transport;

  /// The settings. Any key can read them, so an app can adapt to them.
  Future<Settings> get() async => Settings.fromJson(_object(await _transport
      .request('GET', '/v1/settings', audience: Audience.anyKey)));

  /// Changes settings. Pass only what changes. Secret key only.
  Future<Settings> update({
    int? maxImagesPerPost,
    ImageSize? imageSize,
    ReactionOrder? reactionOrder,
    bool? commentRepliesEnabled,
    FeedMode? feedMode,
    int? feedPageSize,
    int? reportThreshold,
    int? searchPageSize,
    int? bioMaxLength,
    bool? profileViewingEnabled,
    bool? pushEnabled,
  }) async =>
      Settings.fromJson(
          _object(await _transport.request('PATCH', '/v1/settings',
              audience: Audience.creator,
              repeatable: true,
              body: _given({
                'max_images_per_post': maxImagesPerPost,
                'image_size': imageSize?.wire,
                'reaction_order': reactionOrder?.wire,
                'comment_replies_enabled': commentRepliesEnabled,
                'feed_mode': feedMode?.wire,
                'feed_page_size': feedPageSize,
                'report_threshold': reportThreshold,
                'search_page_size': searchPageSize,
                'bio_max_length': bioMaxLength,
                'profile_viewing_enabled': profileViewingEnabled,
                'push_enabled': pushEnabled,
              }))));
}
