import {
  Community as CoreCommunity,
  ConfigurationError,
  ConnectionError,
  ValidationError,
  type BlocksAPI,
  type CallOptions,
  type CoachChatAPI,
  type CoachFile,
  type CoachFileParams,
  type CommentsAPI,
  type CommunityAPI,
  type CommunityOptions,
  type EndUser,
  type FetchLike,
  type LiveAPI,
  type Media,
  type MediaAPI,
  type NotificationsAPI,
  type PostsAPI,
  type PushAPI,
  type ReactionsAPI,
  type ReportsAPI,
  type SettingsAPI,
  type TopicsAPI,
  type WhoAmI,
} from "@trackcore/community-sdk";

/** How the device client is built. The same as the JavaScript SDK's options, without `runtime`. */
export type CommunityDeviceOptions = Omit<CommunityOptions, "runtime">;

/** A file on the device, as an image picker or the camera returns it. */
export interface DeviceFile {
  /** Where the file is: a `file://`, `content://` or `ph://` address. */
  uri: string;
  /** The file's type, such as `image/jpeg`. Taken from the file when left out. */
  type?: string | null;
}

/** Image uploads, with one more way in: a file on the device. */
export type DeviceMediaAPI = MediaAPI & {
  /**
   * Uploads an image from a file on the device, such as the `uri` an image
   * picker or the camera returns. Reads the file, then does what `upload`
   * does: asks for a link, sends the file, and finishes.
   */
  uploadFile(file: DeviceFile, options?: CallOptions): Promise<Media>;
};

/** The member's side of the coaching chat, with one more way in: a file on the device. */
export type DeviceCoachChatAPI = Pick<
  CoachChatAPI,
  "get" | "messages" | "send" | "edit" | "delete" | "deleteImage" | "markRead" | "search" | "startFile" | "completeFile" | "uploadFile"
> & {
  /**
   * Uploads a voice note or a document from a file on the device, such as
   * the `uri` a document picker or a recorder returns. Reads the file, then
   * does what `uploadFile` does. The returned file's `id` goes in `fileIds`
   * of `send`.
   */
  uploadDeviceFile(file: DeviceFile, params: CoachFileParams): Promise<CoachFile>;
};

const SECRET_KEY = /^cm_sk_/;

/**
 * The Community client for React Native and Expo.
 *
 * It is the JavaScript SDK's client with three things fixed for a device: a
 * secret key is refused, always; the calls that need one (the creator's) are
 * not here; and the live connection is opened the way React Native's
 * WebSocket needs. The request layer, the retry policy, the error classes
 * and the models are the JavaScript SDK's own objects, imported.
 */
export class Community {
  static #shared: Community | null = null;

