import { ValidationError } from "./errors.js";
import type { CallOptions } from "./options.js";
import type { Transport } from "./transport.js";
import { assertValidExternalId } from "./transport.js";
import type * as T from "./generated/types.js";

const enc = encodeURIComponent;

/** A key for a request that must not be applied twice when it is retried. */
export function newIdempotencyKey(): string {
  const c = (globalThis as { crypto?: { randomUUID?: () => string } }).crypto;
  if (typeof c?.randomUUID === "function") return c.randomUUID();
  let out = "";
  for (let i = 0; i < 32; i++) out += Math.floor(Math.random() * 16).toString(16);
  return out;
}

function required(field: string, value: unknown): void {
  if (typeof value !== "string" || value === "") throw new ValidationError(field, `${field} is required.`);
}

abstract class Namespace {
  constructor(protected readonly transport: Transport) {}
}

/** Sessions. Minting one for a named user is what `initialize` does for you. */
export class AuthAPI extends Namespace {
  /** Mints a session token for one end user. On a server, hand `token` to that user's device. */
  createSession(params: { externalId: string; ttlSeconds?: number } & CallOptions): Promise<T.Session> {
    assertValidExternalId(params.externalId);
    return this.transport.request({
      method: "POST", path: "/v1/auth/session", audience: "any_key", signal: params.signal,
      body: { external_id: params.externalId, ttl_seconds: params.ttlSeconds },
    });
  }

  /** Ends the session in use. `signOut` does this and forgets the user too. */
  async endSession(options: CallOptions = {}): Promise<void> {
    await this.transport.request({ method: "DELETE", path: "/v1/auth/session", audience: "session", signal: options.signal });
  }
}

/** End users. Secret key only. */
export class UsersAPI extends Namespace {
  /** Erases a user and everything stored for them. Erasing an unknown user is not an error. */
  delete(externalId: string, options: CallOptions = {}): Promise<T.ErasedUser> {
    assertValidExternalId(externalId);
    return this.transport.request({ method: "DELETE", path: `/v1/users/${enc(externalId)}`, audience: "creator", signal: options.signal });
  }
}

/** Joining the community, and profiles. */
export class CommunityAPI extends Namespace {
  /** Whether the user has joined, and their own profile. */
  me(options: CallOptions = {}): Promise<T.Membership> {
    return this.transport.request({ method: "GET", path: "/v1/community/me", audience: "member", signal: options.signal });
  }

  /** Whether a username is free. A hint for the form; `join` decides. */
  usernameAvailable(username: string, options: CallOptions = {}): Promise<T.UsernameAvailability> {
    required("username", username);
    return this.transport.request({
      method: "GET", path: "/v1/community/username-available", audience: "member", query: { username }, signal: options.signal,
    });
  }

  /** Joins the community under a username. Joining again under the same name is safe. */
  join(username: string, options: CallOptions = {}): Promise<T.Membership> {
    required("username", username);
    return this.transport.request({
      method: "POST", path: "/v1/community/join", audience: "member", body: { username },
      // Joining twice under one name returns the same profile, so a retry is safe.
      repeatable: true, signal: options.signal,
    });
  }

  /** Edits the user's own profile. Send only what changes; an empty media id removes that image. */
  updateProfile(
    changes: { username?: string; bio?: string; avatarMediaId?: string; coverMediaId?: string } & CallOptions,
  ): Promise<T.Membership> {
    return this.transport.request({
      method: "PATCH", path: "/v1/community/me", audience: "member", signal: changes.signal,
      body: {
        username: changes.username, bio: changes.bio,
        avatar_media_id: changes.avatarMediaId, cover_media_id: changes.coverMediaId,
      },
    });
  }

  /** Another member's profile, read only. */
  member(externalId: string, options: CallOptions = {}): Promise<T.Member> {
    assertValidExternalId(externalId);
    return this.transport.request({
      method: "GET", path: `/v1/community/members/${enc(externalId)}`, audience: "member_or_creator", signal: options.signal,
    });
  }

  /**
   * The community at a glance, for the card that leads into it: how many
   * members it has, and the profile photos of up to four members who have
   * one, picked at random on every call. The user need not have joined.
   */
  summary(options: CallOptions = {}): Promise<T.CommunitySummary> {
    return this.transport.request({
      method: "GET", path: "/v1/community/summary", audience: "member_or_creator", signal: options.signal,
    });
  }
}

