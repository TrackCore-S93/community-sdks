// GENERATED from contract/openapi.yaml by scripts/generate.mjs. Do not edit.

/** A session token for one end user. The token appears in this reply and nowhere else. */
export interface Session {
  /** The session token. Send it in the header named by `header`. */
  token: string;
  /** Always `opaque`: the token carries nothing to decode. */
  token_type: string;
  /** The request header the token is sent in. */
  header: string;
  /** The user the session is for. */
  external_id: string;
  /** `test` or `live`, the environment of the key that minted it. */
  environment: string;
  /** When the session was minted. */
  issued_at: string;
  /** When it stops working. */
  expires_at: string;
  /** Its lifetime in seconds. */
  ttl_seconds: number;
}

/** Who the session is for and how long it lasts. */
export interface SessionRequest {
  /** Your own id for the end user, 1 to 255 printable characters. */
  external_id: string;
  /** Lifetime in seconds, 60 to 86400. Left out, one hour. */
  ttl_seconds?: number;
}

/** Which customer and key the service sees. */
export interface WhoAmI {
  /** The customer's public id. */
  customer_id: string;
  /** The key's public id (not the key itself). */
  key_id: string;
  /** `secret` or `publishable`. */
  key_kind: string;
  /** `test` or `live`. */
  environment: string;
}

/** The end user a call acts for. */
export interface EndUser {
  /** Your own id for the user. */
  external_id: string;
  /** True when the user was named by a session token, false when by `X-External-Id`. */
  via_session: boolean;
}

/** The result of erasing an end user. */
export interface ErasedUser {
  /** The user that was named. */
  external_id: string;
  /** False when there was nobody by that id, which is not an error. */
  deleted: boolean;
}

/** The result of deleting a topic, post or comment. */
export interface Deleted {
  /** The id that was named. */
  id: string;
  /** False when it was already gone, which is not an error. */
  deleted: boolean;
}

/** One member of the community. */
export interface Profile {
  /** Your own id for the user. */
  external_id: string;
  /** The member's name, unique in the community ignoring case. */
  username: string;
  /** A short-lived link to the profile photo, or an empty string. */
  avatar_url: string;
  /** A short-lived link to the profile background, or an empty string. */
  cover_url: string;
  /** The member's bio, or an empty string. */
  bio: string;
  /** The label shown beside the member's name. */
  role: Role;
  /** Goes up by one each time the profile changes. */
  version: number;
  /** When the user joined the community. */
  joined_at: string;
  /** When the profile last changed. */
  updated_at: string;
  /** How many posts the member has in the community now. Deleted and removed posts are not counted. */
  posts_count: number;
  /** How many comments and replies the member has in the community now. Deleted and removed ones are not counted. */
  comments_count: number;
}

/** The community at a glance. */
export interface CommunitySummary {
  /** How many users have joined the community. */
  members_count: number;
  /** Links to the profile photos of up to four members who have one, picked at random on every call. Empty when nobody has a photo. The links expire, like every image link. */
  avatar_urls: string[];
}

/** A member's profile as another reader sees it. */
export interface Member {
  /** Your own id for the user. */
  external_id: string;
  /** The member's name, unique in the community ignoring case. */
  username: string;
  /** A short-lived link to the profile photo, or an empty string. */
  avatar_url: string;
  /** A short-lived link to the profile background, or an empty string. */
  cover_url: string;
  /** The member's bio, or an empty string. */
  bio: string;
  /** The label shown beside the member's name. */
  role: Role;
  /** Goes up by one each time the profile changes. */
  version: number;
  /** When the user joined the community. */
  joined_at: string;
  /** When the profile last changed. */
  updated_at: string;
  /** How many posts the member has in the community now. Deleted and removed posts are not counted. */
  posts_count: number;
  /** How many comments and replies the member has in the community now. Deleted and removed ones are not counted. */
  comments_count: number;
  /** True when the profile is the reader's own, the only one they can edit. */
  is_me: boolean;
}

