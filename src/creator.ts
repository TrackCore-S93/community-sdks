import {
  Community as CoreCommunity,
  ConfigurationError,
  type CallOptions,
  type CommentsAPI,
  type CommunityOptions,
  type MembersAPI,
  type PostsAPI,
  type ReportsAPI,
  type SettingsAPI,
  type TopicsAPI,
  type UsersAPI,
  type WhoAmI,
} from "@trackcore/community-sdk";

/**
 * How the creator client is built: the JavaScript SDK's options, without
 * `runtime`, plus one statement about where the key comes from.
 */
export type CommunityCreatorOptions = Omit<CommunityOptions, "runtime"> & {
  /**
   * Must be `true`. It says the secret key is typed or pasted in by the
   * creator while the app runs and kept in the device's secure storage, and
   * is NOT written in the app's code, its config, or an environment variable
   * that is built into the app. Anything built into an app can be read by
   * whoever holds the app file.
   */
  secretKeyIsEnteredByTheCreatorAndNotBuiltIntoTheApp: true;
};

const SECRET_KEY = /^cm_sk_/;

/**
 * The creator's client for React Native and Expo: everything a creator's own
 * app (a CMS) does to run the community. Settings, topics, members and roles,
 * pinning, reports, deleting any post or comment, and erasing a user.
 *
 * It takes the creator's SECRET key, which controls the whole community. So
 * it belongs only in an app that is given to the creator and nobody else,
 * and the key is entered by the creator at run time, never shipped inside
 * the app. The members' app uses `Community` from the package's main entry,
 * which refuses a secret key.
 *
 * No user is named on this client: reads see what the creator sees, hidden
 * topics included, and deletes may remove anyone's content.
 */
export class CommunityCreator {
  readonly #core: CoreCommunity;

  constructor(options: CommunityCreatorOptions) {
    const { secretKeyIsEnteredByTheCreatorAndNotBuiltIntoTheApp: stated, ...rest } = options;
    if (stated !== true) {
      throw new ConfigurationError(
        "secret_key_in_browser",
        "The creator client takes a secret key, which must never be built into an app. Pass " +
          "secretKeyIsEnteredByTheCreatorAndNotBuiltIntoTheApp: true to state that the creator enters the key " +
          "while the app runs and that it is kept in the device's secure storage.",
      );
    }
    if (typeof rest.apiKey !== "string" || !SECRET_KEY.test(rest.apiKey)) {
      throw new ConfigurationError(
        "secret_key_required",
        "The creator client needs the creator's secret key (cm_sk_…). A publishable key cannot run the community.",
      );
    }
    // The core refuses a secret key on a device. Here that refusal is lifted
    // on purpose: the statement above is the creator's app taking it on.
    this.#core = new CoreCommunity({ ...rest, runtime: "server" });
  }

  /** Which customer and environment the key belongs to. The quickest check that the key the creator entered works. */
  whoAmI(options?: CallOptions): Promise<WhoAmI> {
    return this.#core.whoAmI(options);
  }

  /** `live` or `test`, from the key. */
  get environment(): "live" | "test" {
    return this.#core.environment;
  }

  /** Where the API answers. */
  get baseUrl(): string {
    return this.#core.baseUrl;
  }

  /** The key, masked: safe to show on screen and to log. */
  describeCredential(): string {
    return this.#core.describeCredential();
  }

  /** The creator's settings: read and change. */
  get settings(): SettingsAPI { return this.#core.settings; }
  /** Topics: list (hidden ones included), create, edit, hide, delete. */
  get topics(): TopicsAPI { return this.#core.topics; }
  /** The member list and roles. */
  get members(): MembersAPI { return this.#core.members; }
  /** The feed as the creator sees it, pinning, and deleting any post. */
  get posts(): Pick<PostsAPI, "feed" | "get" | "delete" | "pin" | "unpin"> { return this.#core.posts; }
  /** Reading a post's comments, and deleting any comment. */
  get comments(): Pick<CommentsAPI, "list" | "replies" | "delete"> { return this.#core.comments; }
  /** The reports members have made. */
  get reports(): Pick<ReportsAPI, "list"> { return this.#core.reports; }
  /** Erasing an end user. */
  get users(): UsersAPI { return this.#core.users; }

  /** Nothing about the key appears when the client is logged or serialised. */
  toJSON(): Record<string, unknown> {
    return { baseUrl: this.baseUrl, environment: this.environment, credential: this.describeCredential() };
  }
}

/** Builds the creator's client. */
export function createCreatorClient(options: CommunityCreatorOptions): CommunityCreator {
  return new CommunityCreator(options);
}

// The types and error helpers a creator's app needs, from the same place.
export * from "@trackcore/community-sdk";