/** The creator's member list and roles. Secret key only. */
export class MembersAPI extends Namespace {
  /** Everyone who has joined, in username order. */
  list(params: { q?: string; role?: T.Role; limit?: number; after?: string } & CallOptions = {}): Promise<T.MemberList> {
    return this.transport.request({
      method: "GET", path: "/v1/community/members", audience: "creator", signal: params.signal,
      query: { q: params.q, role: params.role, limit: params.limit, after: params.after },
    });
  }

  /** Changes a member's role. */
  setRole(externalId: string, role: T.Role, options: CallOptions = {}): Promise<T.Profile> {
    assertValidExternalId(externalId);
    return this.transport.request({
      method: "PATCH", path: `/v1/community/members/${enc(externalId)}`, audience: "creator", body: { role },
      // Setting the same role twice changes nothing, so a retry is safe.
      repeatable: true, signal: options.signal,
    });
  }
}

/** What a new topic needs. */
export interface CreateTopicParams extends CallOptions {
  name: string;
  description?: string;
  imageUrl?: string;
  coverUrl?: string;
  sortOrder?: number;
  isLive?: boolean;
  isTrending?: boolean;
}

/** Topics: the sections posts are written in. */
export class TopicsAPI extends Namespace {
  /** The community's topics. `trending: true` returns only trending ones. */
  list(params: { trending?: boolean } & CallOptions = {}): Promise<T.TopicList> {
    return this.transport.request({
      method: "GET", path: "/v1/topics", audience: "member_or_creator", signal: params.signal,
      query: { trending: params.trending ? true : undefined },
    });
  }

  /** One topic. */
  get(topicId: string, options: CallOptions = {}): Promise<T.Topic> {
    required("topicId", topicId);
    return this.transport.request({ method: "GET", path: `/v1/topics/${enc(topicId)}`, audience: "member_or_creator", signal: options.signal });
  }

  /** Creates a topic. Secret key only. */
  create(params: CreateTopicParams): Promise<T.Topic> {
    required("name", params.name);
    return this.transport.request({
      method: "POST", path: "/v1/topics", audience: "creator", signal: params.signal,
      body: {
        name: params.name, description: params.description, image_url: params.imageUrl, cover_url: params.coverUrl,
        sort_order: params.sortOrder, is_live: params.isLive, is_trending: params.isTrending,
      },
    });
  }

  /** Edits a topic. Send only what changes. Secret key only. */
  update(topicId: string, changes: Partial<Omit<CreateTopicParams, "signal">> & CallOptions): Promise<T.Topic> {
    required("topicId", topicId);
    return this.transport.request({
      method: "PATCH", path: `/v1/topics/${enc(topicId)}`, audience: "creator", signal: changes.signal,
      body: {
        name: changes.name, description: changes.description, image_url: changes.imageUrl, cover_url: changes.coverUrl,
        sort_order: changes.sortOrder, is_live: changes.isLive, is_trending: changes.isTrending,
      },
    });
  }

  /** Deletes a topic and its posts. Secret key only. */
  delete(topicId: string, options: CallOptions = {}): Promise<T.Deleted> {
    required("topicId", topicId);
    return this.transport.request({ method: "DELETE", path: `/v1/topics/${enc(topicId)}`, audience: "creator", signal: options.signal });
  }
}

/** Posts and the feed. */
export class PostsAPI extends Namespace {
  /**
   * One page of the feed, newest first. Send `before` or `after`, not both.
   * `limit` is the page size, 1 to 40: the app's own choice, 20 when left
   * out. Send the same `limit` with every page.
   */
  feed(params: { topicId?: string; limit?: number; before?: string; after?: string } & CallOptions = {}): Promise<T.Feed> {
    if (params.before && params.after) throw new ValidationError("before", "Send before or after, not both.");
    return this.transport.request({
      method: "GET", path: "/v1/posts", audience: "member_or_creator", signal: params.signal,
      query: { topic_id: params.topicId, limit: params.limit, before: params.before, after: params.after },
    });
  }