/** Whether the user has joined, and their profile if so. */
export interface Membership {
  /** False until the user has chosen a username. */
  joined: boolean;
  /** Null until the user has joined. */
  profile: Profile | null;
}

/** Whether a username is free. A hint for the form; joining decides. */
export interface UsernameAvailability {
  /** The name that was asked about. */
  username: string;
  /** True when the user could take this name now. */
  available: boolean;
  /** Present when not available: `taken` or `invalid`. */
  reason?: string;
  /** Present when not available: a sentence to show under the field. */
  message?: string;
}

/** The username to join under. */
export interface JoinRequest {
  /** 3 to 30 characters: letters, numbers, underscores and single dots. */
  username: string;
}

/** A partial edit: a field left out is not changed. */
export interface EditProfileRequest {
  /** A new username, under the same rules as joining. */
  username?: string | null;
  /** A new bio, at most the creator's `bio_max_length`. An empty string clears it. */
  bio?: string | null;
  /** An uploaded image to use as the photo. An empty string removes the photo. */
  avatar_media_id?: string | null;
  /** An uploaded image to use as the background. An empty string removes it. */
  cover_media_id?: string | null;
}

/** One page of the member list, in username order. */
export interface MemberList {
  /** The members on this page. */
  members: Profile[];
  /** Send as `after` for the next page. Null at the end. */
  next_cursor: string | null;
  /** True when there is another page. */
  has_more: boolean;
  /** How many members match the search and role, across all pages. */
  total: number;
}

/** The role to give a member. */
export interface SetRoleRequest {
  /** `user`, `coach` or `creator`. */
  role: Role;
}

/** One section of the community that posts are written in. */
export interface Topic {
  /** The topic's id. */
  id: string;
  /** Unique in the community ignoring case. */
  name: string;
  /** Shown on the topic's sheet. */
  description: string;
  /** The image on the topic's card. */
  image_url: string;
  /** The image on the topic's sheet. */
  cover_url: string;
  /** How many posts the topic has. */
  posts_count: number;
  /** Position in the list, lowest first. */
  sort_order: number;
  /** False hides the topic and its posts from members. */
  is_live: boolean;
  /** True puts the topic in the trending list. */
  is_trending: boolean;
  /** When the topic was created. */
  created_at: string;
  /** When it last changed. */
  updated_at: string;
}

/** The community's topics. */
export interface TopicList {
  /** In `sort_order`, then by name. */
  topics: Topic[];
}

/** A new topic. */
export interface CreateTopicRequest {
  /** Unique in the community ignoring case. */
  name: string;
  /** Shown on the topic's sheet. */
  description?: string;
  /** The image on the topic's card. */
  image_url?: string;
  /** The image on the topic's sheet. */
  cover_url?: string;
  /** Position in the list, lowest first. */
  sort_order?: number;
  /** Left out, the topic is live. */
  is_live?: boolean | null;
  /** True puts the topic in the trending list. */
  is_trending?: boolean;
}

/** A partial edit: a field left out is not changed. */
export interface UpdateTopicRequest {
  /** A new name. */
  name?: string | null;
  /** A new description. */
  description?: string | null;
  /** A new card image. */
  image_url?: string | null;
  /** A new sheet image. */
  cover_url?: string | null;
  /** A new position. */
  sort_order?: number | null;
  /** False hides the topic and its posts. */
  is_live?: boolean | null;
  /** True puts it in the trending list. */
  is_trending?: boolean | null;
}

/** Who wrote a post or comment. */
export interface Author {
  /** Your own id for the user. */
  external_id: string;
  /** The name the member chose in the community. */
  username: string;
  /** A short-lived link to their photo, or an empty string. */
  avatar_url: string;
  /** The label shown beside their name. */
  role: Role;
}

