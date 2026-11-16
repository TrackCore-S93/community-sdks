import { ValidationError } from "./errors.js";
import type { CallOptions } from "./options.js";
import type { Transport } from "./transport.js";
import type { CommentReactions, PostReactions, Reaction } from "./generated/types.js";

const enc = encodeURIComponent;

/**
 * What a reaction list looks like after the user gives or takes back an
 * emoji, worked out locally. Show this at once, then replace it with the list
 * the server returns. Giving an emoji already given, or taking back one not
 * given, changes nothing.
 */
export function applyReaction(reactions: readonly Reaction[], emoji: string, on: boolean): Reaction[] {
  const current = reactions.find((r) => r.emoji === emoji);
  if (on) {
    if (current?.reacted_by_me) return reactions.map((r) => ({ ...r }));
    if (current) return reactions.map((r) => (r.emoji === emoji ? { ...r, count: r.count + 1, reacted_by_me: true } : { ...r }));
    return [...reactions.map((r) => ({ ...r })), { emoji, count: 1, reacted_by_me: true }];
  }
  if (!current?.reacted_by_me) return reactions.map((r) => ({ ...r }));
  return reactions
    .map((r) => (r.emoji === emoji ? { ...r, count: r.count - 1, reacted_by_me: false } : { ...r }))
    .filter((r) => r.count > 0);
}

/** One emoji on one post or comment: the request in flight and what the user wants last. */
interface Chip<R> {
  wanted: boolean;
  sent: boolean | null;
  running: Promise<R> | null;
}

/** Emoji reactions on posts and comments. */
export class ReactionsAPI {
  readonly #chips = new Map<string, Chip<unknown>>();

  constructor(private readonly transport: Transport) {}

  /** Gives an emoji to a post. Giving it again changes nothing. */
  addToPost(postId: string, emoji: string, options: CallOptions = {}): Promise<PostReactions> {
    return this.#call("PUT", `/v1/posts/${enc(check("postId", postId))}/reactions/${enc(check("emoji", emoji))}`, options);
  }

  /** Takes an emoji back from a post. */
  removeFromPost(postId: string, emoji: string, options: CallOptions = {}): Promise<PostReactions> {
    return this.#call("DELETE", `/v1/posts/${enc(check("postId", postId))}/reactions/${enc(check("emoji", emoji))}`, options);
  }

  /** Gives an emoji to a comment. */
  addToComment(commentId: string, emoji: string, options: CallOptions = {}): Promise<CommentReactions> {
    return this.#call("PUT", `/v1/comments/${enc(check("commentId", commentId))}/reactions/${enc(check("emoji", emoji))}`, options);
  }

  /** Takes an emoji back from a comment. */
  removeFromComment(commentId: string, emoji: string, options: CallOptions = {}): Promise<CommentReactions> {
    return this.#call("DELETE", `/v1/comments/${enc(check("commentId", commentId))}/reactions/${enc(check("emoji", emoji))}`, options);
  }

  /**
   * Sets whether the user has given this emoji to a post, built for a chip
   * that is tapped fast. Only one request per chip is in flight at a time,
   * and when taps arrive while one is running, only the last wanted state is
   * sent afterwards. Every call resolves with the post's reactions once the
   * chip has settled, so the count can never be left wrong by rapid taps.
   */
  setOnPost(postId: string, emoji: string, on: boolean): Promise<PostReactions> {
    check("postId", postId);
    check("emoji", emoji);
    return this.#settle(`post:${postId}:${emoji}`, on, (want) =>
      want ? this.addToPost(postId, emoji) : this.removeFromPost(postId, emoji),
    );
  }

  /** The same as `setOnPost`, for a comment. */
  setOnComment(commentId: string, emoji: string, on: boolean): Promise<CommentReactions> {
    check("commentId", commentId);
    check("emoji", emoji);
    return this.#settle(`comment:${commentId}:${emoji}`, on, (want) =>
      want ? this.addToComment(commentId, emoji) : this.removeFromComment(commentId, emoji),
    );
  }

  #call<R>(method: "PUT" | "DELETE", path: string, options: CallOptions): Promise<R> {
    return this.transport.request<R>({ method, path, audience: "member", signal: options.signal });
  }

  #settle<R>(key: string, on: boolean, send: (want: boolean) => Promise<R>): Promise<R> {
    let chip = this.#chips.get(key) as Chip<R> | undefined;
    if (!chip) {
      chip = { wanted: on, sent: null, running: null };
      this.#chips.set(key, chip as Chip<unknown>);
    }
    chip.wanted = on;
    const state = chip;
    state.running ??= (async () => {
      try {
        let result: R;
        do {
          state.sent = state.wanted;
          result = await send(state.sent);
        } while (state.wanted !== state.sent);
        return result;
      } finally {
        this.#chips.delete(key);
      }
    })();
    return state.running;
  }
}

function check(field: string, value: string): string {
  if (typeof value !== "string" || value === "") throw new ValidationError(field, `${field} is required.`);
  return value;
}
