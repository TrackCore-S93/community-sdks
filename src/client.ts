import { ConfigurationError } from "./errors.js";
import type { CallOptions, CommunityOptions } from "./options.js";
import { Transport } from "./transport.js";
import {
  AuthAPI, BlocksAPI, CommentsAPI, CommunityAPI, MembersAPI, NotificationsAPI, PostsAPI, ReportsAPI, SettingsAPI,
  TopicsAPI, UsersAPI,
} from "./api.js";
import { LiveAPI } from "./live.js";
import { MediaAPI } from "./media.js";
import { ReactionsAPI } from "./reactions.js";
import type { EndUser, WhoAmI } from "./generated/types.js";

/**
 * The Community client. Build one with `new Community(options)` and keep it,
 * or configure the shared one once with `Community.instance.configure(options)`.
 * The client holds no connection and no per-request state, so one for the
 * whole process is right.
 */
export class Community {
  static #shared: Community | null = null;

  /** The shared client. Call `configure` on it once, at start-up. */
  static get instance(): Community {
    return (Community.#shared ??= new Community(null));
  }

  #transport: Transport | null = null;
  #apis: ReturnType<typeof buildAPIs> | null = null;

  /** Pass options to build a ready client. */
  constructor(options?: CommunityOptions | null) {
    if (options !== null) this.configure(options ?? {});
  }

  /** Sets the key and the options. Call once, before anything else. Calling again replaces them and signs out. */
  configure(options: CommunityOptions): this {
    const transport = new Transport(options);
    this.#transport = transport;
    this.#apis = buildAPIs(transport, options);
    return this;
  }

  get #ready(): { transport: Transport; apis: ReturnType<typeof buildAPIs> } {
    if (!this.#transport || !this.#apis) {
      throw new ConfigurationError("not_configured", "The client is not configured. Call configure({ apiKey, baseUrl }) first.");
    }
    return { transport: this.#transport, apis: this.#apis };
  }

  /**
   * Signs a user in, after your own sign-in. With a publishable key this
   * mints a session for them and renews it when it nears its end. With a
   * secret key it names the user and makes no network call.
   */
  initialize(externalId: string, options: CallOptions = {}): Promise<void> {
    return this.#ready.transport.initialize(externalId, options.signal);
  }

  /** Signs the user out: ends the session where there is one, and forgets the user. */
  signOut(options: CallOptions = {}): Promise<void> {
    return this.#ready.transport.signOut(options.signal);
  }

  /** Names the user every later request acts for. For a server; no network call. */
  setUser(externalId: string): void {
    this.#ready.transport.setUser(externalId);
  }

  /** Stops naming a user. */
  clearUser(): void {
    this.#ready.transport.clearUser();
  }

  /** Carries a session token your backend minted for this user. */
  setSession(sessionToken: string): void {
    this.#ready.transport.setSession(sessionToken);
  }

  /** Forgets the session token. */
  clearSession(): void {
    this.#ready.transport.clearSession();
  }

  /** The user requests act for, or null. */
  get externalId(): string | null {
    return this.#ready.transport.externalId;
  }

  /** The session token in use, or null. */
  get sessionToken(): string | null {
    return this.#ready.transport.sessionToken;
  }

  /** `live` or `test`, from the key. */
  get environment(): "live" | "test" {
    return this.#ready.transport.environment;
  }

  /** `secret` or `publishable`, from the key. */
  get keyKind(): "secret" | "publishable" {
    return this.#ready.transport.keyKind;
  }

  /** Where the API answers. */
  get baseUrl(): string {
    return this.#ready.transport.baseUrl;
  }

  /** The key, masked: safe to log. */
  describeCredential(): string {
    return this.#ready.transport.describeCredential();
  }

  /** Which customer and environment the key belongs to. The quickest check that a key works. */
  whoAmI(options: CallOptions = {}): Promise<WhoAmI> {
    return this.#ready.transport.request({ method: "GET", path: "/v1/me", audience: "any_key", signal: options.signal });
  }

  /** The user a call acts for, as the server sees it. */
  currentUser(options: CallOptions = {}): Promise<EndUser> {
    return this.#ready.transport.request({ method: "GET", path: "/v1/users/me", audience: "member", signal: options.signal });
  }

  /** Sessions. */
  get auth(): AuthAPI { return this.#ready.apis.auth; }
  /** Erasing end users. Secret key only. */
  get users(): UsersAPI { return this.#ready.apis.users; }
  /** Joining the community, and profiles. */
  get community(): CommunityAPI { return this.#ready.apis.community; }
  /** The creator's member list and roles. Secret key only. */
  get members(): MembersAPI { return this.#ready.apis.members; }
  /** Topics. */
  get topics(): TopicsAPI { return this.#ready.apis.topics; }
  /** Posts, the feed and search. */
  get posts(): PostsAPI { return this.#ready.apis.posts; }
  /** Comments and replies. */
  get comments(): CommentsAPI { return this.#ready.apis.comments; }
  /** Emoji reactions. */
  get reactions(): ReactionsAPI { return this.#ready.apis.reactions; }
  /** Image uploads. */
  get media(): MediaAPI { return this.#ready.apis.media; }
  /** Blocking members. */
  get blocks(): BlocksAPI { return this.#ready.apis.blocks; }
  /** Reports. */
  get reports(): ReportsAPI { return this.#ready.apis.reports; }
  /** Notifications. */
  get notifications(): NotificationsAPI { return this.#ready.apis.notifications; }
  /** The creator's settings. */
  get settings(): SettingsAPI { return this.#ready.apis.settings; }
  /** Live updates. */
  get live(): LiveAPI { return this.#ready.apis.live; }

  /** Nothing about the key or the session appears when a client is logged or serialised. */
  toJSON(): Record<string, unknown> {
    if (!this.#transport) return { configured: false };
    const t = this.#transport;
    return { configured: true, baseUrl: t.baseUrl, environment: t.environment, keyKind: t.keyKind, credential: t.describeCredential() };
  }
}

function buildAPIs(transport: Transport, options: CommunityOptions) {
  return {
    auth: new AuthAPI(transport),
    users: new UsersAPI(transport),
    community: new CommunityAPI(transport),
    members: new MembersAPI(transport),
    topics: new TopicsAPI(transport),
    posts: new PostsAPI(transport),
    comments: new CommentsAPI(transport),
    reactions: new ReactionsAPI(transport),
    media: new MediaAPI(transport, transport.fetch),
    blocks: new BlocksAPI(transport),
    reports: new ReportsAPI(transport),
    notifications: new NotificationsAPI(transport),
    settings: new SettingsAPI(transport),
    live: new LiveAPI(transport, options.webSocket),
  };
}