/** One picture on a post or comment. Every image is stored in two sizes: a large one for a post opened on its own screen, and a small one for the feed. */
export interface Image {
  /** The image's id. */
  id: string;
  /** A short-lived link to the large size: longest side at most 1024 pixels. */
  url: string;
  /** Width of the large size, in pixels. */
  width: number;
  /** Height of the large size, in pixels. */
  height: number;
  /** A short-lived link to the small size: longest side at most 512 pixels. For an image uploaded before two sizes were stored, or one already 512 pixels or less, this is the same picture as `url`. */
  small_url: string;
  /** Width of the small size, in pixels. */
  small_width: number;
  /** Height of the small size, in pixels. */
  small_height: number;
}

/** One emoji on a post or comment. */
export interface Reaction {
  /** The emoji. */
  emoji: string;
  /** How many members gave it. */
  count: number;
  /** True when the user the call acts for gave it. */
  reacted_by_me: boolean;
}

/** One post in the feed. */
export interface Post {
  /** The post's id. */
  id: string;
  /** The topic it was written in. */
  topic_id: string;
  /** Who wrote it. */
  author: Author;
  /** The text. May be empty when the post has images. */
  body: string;
  /** The post's pictures, in the author's order. */
  images: Image[];
  /** The emoji on the post, in the creator's chosen order. */
  reactions: Reaction[];
  /** How many comments and replies the post has. */
  comments_count: number;
  /** True when the side the call acts for wrote it: the member's own messages for the member, the coach's side's for a coach. */
  is_mine: boolean;
  /** True when the creator has pinned it. */
  is_pinned: boolean;
  /** When it was pinned, or null. */
  pinned_at: string | null;
  /** When it was posted. */
  created_at: string;
}

/** One page of the feed, newest first. */
export interface Feed {
  /** Pinned posts, most recently pinned first. First page only; never repeated in `posts`. */
  pinned: Post[];
  /** The posts on this page. */
  posts: Post[];
  /** Send as `before` for the older posts. Null at the end. */
  next_cursor: string | null;
  /** Send as `after` for the page before. Pages mode only; null otherwise. */
  prev_cursor: string | null;
  /** Send as `after` later for posts created since this read. */
  newest_cursor: string | null;
  /** True when there are more posts in the direction that was read. */
  has_more: boolean;
  /** The creator's feed mode. */
  mode: FeedMode;
  /** How many posts this read was limited to: the `limit` sent, or 20. */
  page_size: number;
}

/** A new post: text, images, or both. */
export interface CreatePostRequest {
  /** The topic to post in. */
  topic_id: string;
  /** The text. May be left out when the post has images. */
  body?: string;
  /** Uploaded images, in display order, at most the creator's `max_images_per_post`. */
  media_ids?: string[];
}

/** One page of search results, newest first. */
export interface SearchResults {
  /** The matching posts. */
  posts: Post[];
  /** Send as `before` for the next page. Null at the end. */
  next_cursor: string | null;
  /** True when there is another page. */
  has_more: boolean;
  /** The creator's search page size. */
  page_size: number;
}

/** A post's reactions after a change. */
export interface PostReactions {
  /** The post. */
  post_id: string;
  /** The full list, in the creator's chosen order. */
  reactions: Reaction[];
}

/** One comment or reply. */
export interface Comment {
  /** The comment's id. */
  id: string;
  /** The post it is on. */
  post_id: string;
  /** The comment this replies to, or null for a comment on the post. */
  parent_id: string | null;
  /** Who wrote it. */
  author: Author;
  /** The text. May be empty when the comment has images. */
  body: string;
  /** The comment's pictures. */
  images: Image[];
  /** The emoji on the comment. */
  reactions: Reaction[];
  /** How many replies it has. */
  replies_count: number;
  /** True when the side the call acts for wrote it: the member's own messages for the member, the coach's side's for a coach. */
  is_mine: boolean;
  /** When it was written. */
  created_at: string;
}

/** One page of comments or replies, oldest first. */
export interface CommentPage {
  /** The comments on this page. */
  comments: Comment[];
  /** Send as `after` for the next page. Null at the end. */
  next_cursor: string | null;
  /** True when there is another page. */
  has_more: boolean;
}