  /**
   * Writes a post: text, images, or both. A retry cannot post twice: the SDK
   * sends an idempotency key, its own unless you pass one.
   */
  create(params: { topicId: string; body?: string; mediaIds?: string[]; idempotencyKey?: string } & CallOptions): Promise<T.Post> {
    required("topicId", params.topicId);
    return this.transport.request({
      method: "POST", path: "/v1/posts", audience: "member", signal: params.signal,
      idempotencyKey: params.idempotencyKey ?? newIdempotencyKey(),
      body: { topic_id: params.topicId, body: params.body, media_ids: params.mediaIds },
    });
  }

  /** One post. */
  get(postId: string, options: CallOptions = {}): Promise<T.Post> {
    required("postId", postId);
    return this.transport.request({ method: "GET", path: `/v1/posts/${enc(postId)}`, audience: "member_or_creator", signal: options.signal });
  }

  /** Deletes a post: a member their own, the creator's backend any. */
  delete(postId: string, options: CallOptions = {}): Promise<T.Deleted> {
    required("postId", postId);
    return this.transport.request({ method: "DELETE", path: `/v1/posts/${enc(postId)}`, audience: "member_or_creator", signal: options.signal });
  }

  /** Pins a post to the top of the feed. Secret key only. */
  pin(postId: string, options: CallOptions = {}): Promise<T.Post> {
    required("postId", postId);
    return this.transport.request({ method: "PUT", path: `/v1/posts/${enc(postId)}/pin`, audience: "creator", signal: options.signal });
  }

  /** Unpins a post. Secret key only. */
  unpin(postId: string, options: CallOptions = {}): Promise<T.Post> {
    required("postId", postId);
    return this.transport.request({ method: "DELETE", path: `/v1/posts/${enc(postId)}/pin`, audience: "creator", signal: options.signal });
  }

  /** Posts whose text contains every word of `q`. No match is an empty list. */
  search(params: { q: string; topicId?: string; limit?: number; before?: string } & CallOptions): Promise<T.SearchResults> {
    if (typeof params.q !== "string" || [...params.q.trim()].length < 2) {
      throw new ValidationError("q", "q must be at least 2 characters.");
    }
    return this.transport.request({
      method: "GET", path: "/v1/search/posts", audience: "member_or_creator", signal: params.signal,
      query: { q: params.q, topic_id: params.topicId, limit: params.limit, before: params.before },
    });
  }
}

/** Comments and replies. */
export class CommentsAPI extends Namespace {
  /** A post's top-level comments, oldest first. */
  list(postId: string, params: { limit?: number; after?: string } & CallOptions = {}): Promise<T.CommentPage> {
    required("postId", postId);
    return this.transport.request({
      method: "GET", path: `/v1/posts/${enc(postId)}/comments`, audience: "member_or_creator", signal: params.signal,
      query: { limit: params.limit, after: params.after },
    });
  }

  /** A comment's replies, oldest first. */
  replies(commentId: string, params: { limit?: number; after?: string } & CallOptions = {}): Promise<T.CommentPage> {
    required("commentId", commentId);
    return this.transport.request({
      method: "GET", path: `/v1/comments/${enc(commentId)}/replies`, audience: "member_or_creator", signal: params.signal,
      query: { limit: params.limit, after: params.after },
    });
  }

  /** Comments on a post, or replies to a comment with `parentId`. A retry cannot comment twice. */
  create(
    postId: string,
    params: { body?: string; mediaIds?: string[]; parentId?: string; idempotencyKey?: string } & CallOptions,
  ): Promise<T.Comment> {
    required("postId", postId);
    return this.transport.request({
      method: "POST", path: `/v1/posts/${enc(postId)}/comments`, audience: "member", signal: params.signal,
      idempotencyKey: params.idempotencyKey ?? newIdempotencyKey(),
      body: { body: params.body, media_ids: params.mediaIds, parent_id: params.parentId },
    });
  }

  /** Deletes a comment: a member their own, the creator's backend any. */
  delete(commentId: string, options: CallOptions = {}): Promise<T.Deleted> {
    required("commentId", commentId);
    return this.transport.request({ method: "DELETE", path: `/v1/comments/${enc(commentId)}`, audience: "member_or_creator", signal: options.signal });
  }
}

/** Blocking members. */
export class BlocksAPI extends Namespace {
  /** The members the user has blocked. */
  list(options: CallOptions = {}): Promise<T.BlockList> {
    return this.transport.request({ method: "GET", path: "/v1/blocks", audience: "member", signal: options.signal });
  }