  /** The shared client. Call `configure` on it once, when the app starts. */
  static get instance(): Community {
    return (Community.#shared ??= new Community(null));
  }

  #core: CoreCommunity | null = null;
  #media: DeviceMediaAPI | null = null;
  #chat: DeviceCoachChatAPI | null = null;

  /** Pass options to build a ready client. */
  constructor(options?: CommunityDeviceOptions | null) {
    if (options !== null) this.configure(options ?? {});
  }

  /** Sets the key and the options. Call once, when the app starts. */
  configure(options: CommunityDeviceOptions): this {
    if (typeof options.apiKey === "string" && SECRET_KEY.test(options.apiKey)) {
      // Refused here as well as in the core, whatever the runtime looks like:
      // this package exists only to run on a device.
      throw new ConfigurationError(
        "secret_key_in_browser",
        "A Community secret key was given to the React Native SDK. Anything shipped in an app is readable by " +
          "whoever holds the app, so this key must be treated as compromised: revoke it and issue a new one. " +
          "Use a publishable key (cm_pk_…) here.",
      );
    }
    const core = new CoreCommunity({ ...options, runtime: "react-native" });
    const read: FetchLike = options.fetch ?? ((input, init) => fetch(input, init));
    this.#core = core;
    this.#media = Object.assign(Object.create(core.media) as MediaAPI, {
      uploadFile: (file: DeviceFile, callOptions: CallOptions = {}) => uploadFile(core.media, read, file, callOptions),
    });
    this.#chat = Object.assign(Object.create(core.coachChat) as CoachChatAPI, {
      uploadDeviceFile: async (file: DeviceFile, params: CoachFileParams) =>
        core.coachChat.uploadFile(await readDeviceFile(read, file, params.signal), params),
    });
    return this;
  }

  get #ready(): CoreCommunity {
    if (!this.#core) {
      throw new ConfigurationError("not_configured", "The client is not configured. Call configure({ apiKey }) first.");
    }
    return this.#core;
  }

  /**
   * Signs a user in, after your own sign-in. Mints a session for them and
   * renews it when it nears its end. Nothing else is needed: no token to
   * fetch and no backend endpoint.
   */
  initialize(externalId: string, options?: CallOptions): Promise<void> {
    return this.#ready.initialize(externalId, options);
  }

  /** Signs the user out: ends the session and forgets the user. */
  signOut(options?: CallOptions): Promise<void> {
    return this.#ready.signOut(options);
  }

  /** Carries a session token your backend minted for this user, instead of `initialize`. */
  setSession(sessionToken: string): void {
    this.#ready.setSession(sessionToken);
  }

  /** Forgets the session token. */
  clearSession(): void {
    this.#ready.clearSession();
  }

  /** The user signed in, or null. */
  get externalId(): string | null {
    return this.#ready.externalId;
  }

  /** The session token in use, or null. */
  get sessionToken(): string | null {
    return this.#ready.sessionToken;
  }

  /** `live` or `test`, from the key. */
  get environment(): "live" | "test" {
    return this.#ready.environment;
  }

  /** Always `publishable` on a device. */
  get keyKind(): "secret" | "publishable" {
    return this.#ready.keyKind;
  }

  /** Where the API answers. */
  get baseUrl(): string {
    return this.#ready.baseUrl;
  }

  /** The key, masked: safe to log. */
  describeCredential(): string {
    return this.#ready.describeCredential();
  }

  /** Which customer and environment the key belongs to. */
  whoAmI(options?: CallOptions): Promise<WhoAmI> {
    return this.#ready.whoAmI(options);
  }

  /** The user a call acts for, as the server sees it. */
  currentUser(options?: CallOptions): Promise<EndUser> {
    return this.#ready.currentUser(options);
  }

  /** Joining the community, and profiles. */
  get community(): CommunityAPI { return this.#ready.community; }
  /** Topics. Creating and editing them is the creator's, on a backend. */
  get topics(): Pick<TopicsAPI, "list" | "get"> { return this.#ready.topics; }
  /** Posts, the feed and search. Pinning is the creator's, on a backend. */
  get posts(): Pick<PostsAPI, "feed" | "get" | "create" | "update" | "byMember" | "delete" | "search"> { return this.#ready.posts; }
  /** Comments and replies. */
  get comments(): CommentsAPI { return this.#ready.comments; }
  /** Emoji reactions. */
  get reactions(): ReactionsAPI { return this.#ready.reactions; }
  /** Image uploads. */
  get media(): DeviceMediaAPI {
    void this.#ready;
    return this.#media!;
  }
  /** Blocking members. */
  get blocks(): BlocksAPI { return this.#ready.blocks; }
  /** Reporting posts and comments. Listing reports is the creator's, on a backend. */
  get reports(): Pick<ReportsAPI, "reportPost" | "reportComment"> { return this.#ready.reports; }
  /** Notifications. */
  get notifications(): NotificationsAPI { return this.#ready.notifications; }
  /**
   * The coaching chat: the member's one-to-one chat with their coach. A
   * member sends voice notes and documents when the creator allows it.
   * Answering as the coach is the creator's, on a backend.
   */
  get coachChat(): DeviceCoachChatAPI {
    void this.#ready;
    return this.#chat as DeviceCoachChatAPI;
  }
  /**
   * Push notifications. Get the phone's push token from Expo's or Firebase's
   * library and pass it to `push.register`; `signOut` unregisters it.
   */
  get push(): PushAPI { return this.#ready.push; }
  /** The creator's settings, to read. Changing them is the creator's, on a backend. */
  get settings(): Pick<SettingsAPI, "get"> { return this.#ready.settings; }
  /** Live updates. */
  get live(): LiveAPI { return this.#ready.live; }

  /** Nothing about the key or the session appears when a client is logged or serialised. */
  toJSON(): Record<string, unknown> {
    return this.#core ? this.#core.toJSON() : { configured: false };
  }
}

/** Builds a client you hold yourself. The same as `new Community(options)`. */
export function createCommunityClient(options: CommunityDeviceOptions): Community {
  return new Community(options);
}

async function readDeviceFile(read: FetchLike, file: DeviceFile, signal?: AbortSignal): Promise<Blob> {
  if (!file || typeof file.uri !== "string" || file.uri === "") {
    throw new ValidationError("file", "file.uri is required.");
  }
  try {
    // React Native's fetch reads a local file address into a Blob.
    const response = await read(file.uri, { signal });
    return await response.blob();
  } catch (error) {
    throw new ConnectionError("The file could not be read from the device.", { cause: error });
  }
}

async function uploadFile(media: MediaAPI, read: FetchLike, file: DeviceFile, options: CallOptions): Promise<Media> {
  const blob = await readDeviceFile(read, file, options.signal);
  return media.upload(blob, { contentType: file.type ?? (blob.type || undefined), signal: options.signal });
}