/** A new comment or reply: text, images, or both. */
export interface CreateCommentRequest {
  /** The text. May be left out when the comment has images. */
  body?: string;
  /** Uploaded images, in display order. */
  media_ids?: string[];
  /** A comment on the same post to reply to, when the creator allows replies. */
  parent_id?: string;
}

/** A comment's reactions after a change. */
export interface CommentReactions {
  /** The comment. */
  comment_id: string;
  /** The full list. */
  reactions: Reaction[];
}

/** A started upload: where to send the file. */
export interface Upload {
  /** The image's id, used to finish the upload and to attach the image. */
  id: string;
  /** `pending` until the upload is finished. */
  status: MediaStatus;
  /** Where and how to send the file. */
  upload: UploadTarget;
  /** The largest file accepted, in bytes. */
  max_bytes: number;
}

/** Where and how to send the file. */
export interface UploadTarget {
  /** The HTTP method to send the file with. */
  method: string;
  /** The link to send the file to. Send the file's bytes as the body. */
  url: string;
  /** When the link stops working. */
  expires_at: string;
}

/** One uploaded image. */
export interface Media {
  /** The image's id. */
  id: string;
  /** `pending`, `ready` or `failed`. */
  status: MediaStatus;
  /** A short-lived link to the large size (longest side at most 1024 pixels), once ready. */
  url: string | null;
  /** Width of the large size in pixels, once ready. */
  width: number | null;
  /** Height of the large size in pixels, once ready. */
  height: number | null;
  /** Size of the stored large file, once ready. */
  bytes: number | null;
  /** A short-lived link to the small size (longest side at most 512 pixels), once ready. */
  small_url: string | null;
  /** Width of the small size in pixels, once ready. */
  small_width: number | null;
  /** Height of the small size in pixels, once ready. */
  small_height: number | null;
  /** True once the image is on a post, a comment or a profile. */
  attached: boolean;
}

/** A member the user has blocked. */
export interface BlockedMember {
  /** Your own id for the user. */
  external_id: string;
  /** The name the member chose in the community. */
  username: string;
  /** A short-lived link to their photo, or an empty string. */
  avatar_url: string;
  /** When the block was made. */
  blocked_at: string;
}

/** The members the user has blocked. */
export interface BlockList {
  /** Most recently blocked first. */
  blocked: BlockedMember[];
}

/** The result of unblocking a member. */
export interface Unblocked {
  /** The member that was named. */
  external_id: string;
  /** False when there was no block, which is not an error. */
  unblocked: boolean;
}

/** Why the member is reporting. */
export interface ReportRequest {
  /** The reason, as the app worded it. */
  reason: string;
}

/** The result of a report. */
export interface Reported {
  /** True: the report is on record. */
  reported: boolean;
  /** True when this member had reported it before. */
  already_reported: boolean;
  /** True when this report reached the creator's threshold and the item was removed from the community. */
  removed: boolean;
}

/** One report on a post or comment. */
export interface Report {
  /** The report's id. */
  id: string;
  /** `post` or `comment`. */
  kind: string;
  /** The post or comment that was reported. */
  target_id: string;
  /** The start of its text. */
  excerpt: string;
  /** Who wrote it. */
  author: ReportParty;
  /** Who reported it. */
  reporter: ReportParty;
  /** The reason given. */
  reason: string;
  /** How many different members have reported the item. */
  reports: number;
  /** When the report was made. */
  created_at: string;
}

/** A member named in a report. */
export interface ReportParty {
  /** Your own id for the user. */
  external_id: string;
  /** The name the member chose in the community. */
  username: string;
}

/** The reports on the community's content. */
export interface ReportList {
  /** Newest first. */
  reports: Report[];
  /** The number of reports at which an item is removed from the community. */
  report_threshold: number;
}