  /** Blocks a member. Blocking again changes nothing. */
  block(externalId: string, options: CallOptions = {}): Promise<T.BlockedMember> {
    assertValidExternalId(externalId);
    return this.transport.request({ method: "PUT", path: `/v1/blocks/${enc(externalId)}`, audience: "member", signal: options.signal });
  }

  /** Unblocks a member. */
  unblock(externalId: string, options: CallOptions = {}): Promise<T.Unblocked> {
    assertValidExternalId(externalId);
    return this.transport.request({ method: "DELETE", path: `/v1/blocks/${enc(externalId)}`, audience: "member", signal: options.signal });
  }
}

/** Reporting posts and comments. */
export class ReportsAPI extends Namespace {
  /** Reports a post. One member can report one post once. */
  reportPost(postId: string, reason: string, options: CallOptions = {}): Promise<T.Reported> {
    required("postId", postId);
    required("reason", reason);
    return this.transport.request({
      method: "POST", path: `/v1/posts/${enc(postId)}/reports`, audience: "member", body: { reason },
      // A second report by the same member is answered, not counted again.
      repeatable: true, signal: options.signal,
    });
  }

  /** Reports a comment. */
  reportComment(commentId: string, reason: string, options: CallOptions = {}): Promise<T.Reported> {
    required("commentId", commentId);
    required("reason", reason);
    return this.transport.request({
      method: "POST", path: `/v1/comments/${enc(commentId)}/reports`, audience: "member", body: { reason },
      repeatable: true, signal: options.signal,
    });
  }

  /** The reports on the community's content. Secret key only. */
  list(options: CallOptions = {}): Promise<T.ReportList> {
    return this.transport.request({ method: "GET", path: "/v1/reports", audience: "creator", signal: options.signal });
  }
}

/**
 * The moderation archive: posts and comments that reached the report
 * threshold. They are not deleted. Members no longer see them, and they are
 * kept here. Secret key only.
 */
export class ArchiveAPI extends Namespace {
  /** One page of the archive, newest first. */
  list(params: { limit?: number; before?: string } & CallOptions = {}): Promise<T.ArchiveList> {
    return this.transport.request({
      method: "GET", path: "/v1/moderation/archive", audience: "creator", signal: params.signal,
      query: { limit: params.limit, before: params.before },
    });
  }

  /** One archived post or comment, by its archive id. */
  get(archiveId: string, options: CallOptions = {}): Promise<T.Archived> {
    required("archiveId", archiveId);
    return this.transport.request({
      method: "GET", path: `/v1/moderation/archive/${enc(archiveId)}`, audience: "creator", signal: options.signal,
    });
  }
}

/** Notifications: what others did to what the user wrote. */
export class NotificationsAPI extends Namespace {
  /** One page of notifications, newest first. */
  list(params: { limit?: number; before?: string } & CallOptions = {}): Promise<T.NotificationList> {
    return this.transport.request({
      method: "GET", path: "/v1/notifications", audience: "member", signal: params.signal,
      query: { limit: params.limit, before: params.before },
    });
  }

  /** The number for the bell. */
  async unreadCount(options: CallOptions = {}): Promise<number> {
    const reply = await this.transport.request<T.UnreadCount>({
      method: "GET", path: "/v1/notifications/unread-count", audience: "member", signal: options.signal,
    });
    return reply.unread_count;
  }

  /** Marks every notification read. */
  async markAllRead(options: CallOptions = {}): Promise<void> {
    await this.transport.request({
      method: "POST", path: "/v1/notifications/read", audience: "member",
      repeatable: true, signal: options.signal,
    });
  }

  /** Marks one notification read: call it when the user opens the notification. */
  markRead(notificationId: string, options: CallOptions = {}): Promise<T.NotificationRead> {
    required("notificationId", notificationId);
    return this.transport.request({
      method: "POST", path: `/v1/notifications/${enc(notificationId)}/read`, audience: "member",
      repeatable: true, signal: options.signal,
    });
  }
}

/** What to register a phone with. */
export interface RegisterPushParams extends CallOptions {
  /** The push token the phone gave the app: an Expo push token or a Firebase Cloud Messaging token. */
  token: string;
  /** `expo` or `fcm`. Left out, it is worked out from the token. */
  provider?: T.PushProvider;
  /** `ios`, `android` or `web`. */
  platform?: T.PushPlatform;
}

