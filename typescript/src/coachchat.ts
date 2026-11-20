import { AbortError, ConnectionError, ValidationError } from "./errors.js";
import type { CallOptions, FetchLike } from "./options.js";
import type { Transport } from "./transport.js";
import { assertValidExternalId } from "./transport.js";
import { newIdempotencyKey } from "./api.js";
import type { UploadSource } from "./media.js";
import type {
  CoachChat, CoachChatList, CoachFile, CoachFileUpload, CoachMessage, CoachMessagePage, CoachSearchResults, Deleted,
} from "./generated/types.js";

const enc = encodeURIComponent;

function required(field: string, value: unknown): void {
  if (typeof value !== "string" || value === "") throw new ValidationError(field, `${field} is required.`);
}

/** Which slice of the chat to read. Pass at most one of `before`, `after` and `around`. */
export interface CoachMessagesParams extends CallOptions {
  /** The page size, 1 to 100. 30 when left out. */
  limit?: number;
  /** An `older_cursor`: the messages above, for scrolling up. */
  before?: string;
  /** A `newer_cursor`: the messages below, and how to catch up after a live event. */
  after?: string;
  /** A message id: the page with that message in the middle, for a search result. */
  around?: string;
}

/** A voice note or a document about to be uploaded. */
export interface CoachFileParams extends CallOptions {
  /** `"voice"` for a voice note, `"file"` for a document. */
  kind: "voice" | "file";
  /** The file's name, shown to the member. */
  fileName: string;
  /** The file's type: any audio type for a voice note; PDF, Word, Excel, PowerPoint, RTF, text or CSV for a document. */
  contentType: string;
  /** A voice note's length in milliseconds. Optional. */
  durationMs?: number;
}

/** A message from the coach's side. */
export interface SendAsCoachParams extends CallOptions {
  /** The member whose chat it goes into: your own id for that user. */
  memberId: string;
  body?: string;
  /** Images uploaded as this coach with `media.upload`. */
  mediaIds?: string[];
  /** Voice notes and documents uploaded as this coach with `coachChat.uploadFile`. */
  fileIds?: string[];
  idempotencyKey?: string;
}

/**
 * The coaching chat: a member's one-to-one chat with their coach.
 *
 * Every member has one chat; it needs no id and is made by its first
 * message. A member sends text and images. Voice notes and documents come
 * from the coach's side only.
 *
 * `chats`, `memberMessages`, `markMemberRead`, `startFile`, `completeFile`,
 * `uploadFile` and `sendAsCoach` are the coach's side. They need a secret
 * key, and the coach named with `initialize` or `setUser`: a member of the
 * community whose role is `coach` or `creator`.
 */
export class CoachChatAPI {
  constructor(
    private readonly transport: Transport,
    private readonly fetchImpl: FetchLike,
  ) {}

  /** The chat at a glance: the unread count for a badge, and when the last message was sent. */
  get(options: CallOptions = {}): Promise<CoachChat> {
    return this.transport.request({ method: "GET", path: "/v1/coach-chat", audience: "member", signal: options.signal });
  }

  /** One page of the chat, oldest first. With no cursor, the newest messages. */
  messages(params: CoachMessagesParams = {}): Promise<CoachMessagePage> {
    if ([params.before, params.after, params.around].filter((v) => v !== undefined && v !== "").length > 1) {
      throw new ValidationError("before", "Pass at most one of before, after and around.");
    }
    return this.transport.request({
      method: "GET", path: "/v1/coach-chat/messages", audience: "member", signal: params.signal,
      query: { limit: params.limit, before: params.before, after: params.after, around: params.around },
    });
  }

  /**
   * Sends a message to the coach: text, images, or both. A retry cannot send
   * twice: the SDK sends an idempotency key, its own unless you pass one.
   * Sending also marks the chat read for the member.
   */
  send(params: { body?: string; mediaIds?: string[]; idempotencyKey?: string } & CallOptions): Promise<CoachMessage> {
    return this.transport.request({
      method: "POST", path: "/v1/coach-chat/messages", audience: "member", signal: params.signal,
      idempotencyKey: params.idempotencyKey ?? newIdempotencyKey(),
      body: { body: params.body, media_ids: params.mediaIds },
    });
  }

  /** Changes the text of one of the user's own messages. Its images stay. */
  edit(messageId: string, body: string, options: CallOptions = {}): Promise<CoachMessage> {
    required("messageId", messageId);
    if (typeof body !== "string") throw new ValidationError("body", "body is required.");
    return this.transport.request({
      method: "PATCH", path: `/v1/coach-chat/messages/${enc(messageId)}`, audience: "member", signal: options.signal,
      body: { body },
    });
  }

  /** Deletes one of the user's own messages for good, with its images. */
  delete(messageId: string, options: CallOptions = {}): Promise<Deleted> {
    required("messageId", messageId);
    return this.transport.request({
      method: "DELETE", path: `/v1/coach-chat/messages/${enc(messageId)}`, audience: "member", signal: options.signal,
    });
  }

  /** The user has seen the chat: call it while the chat is open and a message from the coach is on screen. */
  markRead(options: CallOptions = {}): Promise<CoachChat> {
    return this.transport.request({
      method: "POST", path: "/v1/coach-chat/read", audience: "member", repeatable: true, signal: options.signal,
    });
  }