/** A post or comment that was removed from the community by reports and kept. */
export interface Archived {
  /** The archived item's id. */
  id: string;
  /** `post` or `comment`. */
  kind: string;
  /** The post or comment that was archived. */
  target_id: string;
  /** The post itself, or the post the comment is under. */
  post_id: string;
  /** Set when the comment is a reply: the comment it sits under. */
  parent_comment_id: string | null;
  /** The topic it was written in. */
  topic_id: string;
  /** Its whole text. */
  body: string;
  /** Its pictures. */
  images: Image[];
  /** Who wrote it. */
  author: ReportParty;
  /** Why it was archived. `reports`: it reached the report threshold. */
  reason: string;
  /** How many different members had reported it when it was archived. */
  reports: number;
  /** The report threshold at that moment. */
  threshold: number;
  /** The members who reported it, oldest first. A reporter who has since been erased is not listed. */
  reported_by: ArchivedReporter[];
  /** When it was written. */
  created_at: string;
  /** When it was archived. */
  archived_at: string;
}

/** A member who reported an archived item. */
export interface ArchivedReporter {
  /** Your own id for the user. */
  external_id: string;
  /** The name the member chose in the community. */
  username: string;
  /** The reason they gave. */
  reason: string;
  /** When they reported it. */
  created_at: string;
}

/** One page of the moderation archive. */
export interface ArchiveList {
  /** Newest first. */
  archived: Archived[];
  /** Pass as `before` for the next page. Null at the end. */
  next_cursor: string | null;
}

/** One member being told what another did to what they wrote, or that their coach wrote to them. */
export interface Notification {
  /** The notification's id. */
  id: string;
  /** What happened. */
  kind: NotificationKind;
  /** Who did it. */
  actor: NotificationActor;
  /** The post concerned: open this. Empty for `coach_message`, which concerns no post. */
  post_id: string;
  /** The comment reacted to, or the new comment. Null for a reaction on a post. */
  comment_id: string | null;
  /** Set when `comment_id` is a reply: the comment it sits under. */
  parent_comment_id: string | null;
  /** The emoji, for a reaction. Null otherwise. */
  emoji: string | null;
  /** The start of the post's text. Empty for `coach_message`. */
  post_excerpt: string;
  /** The start of the comment's text, when there is a comment. */
  comment_excerpt: string | null;
  /** For `coach_message`: the newest message from the coach. Open the coaching chat. Null for every other kind. */
  message_id: string | null;
  /** For `coach_message`: the start of the message's text, empty when it carries only pictures or files. Null for every other kind. */
  message_excerpt: string | null;
  /** True until the member opens it or marks all read. */
  unread: boolean;
  /** When it happened. */
  created_at: string;
}

/** The member who acted. */
export interface NotificationActor {
  /** Your own id for the user. */
  external_id: string;
  /** The name the member chose in the community. */
  username: string;
  /** A short-lived link to their photo, or an empty string. */
  avatar_url: string;
}

/** One page of notifications, newest first. */
export interface NotificationList {
  /** The notifications on this page. */
  notifications: Notification[];
  /** Send as `before` for the next page. Null at the end. */
  next_cursor: string | null;
  /** How many of all the member's notifications are unread. */
  unread_count: number;
}

/** The number for the bell. */
export interface UnreadCount {
  /** How many notifications are unread. */
  unread_count: number;
}

/** The result of opening one notification. */
export interface NotificationRead {
  /** The notification. */
  id: string;
  /** Always false. */
  unread: boolean;
  /** How many are still unread. */
  unread_count: number;
}