/**
 * Push notifications: the same notifications, sent to the phone while the app
 * is closed. Get a push token from the phone (Expo's or Firebase's library),
 * then register it for the signed-in user.
 */
export class PushAPI extends Namespace {
  #token: string | null = null;

  /** The token this client registered and has not unregistered, or null. */
  get registeredToken(): string | null {
    return this.#token;
  }

  /**
   * Registers the phone's push token for the user. Safe to call on every
   * start: registering the same token again changes nothing. `signOut`
   * unregisters it.
   */
  async register(params: RegisterPushParams): Promise<T.PushDevice> {
    required("token", params.token);
    const device = await this.transport.request<T.PushDevice>({
      method: "PUT", path: "/v1/push/devices", audience: "member", repeatable: true, signal: params.signal,
      body: { token: params.token, provider: params.provider, platform: params.platform },
    });
    this.#token = params.token;
    return device;
  }

  /**
   * Forgets a push token, so the phone stops getting this user's
   * notifications. Without a token it forgets the one this client registered.
   * Resolves to whether a token was removed.
   */
  async unregister(token?: string, options: CallOptions = {}): Promise<boolean> {
    const target = token ?? this.#token;
    if (!target) return false;
    const reply = await this.transport.request<T.PushUnregistered>({
      method: "POST", path: "/v1/push/devices/unregister", audience: "member", repeatable: true,
      signal: options.signal, body: { token: target },
    });
    if (target === this.#token) this.#token = null;
    return reply.removed;
  }

  /** The user's push switch, the creator's, and how many phones are registered. */
  preference(options: CallOptions = {}): Promise<T.PushPreference> {
    return this.transport.request({ method: "GET", path: "/v1/push/preferences", audience: "member", signal: options.signal });
  }

  /** Turns the user's push notifications on or off. The notification list is not affected. */
  setEnabled(enabled: boolean, options: CallOptions = {}): Promise<T.PushPreference> {
    return this.transport.request({
      method: "PUT", path: "/v1/push/preferences", audience: "member", repeatable: true,
      signal: options.signal, body: { enabled },
    });
  }
}

/** What the creator can change. */
export interface UpdateSettingsParams extends CallOptions {
  maxImagesPerPost?: number;
  reactionOrder?: T.ReactionOrder;
  commentRepliesEnabled?: boolean;
  feedMode?: T.FeedMode;
  reportThreshold?: number;
  searchPageSize?: number;
  bioMaxLength?: number;
  profileViewingEnabled?: boolean;
  /** Whether notifications are also sent to members' phones. */
  pushEnabled?: boolean;
  /** Whether the coaching chat is offered. Off refuses every coaching-chat call with `coach_chat_disabled`. */
  coachChatEnabled?: boolean;
  /** Whether members may send voice notes in the coaching chat. */
  coachChatVoiceEnabled?: boolean;
  /** Whether members may send documents in the coaching chat. */
  coachChatFilesEnabled?: boolean;
}

/** The creator's settings. */
export class SettingsAPI extends Namespace {
  /** The settings. Any key can read them, so an app can adapt to them. */
  get(options: CallOptions = {}): Promise<T.Settings> {
    return this.transport.request({ method: "GET", path: "/v1/settings", audience: "any_key", signal: options.signal });
  }

  /** Changes settings. Send only what changes. Secret key only. */
  update(changes: UpdateSettingsParams): Promise<T.Settings> {
    return this.transport.request({
      method: "PATCH", path: "/v1/settings", audience: "creator", signal: changes.signal,
      // Setting the same values twice changes nothing, so a retry is safe.
      repeatable: true,
      body: {
        max_images_per_post: changes.maxImagesPerPost,
        reaction_order: changes.reactionOrder, comment_replies_enabled: changes.commentRepliesEnabled,
        feed_mode: changes.feedMode, report_threshold: changes.reportThreshold,
        search_page_size: changes.searchPageSize, bio_max_length: changes.bioMaxLength,
        profile_viewing_enabled: changes.profileViewingEnabled,
        push_enabled: changes.pushEnabled,
        coach_chat_enabled: changes.coachChatEnabled,
        coach_chat_voice_enabled: changes.coachChatVoiceEnabled,
        coach_chat_files_enabled: changes.coachChatFilesEnabled,
      },
    });
  }
}
