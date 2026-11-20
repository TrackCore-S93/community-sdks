// GENERATED from contract/openapi.json by tool/generate.dart. Do not edit.

/// One route of the API, as the contract describes it.
typedef OperationSpec = ({String sdk, String method, String path, String auth});

/// Every route of the API.
const List<OperationSpec> operations = [
  (sdk: 'client.whoAmI', method: 'GET', path: '/v1/me', auth: 'any_key'),
  (
    sdk: 'auth.createSession',
    method: 'POST',
    path: '/v1/auth/session',
    auth: 'any_key'
  ),
  (
    sdk: 'auth.endSession',
    method: 'DELETE',
    path: '/v1/auth/session',
    auth: 'session'
  ),
  (
    sdk: 'client.currentUser',
    method: 'GET',
    path: '/v1/users/me',
    auth: 'member'
  ),
  (
    sdk: 'users.delete',
    method: 'DELETE',
    path: '/v1/users/{external_id}',
    auth: 'creator'
  ),
  (
    sdk: 'community.me',
    method: 'GET',
    path: '/v1/community/me',
    auth: 'member'
  ),
  (
    sdk: 'community.updateProfile',
    method: 'PATCH',
    path: '/v1/community/me',
    auth: 'member'
  ),
  (
    sdk: 'community.usernameAvailable',
    method: 'GET',
    path: '/v1/community/username-available',
    auth: 'member'
  ),
  (
    sdk: 'community.join',
    method: 'POST',
    path: '/v1/community/join',
    auth: 'member'
  ),
  (
    sdk: 'community.summary',
    method: 'GET',
    path: '/v1/community/summary',
    auth: 'member_or_creator'
  ),
  (
    sdk: 'community.member',
    method: 'GET',
    path: '/v1/community/members/{external_id}',
    auth: 'member_or_creator'
  ),
  (
    sdk: 'members.setRole',
    method: 'PATCH',
    path: '/v1/community/members/{external_id}',
    auth: 'creator'
  ),
  (
    sdk: 'members.list',
    method: 'GET',
    path: '/v1/community/members',
    auth: 'creator'
  ),
  (
    sdk: 'topics.list',
    method: 'GET',
    path: '/v1/topics',
    auth: 'member_or_creator'
  ),
  (sdk: 'topics.create', method: 'POST', path: '/v1/topics', auth: 'creator'),
  (
    sdk: 'topics.get',
    method: 'GET',
    path: '/v1/topics/{topic_id}',
    auth: 'member_or_creator'
  ),
  (
    sdk: 'topics.update',
    method: 'PATCH',
    path: '/v1/topics/{topic_id}',
    auth: 'creator'
  ),
  (
    sdk: 'topics.delete',
    method: 'DELETE',
    path: '/v1/topics/{topic_id}',
    auth: 'creator'
  ),
  (
    sdk: 'posts.feed',
    method: 'GET',
    path: '/v1/posts',
    auth: 'member_or_creator'
  ),
  (sdk: 'posts.create', method: 'POST', path: '/v1/posts', auth: 'member'),
  (
    sdk: 'posts.get',
    method: 'GET',
    path: '/v1/posts/{post_id}',
    auth: 'member_or_creator'
  ),
  (
    sdk: 'posts.delete',
    method: 'DELETE',
    path: '/v1/posts/{post_id}',
    auth: 'member_or_creator'
  ),
  (
    sdk: 'posts.pin',
    method: 'PUT',
    path: '/v1/posts/{post_id}/pin',
    auth: 'creator'
  ),
  (
    sdk: 'posts.unpin',
    method: 'DELETE',
    path: '/v1/posts/{post_id}/pin',
    auth: 'creator'
  ),
  (
    sdk: 'posts.search',
    method: 'GET',
    path: '/v1/search/posts',
    auth: 'member_or_creator'
  ),
  (
    sdk: 'reactions.addToPost',
    method: 'PUT',
    path: '/v1/posts/{post_id}/reactions/{emoji}',
    auth: 'member'
  ),
  (
    sdk: 'reactions.removeFromPost',
    method: 'DELETE',
    path: '/v1/posts/{post_id}/reactions/{emoji}',
    auth: 'member'
  ),
  (
    sdk: 'reactions.addToComment',
    method: 'PUT',
    path: '/v1/comments/{comment_id}/reactions/{emoji}',
    auth: 'member'
  ),
  (
    sdk: 'reactions.removeFromComment',
    method: 'DELETE',
    path: '/v1/comments/{comment_id}/reactions/{emoji}',
    auth: 'member'
  ),
  (
    sdk: 'comments.list',
    method: 'GET',
    path: '/v1/posts/{post_id}/comments',
    auth: 'member_or_creator'
  ),
  (
    sdk: 'comments.create',
    method: 'POST',
    path: '/v1/posts/{post_id}/comments',
    auth: 'member'
  ),
  (
    sdk: 'comments.replies',
    method: 'GET',
    path: '/v1/comments/{comment_id}/replies',
    auth: 'member_or_creator'
  ),
  (
    sdk: 'comments.delete',
    method: 'DELETE',
    path: '/v1/comments/{comment_id}',
    auth: 'member_or_creator'
  ),
  (sdk: 'media.start', method: 'POST', path: '/v1/media', auth: 'member'),
  (
    sdk: 'media.complete',
    method: 'POST',
    path: '/v1/media/{media_id}/complete',
    auth: 'member'
  ),
  (
    sdk: 'media.get',
    method: 'GET',
    path: '/v1/media/{media_id}',
    auth: 'member'
  ),
  (sdk: 'coachChat.get', method: 'GET', path: '/v1/coach-chat', auth: 'member'),
  (
    sdk: 'coachChat.messages',
    method: 'GET',
    path: '/v1/coach-chat/messages',
    auth: 'member'
  ),
  (
    sdk: 'coachChat.send',
    method: 'POST',
    path: '/v1/coach-chat/messages',
    auth: 'member'
  ),
  (
    sdk: 'coachChat.edit',
    method: 'PATCH',
    path: '/v1/coach-chat/messages/{message_id}',
    auth: 'member'
  ),
  (
    sdk: 'coachChat.delete',
    method: 'DELETE',
    path: '/v1/coach-chat/messages/{message_id}',
    auth: 'member'
  ),
  (
    sdk: 'coachChat.markRead',
    method: 'POST',
    path: '/v1/coach-chat/read',
    auth: 'member'
  ),
  (
    sdk: 'coachChat.search',
    method: 'GET',
    path: '/v1/coach-chat/search',
    auth: 'member'
  ),
  (
    sdk: 'coachChat.startFile',
    method: 'POST',
    path: '/v1/coach-chat/files',
    auth: 'creator'
  ),
  (
    sdk: 'coachChat.completeFile',
    method: 'POST',
    path: '/v1/coach-chat/files/{file_id}/complete',
    auth: 'creator'
  ),
  (
    sdk: 'coachChat.chats',
    method: 'GET',
    path: '/v1/coach-chat/members',
    auth: 'creator'
  ),
  (
    sdk: 'coachChat.memberMessages',
    method: 'GET',
    path: '/v1/coach-chat/members/{external_id}/messages',
    auth: 'creator'
  ),
  (
    sdk: 'coachChat.sendAsCoach',
    method: 'POST',
    path: '/v1/coach-chat/members/{external_id}/messages',
    auth: 'creator'
  ),
  (
    sdk: 'coachChat.markMemberRead',
    method: 'POST',
    path: '/v1/coach-chat/members/{external_id}/read',
    auth: 'creator'
  ),
  (
    sdk: 'push.register',
    method: 'PUT',
    path: '/v1/push/devices',
    auth: 'member'
  ),
  (
    sdk: 'push.unregister',
    method: 'POST',
    path: '/v1/push/devices/unregister',
    auth: 'member'
  ),
  (
    sdk: 'push.preference',
    method: 'GET',
    path: '/v1/push/preferences',
    auth: 'member'
  ),
  (
    sdk: 'push.setEnabled',
    method: 'PUT',
    path: '/v1/push/preferences',
    auth: 'member'
  ),
  (sdk: 'blocks.list', method: 'GET', path: '/v1/blocks', auth: 'member'),
  (
    sdk: 'blocks.block',
    method: 'PUT',
    path: '/v1/blocks/{external_id}',
    auth: 'member'
  ),
  (
    sdk: 'blocks.unblock',
    method: 'DELETE',
    path: '/v1/blocks/{external_id}',
    auth: 'member'
  ),
  (
    sdk: 'reports.reportPost',
    method: 'POST',
    path: '/v1/posts/{post_id}/reports',
    auth: 'member'
  ),
  (
    sdk: 'reports.reportComment',
    method: 'POST',
    path: '/v1/comments/{comment_id}/reports',
    auth: 'member'
  ),
  (sdk: 'reports.list', method: 'GET', path: '/v1/reports', auth: 'creator'),
  (
    sdk: 'archive.list',
    method: 'GET',
    path: '/v1/moderation/archive',
    auth: 'creator'
  ),
  (
    sdk: 'archive.get',
    method: 'GET',
    path: '/v1/moderation/archive/{archive_id}',
    auth: 'creator'
  ),
  (
    sdk: 'notifications.list',
    method: 'GET',
    path: '/v1/notifications',
    auth: 'member'
  ),
  (
    sdk: 'notifications.unreadCount',
    method: 'GET',
    path: '/v1/notifications/unread-count',
    auth: 'member'
  ),
  (
    sdk: 'notifications.markAllRead',
    method: 'POST',
    path: '/v1/notifications/read',
    auth: 'member'
  ),
  (
    sdk: 'notifications.markRead',
    method: 'POST',
    path: '/v1/notifications/{notification_id}/read',
    auth: 'member'
  ),
  (sdk: 'settings.get', method: 'GET', path: '/v1/settings', auth: 'any_key'),
  (
    sdk: 'settings.update',
    method: 'PATCH',
    path: '/v1/settings',
    auth: 'creator'
  ),
  (
    sdk: 'live.connect',
    method: 'GET',
    path: '/v1/live',
    auth: 'member_or_creator'
  ),
];

/// The version of the API contract this SDK was generated from.
const String contractVersion = '0.1.0';