/** What the creator has chosen for the community. */
export interface Settings {
  /** Images one post may carry, 0 to 10. 0 turns images off. */
  max_images_per_post: number;
  /** The order reaction chips are shown in. */
  reaction_order: ReactionOrder;
  /** Members may reply to comments. */
  comment_replies_enabled: boolean;
  /** How the app presents the feed. */
  feed_mode: FeedMode;
  /** Reports that remove a post or comment from the community, 1 or more. */
  report_threshold: number;
  /** Search results per page, 1 to 40. */
  search_page_size: number;
  /** The most characters a bio may have, 1 to 5000. */
  bio_max_length: number;
  /** Members may open each other's profiles. */
  profile_viewing_enabled: boolean;
  /** Notifications are also sent to members' phones. */
  push_enabled: boolean;
  /** The largest image upload, in bytes. Fixed, not a creator setting. */
  max_image_upload_bytes: number;
  /** False when this deployment has no image storage. */
  image_uploads_enabled: boolean;
  /** Present only in the reply to a change of `report_threshold`. */
  removed_by_threshold?: RemovedByThreshold;
}

/** What a new report threshold removed at once. */
export interface RemovedByThreshold {
  /** Posts deleted. */
  posts: number;
  /** Comments deleted. */
  comments: number;
}

/** A partial edit: a field left out is not changed. */
export interface UpdateSettingsRequest {
  /** 0 to 10. */
  max_images_per_post?: number | null;
  /** `most_used` or `first_added`. */
  reaction_order?: ReactionOrder | null;
  /** Whether members may reply to comments. */
  comment_replies_enabled?: boolean | null;
  /** `infinite_scroll` or `pages`. */
  feed_mode?: FeedMode | null;
  /** 1 or more. Lowering it removes at once whatever already has that many reports. */
  report_threshold?: number | null;
  /** 1 to 40. */
  search_page_size?: number | null;
  /** 1 to 5000. */
  bio_max_length?: number | null;
  /** Whether members may open each other's profiles. */
  profile_viewing_enabled?: boolean | null;
  /** Whether notifications are also sent to members' phones. */
  push_enabled?: boolean | null;
}

/** A member's coaching chat at a glance. */
export interface CoachChat {
  /** How many messages from the other side have not been seen: the coach's, for the member; the member's, when the coach's side asks. */
  unread_count: number;
  /** When the last message was sent, or null while the chat is empty. */
  last_message_at: string | null;
}

/** One page of the coach's list of chats, newest activity first. */
export interface CoachChatList {
  /** The chats on this page. */
  chats: CoachChatRow[];
  /** Send as `before` for the next page. Null at the end. */
  next_cursor: string | null;
  /** True when there are more chats after this page. */
  has_more: boolean;
}

/** One member's chat in the coach's list. */
export interface CoachChatRow {
  /** Whose chat it is. The username is empty for someone who has not joined the community. */
  member: Author;
  /** How many of the member's messages the coach's side has not seen. */
  unread_count: number;
  /** When the newest message was sent, by either side. */
  last_message_at: string;
  /** The newest message, for the preview line. */
  last_message: CoachLastMessage;
}

/** The preview of a chat's newest message. */
export interface CoachLastMessage {
  /** The message's id. */
  id: string;
  /** Its text. May be empty when it has images or files. */
  body: string;
  /** True when the coach's side wrote it. */
  from_coach: boolean;
  /** How many pictures it has. */
  images_count: number;
  /** How many voice notes and documents it has. */
  files_count: number;
}

/** One message in a coaching chat. */
export interface CoachMessage {
  /** The message's id. */
  id: string;
  /** Who wrote it. Null once that person's account has been erased; the message stays. The username is empty for someone who has not joined the community. */
  author: Author | null;
  /** Which side wrote it: true for the coach's side, false for the member. */
  from_coach: boolean;
  /** The text. May be empty when the message has images or files. */
  body: string;
  /** The message's pictures. */
  images: Image[];
  /** The voice notes and documents on it. Only the coach's side sends them; a member's message has none. */
  files: CoachFile[];
  /** True when the side the call acts for wrote it: the member's own messages for the member, the coach's side's for a coach. */
  is_mine: boolean;
  /** True when the other side of the chat has seen it. On the member's own message, the coach has read it; on the coach's, the member has. */
  is_read: boolean;
  /** When the text was last changed, or null if it never was. */
  edited_at: string | null;
  /** When it was sent. */
  created_at: string;
}