  /** Finds messages by the words in their text, newest first. Jump to one with `messages({ around: id })`. */
  search(params: { q: string; limit?: number; before?: string } & CallOptions): Promise<CoachSearchResults> {
    const q = typeof params.q === "string" ? params.q.trim() : "";
    if ([...q].length < 2) throw new ValidationError("q", "q must be at least 2 characters.");
    return this.transport.request({
      method: "GET", path: "/v1/coach-chat/search", audience: "member", signal: params.signal,
      query: { q, limit: params.limit, before: params.before },
    });
  }

  // ---- the coach's side ----

  /**
   * The coach's list of chats: every member's chat that has a message, the
   * one with the newest message first. Each has the member, how many of
   * their messages the coach's side has not seen, and the newest message for
   * a preview line. `next_cursor`, passed as `before`, gives the next page.
   */
  chats(params: { limit?: number; before?: string; unreadOnly?: boolean } & CallOptions = {}): Promise<CoachChatList> {
    return this.transport.request({
      method: "GET", path: "/v1/coach-chat/members", audience: "coach", signal: params.signal,
      query: { limit: params.limit, before: params.before, unread: params.unreadOnly ? true : undefined },
    });
  }

  /**
   * One page of one member's chat as the coach's side sees it, oldest first.
   * `is_mine` is true on the messages the coach's side wrote. Reading does
   * not mark the chat read: call `markMemberRead` for that.
   */
  memberMessages(memberId: string, params: CoachMessagesParams = {}): Promise<CoachMessagePage> {
    assertValidExternalId(memberId);
    if ([params.before, params.after, params.around].filter((v) => v !== undefined && v !== "").length > 1) {
      throw new ValidationError("before", "Pass at most one of before, after and around.");
    }
    return this.transport.request({
      method: "GET", path: `/v1/coach-chat/members/${enc(memberId)}/messages`, audience: "coach", signal: params.signal,
      query: { limit: params.limit, before: params.before, after: params.after, around: params.around },
    });
  }

  /** The coach has seen the member's chat: the member's messages show as read in their app. */
  markMemberRead(memberId: string, options: CallOptions = {}): Promise<CoachChat> {
    assertValidExternalId(memberId);
    return this.transport.request({
      method: "POST", path: `/v1/coach-chat/members/${enc(memberId)}/read`, audience: "coach", repeatable: true, signal: options.signal,
    });
  }

  /** Step 1 of 3 for a voice note or a document: asks for a link to send it to. `uploadFile` does all three. */
  startFile(params: CoachFileParams): Promise<CoachFileUpload> {
    required("fileName", params.fileName);
    required("contentType", params.contentType);
    if (params.kind !== "voice" && params.kind !== "file") throw new ValidationError("kind", 'kind must be "voice" or "file".');
    return this.transport.request({
      method: "POST", path: "/v1/coach-chat/files", audience: "coach", signal: params.signal,
      body: { kind: params.kind, file_name: params.fileName, content_type: params.contentType, duration_ms: params.durationMs },
    });
  }

  /** Step 3 of 3: tells the server the file has arrived. */
  completeFile(fileId: string, options: CallOptions = {}): Promise<CoachFile> {
    required("fileId", fileId);
    return this.transport.request({
      method: "POST", path: `/v1/coach-chat/files/${enc(fileId)}/complete`, audience: "coach",
      // Completing an upload twice returns the same file.
      repeatable: true, signal: options.signal,
    });
  }

  /**
   * Uploads one voice note or document: asks for a link, sends the file to
   * it, and finishes the upload. The returned file's `id` goes in
   * `sendAsCoach`'s `fileIds`.
   */
  async uploadFile(file: UploadSource, params: CoachFileParams): Promise<CoachFile> {
    const size = file instanceof Blob ? file.size : file.byteLength;
    if (!size) throw new ValidationError("file", "The file is empty.");
    const started = await this.startFile(params);
    if (size > started.max_bytes) {
      throw new ValidationError("file", `The file is larger than the upload limit of ${started.max_bytes} bytes.`);
    }
    let response: Response;
    try {
      // The link carries its own permission, so no key is sent with the file.
      response = await this.fetchImpl(started.upload.url, {
        method: started.upload.method,
        headers: { "Content-Type": params.contentType },
        body: file as BodyInit,
        signal: params.signal,
      });
    } catch (error) {
      if (params.signal?.aborted) throw new AbortError();
      throw new ConnectionError("The file could not be sent to storage.", { cause: error });
    }
    if (!response.ok) {
      throw new ConnectionError(`Storage refused the file (HTTP ${response.status}).`);
    }
    return this.completeFile(started.id, { signal: params.signal });
  }

  /**
   * Sends a message into one member's chat as the coach: text, images, files,
   * or any mix. It makes the chat if this is its first message, and marks the
   * chat read for the coach's side.
   */
  sendAsCoach(params: SendAsCoachParams): Promise<CoachMessage> {
    assertValidExternalId(params.memberId);
    return this.transport.request({
      method: "POST", path: `/v1/coach-chat/members/${enc(params.memberId)}/messages`, audience: "coach", signal: params.signal,
      idempotencyKey: params.idempotencyKey ?? newIdempotencyKey(),
      body: { body: params.body, media_ids: params.mediaIds, file_ids: params.fileIds },
    });
  }
}
