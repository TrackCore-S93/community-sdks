// GENERATED from contract/openapi.yaml by scripts/generate.mjs. Do not edit.

/** One route of the API, as the contract describes it. */
export interface OperationSpec {
  /** The SDK call that wraps it, as namespace.method. */
  sdk: string;
  operationId: string;
  method: string;
  path: string;
  /** Who may call it. */
  auth: "any_key" | "member" | "creator" | "member_or_creator" | "session";
}

export const OPERATIONS: readonly OperationSpec[] = [
  { sdk: "client.whoAmI", operationId: "whoAmI", method: "GET", path: "/v1/me", auth: "any_key" },
  { sdk: "auth.createSession", operationId: "createSession", method: "POST", path: "/v1/auth/session", auth: "any_key" },
  { sdk: "auth.endSession", operationId: "endSession", method: "DELETE", path: "/v1/auth/session", auth: "session" },
  { sdk: "client.currentUser", operationId: "currentUser", method: "GET", path: "/v1/users/me", auth: "member" },
  { sdk: "users.delete", operationId: "deleteUser", method: "DELETE", path: "/v1/users/{external_id}", auth: "creator" },
  { sdk: "community.me", operationId: "getMyProfile", method: "GET", path: "/v1/community/me", auth: "member" },
  { sdk: "community.updateProfile", operationId: "updateMyProfile", method: "PATCH", path: "/v1/community/me", auth: "member" },
  { sdk: "community.usernameAvailable", operationId: "checkUsername", method: "GET", path: "/v1/community/username-available", auth: "member" },
  { sdk: "community.join", operationId: "joinCommunity", method: "POST", path: "/v1/community/join", auth: "member" },
  { sdk: "community.summary", operationId: "getCommunitySummary", method: "GET", path: "/v1/community/summary", auth: "member_or_creator" },
  { sdk: "community.member", operationId: "getMember", method: "GET", path: "/v1/community/members/{external_id}", auth: "member_or_creator" },
  { sdk: "members.setRole", operationId: "setMemberRole", method: "PATCH", path: "/v1/community/members/{external_id}", auth: "creator" },
  { sdk: "members.list", operationId: "listMembers", method: "GET", path: "/v1/community/members", auth: "creator" },
  { sdk: "topics.list", operationId: "listTopics", method: "GET", path: "/v1/topics", auth: "member_or_creator" },
  { sdk: "topics.create", operationId: "createTopic", method: "POST", path: "/v1/topics", auth: "creator" },
  { sdk: "topics.get", operationId: "getTopic", method: "GET", path: "/v1/topics/{topic_id}", auth: "member_or_creator" },
  { sdk: "topics.update", operationId: "updateTopic", method: "PATCH", path: "/v1/topics/{topic_id}", auth: "creator" },
  { sdk: "topics.delete", operationId: "deleteTopic", method: "DELETE", path: "/v1/topics/{topic_id}", auth: "creator" },
  { sdk: "posts.feed", operationId: "listPosts", method: "GET", path: "/v1/posts", auth: "member_or_creator" },
  { sdk: "posts.create", operationId: "createPost", method: "POST", path: "/v1/posts", auth: "member" },
  { sdk: "posts.get", operationId: "getPost", method: "GET", path: "/v1/posts/{post_id}", auth: "member_or_creator" },
  { sdk: "posts.delete", operationId: "deletePost", method: "DELETE", path: "/v1/posts/{post_id}", auth: "member_or_creator" },
  { sdk: "posts.pin", operationId: "pinPost", method: "PUT", path: "/v1/posts/{post_id}/pin", auth: "creator" },
  { sdk: "posts.unpin", operationId: "unpinPost", method: "DELETE", path: "/v1/posts/{post_id}/pin", auth: "creator" },
  { sdk: "posts.search", operationId: "searchPosts", method: "GET", path: "/v1/search/posts", auth: "member_or_creator" },
  { sdk: "reactions.addToPost", operationId: "addPostReaction", method: "PUT", path: "/v1/posts/{post_id}/reactions/{emoji}", auth: "member" },
  { sdk: "reactions.removeFromPost", operationId: "removePostReaction", method: "DELETE", path: "/v1/posts/{post_id}/reactions/{emoji}", auth: "member" },
  { sdk: "reactions.addToComment", operationId: "addCommentReaction", method: "PUT", path: "/v1/comments/{comment_id}/reactions/{emoji}", auth: "member" },
  { sdk: "reactions.removeFromComment", operationId: "removeCommentReaction", method: "DELETE", path: "/v1/comments/{comment_id}/reactions/{emoji}", auth: "member" },
  { sdk: "comments.list", operationId: "listComments", method: "GET", path: "/v1/posts/{post_id}/comments", auth: "member_or_creator" },
  { sdk: "comments.create", operationId: "createComment", method: "POST", path: "/v1/posts/{post_id}/comments", auth: "member" },
  { sdk: "comments.replies", operationId: "listReplies", method: "GET", path: "/v1/comments/{comment_id}/replies", auth: "member_or_creator" },
  { sdk: "comments.delete", operationId: "deleteComment", method: "DELETE", path: "/v1/comments/{comment_id}", auth: "member_or_creator" },
  { sdk: "media.start", operationId: "startUpload", method: "POST", path: "/v1/media", auth: "member" },
  { sdk: "media.complete", operationId: "completeUpload", method: "POST", path: "/v1/media/{media_id}/complete", auth: "member" },
  { sdk: "media.get", operationId: "getMedia", method: "GET", path: "/v1/media/{media_id}", auth: "member" },
  { sdk: "coachChat.get", operationId: "getCoachChat", method: "GET", path: "/v1/coach-chat", auth: "member" },
  { sdk: "coachChat.messages", operationId: "listCoachMessages", method: "GET", path: "/v1/coach-chat/messages", auth: "member" },
  { sdk: "coachChat.send", operationId: "sendCoachMessage", method: "POST", path: "/v1/coach-chat/messages", auth: "member" },
  { sdk: "coachChat.edit", operationId: "editCoachMessage", method: "PATCH", path: "/v1/coach-chat/messages/{message_id}", auth: "member" },
  { sdk: "coachChat.delete", operationId: "deleteCoachMessage", method: "DELETE", path: "/v1/coach-chat/messages/{message_id}", auth: "member" },
  { sdk: "coachChat.deleteImage", operationId: "deleteCoachMessageImage", method: "DELETE", path: "/v1/coach-chat/messages/{message_id}/images/{image_id}", auth: "member" },
  { sdk: "coachChat.markRead", operationId: "markCoachChatRead", method: "POST", path: "/v1/coach-chat/read", auth: "member" },
  { sdk: "coachChat.search", operationId: "searchCoachChat", method: "GET", path: "/v1/coach-chat/search", auth: "member" },
  { sdk: "coachChat.startFile", operationId: "beginCoachFile", method: "POST", path: "/v1/coach-chat/files", auth: "member" },
  { sdk: "coachChat.completeFile", operationId: "completeCoachFile", method: "POST", path: "/v1/coach-chat/files/{file_id}/complete", auth: "member" },
  { sdk: "coachChat.chats", operationId: "listCoachChats", method: "GET", path: "/v1/coach-chat/members", auth: "creator" },
  { sdk: "coachChat.memberMessages", operationId: "listMemberMessagesAsCoach", method: "GET", path: "/v1/coach-chat/members/{external_id}/messages", auth: "creator" },
  { sdk: "coachChat.sendAsCoach", operationId: "sendAsCoach", method: "POST", path: "/v1/coach-chat/members/{external_id}/messages", auth: "creator" },
  { sdk: "coachChat.markMemberRead", operationId: "markMemberChatRead", method: "POST", path: "/v1/coach-chat/members/{external_id}/read", auth: "creator" },
  { sdk: "push.register", operationId: "registerPushDevice", method: "PUT", path: "/v1/push/devices", auth: "member" },
  { sdk: "push.unregister", operationId: "unregisterPushDevice", method: "POST", path: "/v1/push/devices/unregister", auth: "member" },
  { sdk: "push.preference", operationId: "getPushPreference", method: "GET", path: "/v1/push/preferences", auth: "member" },
  { sdk: "push.setEnabled", operationId: "setPushPreference", method: "PUT", path: "/v1/push/preferences", auth: "member" },
  { sdk: "blocks.list", operationId: "listBlocks", method: "GET", path: "/v1/blocks", auth: "member" },
  { sdk: "blocks.block", operationId: "blockMember", method: "PUT", path: "/v1/blocks/{external_id}", auth: "member" },
  { sdk: "blocks.unblock", operationId: "unblockMember", method: "DELETE", path: "/v1/blocks/{external_id}", auth: "member" },
  { sdk: "reports.reportPost", operationId: "reportPost", method: "POST", path: "/v1/posts/{post_id}/reports", auth: "member" },
  { sdk: "reports.reportComment", operationId: "reportComment", method: "POST", path: "/v1/comments/{comment_id}/reports", auth: "member" },
  { sdk: "reports.list", operationId: "listReports", method: "GET", path: "/v1/reports", auth: "creator" },
  { sdk: "archive.list", operationId: "listArchive", method: "GET", path: "/v1/moderation/archive", auth: "creator" },
  { sdk: "archive.get", operationId: "getArchived", method: "GET", path: "/v1/moderation/archive/{archive_id}", auth: "creator" },
  { sdk: "notifications.list", operationId: "listNotifications", method: "GET", path: "/v1/notifications", auth: "member" },
  { sdk: "notifications.unreadCount", operationId: "countUnreadNotifications", method: "GET", path: "/v1/notifications/unread-count", auth: "member" },
  { sdk: "notifications.markAllRead", operationId: "markAllNotificationsRead", method: "POST", path: "/v1/notifications/read", auth: "member" },
  { sdk: "notifications.markRead", operationId: "markNotificationRead", method: "POST", path: "/v1/notifications/{notification_id}/read", auth: "member" },
  { sdk: "settings.get", operationId: "getSettings", method: "GET", path: "/v1/settings", auth: "any_key" },
  { sdk: "settings.update", operationId: "updateSettings", method: "PATCH", path: "/v1/settings", auth: "creator" },
  { sdk: "live.connect", operationId: "connectLive", method: "GET", path: "/v1/live", auth: "member_or_creator" },
];

/** The version of the API contract this SDK was generated from. */
export const CONTRACT_VERSION = "0.1.0";