/** One page of a coaching chat, oldest first. */
export interface CoachMessagePage {
  /** The messages on this page. */
  messages: CoachMessage[];
  /** Send as `before` for the messages above these. Null when the page is empty. */
  older_cursor: string | null;
  /** Send as `after` for the messages below these, including ones that arrive later. Null when the page is empty. */
  newer_cursor: string | null;
  /** True when there are messages before this page. */
  has_older: boolean;
  /** True when there are messages after this page. */
  has_newer: boolean;
}

/** A voice note or a document on a coaching-chat message. */
export interface CoachFile {
  /** The file's id. */
  id: string;
  /** `voice` is a voice note, to play. `file` is a document, to open or save. */
  kind: "voice" | "file";
  /** What the sender called the file. */
  name: string;
  /** The file's type. */
  content_type: string;
  /** The file's size in bytes. Null until the upload is finished. */
  bytes: number | null;
  /** A voice note's length in milliseconds, when the sender gave it. Null otherwise. */
  duration_ms: number | null;
  /** A short-lived link to the file. Null until the upload is finished. */
  url: string | null;
}

/** A started file upload: where to send the bytes. */
export interface CoachFileUpload {
  /** The file's id, used to finish the upload and to put the file on a message. */
  id: string;
  /** What was asked for. */
  kind: "voice" | "file";
  /** The file's name. */
  name: string;
  /** Where and how to send the file. */
  upload: UploadTarget;
  /** The largest file accepted, in bytes. */
  max_bytes: number;
}

/** A voice note or a document about to be uploaded. */
export interface BeginCoachFileRequest {
  /** `voice` for a voice note, `file` for a document. */
  kind: "voice" | "file";
  /** The file's name, shown to the member. */
  file_name: string;
  /** The file's type. Any audio type for a voice note. For a document: PDF, Word, Excel, PowerPoint, RTF, text or CSV. */
  content_type: string;
  /** A voice note's length in milliseconds. Optional. */
  duration_ms?: number;
}

/** A message from the coach's side: text, images, files, or any mix. */
export interface SendAsCoachRequest {
  /** The text. May be left out when the message has images or files. */
  body?: string;
  /** Images this coach uploaded, in display order. */
  media_ids?: string[];
  /** Voice notes and documents this coach uploaded, in order. At most 10. */
  file_ids?: string[];
}

/** A new chat message: text, images, or both. */
export interface SendCoachMessageRequest {
  /** The text. May be left out when the message has images. */
  body?: string;
  /** Uploaded images, in display order. */
  media_ids?: string[];
}

/** The new text of a chat message. */
export interface EditCoachMessageRequest {
  /** The text. May be empty only when the message has images. */
  body?: string;
}

/** One page of chat search results, newest first. */
export interface CoachSearchResults {
  /** The matching messages. */
  messages: CoachMessage[];
  /** Send as `before` for the next page. Null at the end. */
  next_cursor: string | null;
  /** True when there is another page. */
  has_more: boolean;
}

/** A phone's push token. */
export interface RegisterPushDeviceRequest {
  /** The push token the phone gave the app: an Expo push token or a Firebase Cloud Messaging token. */
  token: string;
  /** `expo` or `fcm`. Left out, it is worked out from the token. */
  provider?: PushProvider;
  /** `ios`, `android` or `web`. Optional. */
  platform?: PushPlatform;
}

/** A registered phone. */
export interface PushDevice {
  /** The service the token belongs to. */
  provider: PushProvider;
  /** What the app said it runs on; null when it did not say. */
  platform: PushPlatform | null;
  /** Always true. */
  registered: boolean;
}

/** The push token to forget. */
export interface UnregisterPushDeviceRequest {
  /** The token that was registered. */
  token: string;
}

/** The result of forgetting a phone. */
export interface PushUnregistered {
  /** False when the token was not registered for this user. */
  removed: boolean;
}

/** The user's push switch. */
export interface PushPreference {
  /** The user's own choice. */
  enabled: boolean;
  /** The creator's switch. Push arrives only when both are on. */
  community_enabled: boolean;
  /** How many phones the user has registered. */
  devices: number;
}

/** The user's choice. */
export interface SetPushPreferenceRequest {
  /** True for on, false for off. */
  enabled: boolean;
}

/** The push service a token belongs to. */
export type PushProvider = "expo" | "fcm";

/** What the app runs on. */
export type PushPlatform = "ios" | "android" | "web";

/** One message on the live connection. */
export interface LiveEvent {
  /** What happened. */
  type: LiveEventType;
  /** The topic concerned. Absent on `notification.created`. */
  topic_id?: string;
  /** The post concerned. Absent on coaching-chat events and on `notification.created` for a coach's message. */
  post_id?: string;
  /** The comment concerned, for comment events. */
  comment_id?: string;
  /** The chat message concerned, on `coach_message` events, and on `notification.created` for a coach's message. */
  message_id?: string;
  /** Whose chat a coaching-chat event is about. Sent only to the coach's side: a connection made with a secret key, for the backend or naming a coach or the creator. */
  member_external_id?: string;
  /** The comment it replies to, when it is a reply. */
  parent_id?: string;
  /** What the notification is about, on `notification.created`. */
  kind?: NotificationKind;
  /** Who wrote the post, comment or chat message, for created, updated and deleted events. Never sent for reactions. */
  author_external_id?: string;
  /** The full new list, for a reactions event. Empty when the last one was removed. */
  reactions?: LiveReaction[];
  /** The post's new comment count, for a comment event. */
  comments_count?: number;
}

/** One emoji and its count. Who gave it is not sent. */
export interface LiveReaction {
  /** The emoji. */
  emoji: string;
  /** How many members gave it. */
  count: number;
}

/** The label shown beside a member's name. It gives no extra permissions. */
export type Role = "user" | "coach" | "creator";

/** How the app presents the feed. */
export type FeedMode = "infinite_scroll" | "pages";

/** The order reaction chips are shown in. */
export type ReactionOrder = "most_used" | "first_added";

/** Where an upload is in its life. */
export type MediaStatus = "pending" | "ready" | "failed";

/** What a notification is about. */
export type NotificationKind = "post_reaction" | "comment_reaction" | "post_comment" | "comment_reply" | "coach_message";

/** The kinds of live message. */
export type LiveEventType = "post.created" | "post.deleted" | "post.pinned" | "post.unpinned" | "post.reactions" | "comment.created" | "comment.deleted" | "comment.reactions" | "notification.created" | "coach_message.created" | "coach_message.updated" | "coach_message.deleted" | "coach_chat.read" | "coach_chat.member_read";

/** The body of every non-2xx reply. */
export interface ErrorEnvelope {
  /** What went wrong. */
  error: ErrorBody;
}

/** What went wrong. */
export interface ErrorBody {
  /** Which problem this is. Branch on this. */
  code: ErrorCode;
  /** A sentence that can be shown to the user. */
  message: string;
  /** A reference for this request, to quote when reporting a problem. */
  request_id?: string;
  /** For `validation_failed`: each field that failed, and why. */
  fields?: Record<string, string>;
  /** How long to wait before trying again, when the server knows. Otherwise null. */
  retry_after_seconds: number | null;
}

/** The closed list of error codes. */
export type ErrorCode = "invalid_request" | "ambiguous_credentials" | "unauthenticated" | "credential_missing" | "credential_malformed" | "credential_unknown" | "credential_revoked" | "session_invalid" | "user_scope_violation" | "forbidden" | "not_found" | "method_not_allowed" | "conflict" | "username_taken" | "already_joined" | "community_join_required" | "comment_replies_disabled" | "profile_viewing_disabled" | "topic_name_taken" | "media_not_uploaded" | "media_too_large" | "media_invalid" | "payload_too_large" | "validation_failed" | "rate_limited" | "internal_error" | "service_unavailable" | "timeout";

