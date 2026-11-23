// The part of this package that has no picker of its own: the call, its
// errors and its types. `index.ts` binds it to expo-image-picker; an app
// with another picker imports from here and passes its own.
import {
  AbortError,
  Community,
  CommunityClientError,
  ValidationError,
  type CallOptions,
  type DeviceFile,
  type Media,
} from "@trackcore/community-react-native";

/** Where the picture comes from. */
export type CaptureSource = "camera" | "gallery";

/**
 * What opens the camera or the gallery. `pick` resolves with the file the
 * user chose, or `null` when they backed out. It throws
 * `CapturePermissionError` when the user has refused access.
 */
export interface ImagePicker {
  pick(source: CaptureSource): Promise<DeviceFile | null>;
}

/** The part of a Community client this package uses. */
export interface CaptureClient {
  readonly media: { uploadFile(file: DeviceFile, options?: CallOptions): Promise<Media> };
}

export interface CaptureOptions {
  /** `"camera"` takes a new picture; `"gallery"` picks one the user has. */
  source: CaptureSource;
  /** The client to upload with. Left out, `Community.instance`. */
  client?: CaptureClient;
  /** Cancels the upload. It cannot close the camera or the gallery. */
  signal?: AbortSignal;
}

/** The user has refused access to the camera or the photo library. */
export class CapturePermissionError extends CommunityClientError {
  constructor(
    /** What was refused. */
    readonly source: CaptureSource,
    /**
     * False when the phone will not ask again: the user has to turn the
     * permission on in the phone's Settings. Send them there.
     */
    readonly canAskAgain: boolean,
  ) {
    super(
      source === "camera"
        ? "The user has not allowed this app to use the camera."
        : "The user has not allowed this app to read the photo library.",
    );
  }
}

/** The camera or the gallery could not be opened, or gave back nothing usable. */
export class CaptureUnavailableError extends CommunityClientError {
  constructor(readonly source: CaptureSource, message: string, options?: { cause?: unknown }) {
    super(message);
    if (options?.cause !== undefined) (this as { cause?: unknown }).cause = options.cause;
  }
}

/**
 * Opens the camera or the gallery with `picker`, uploads the picture the
 * user chose, and resolves with it once the server has finished it: the
 * `id` goes into `mediaIds` on a post or comment, or into a profile.
 *
 * Resolves with `null` when the user backs out. Nothing is uploaded then.
 */
export async function captureImageWith(picker: ImagePicker, options: CaptureOptions): Promise<Media | null> {
  const source = options?.source;
  if (source !== "camera" && source !== "gallery") {
    throw new ValidationError("source", 'source must be "camera" or "gallery".');
  }
  if (options.signal?.aborted) throw new AbortError();
  // Read the client before the picker opens, so a client that was never
  // configured fails now and not after the user has taken a picture.
  const media = (options.client ?? Community.instance).media;

  let file: DeviceFile | null;
  try {
    file = await picker.pick(source);
  } catch (error) {
    if (error instanceof CommunityClientError) throw error;
    throw new CaptureUnavailableError(
      source,
      source === "camera" ? "The camera could not be opened." : "The gallery could not be opened.",
      { cause: error },
    );
  }
  if (file === null) return null;
  if (typeof file?.uri !== "string" || file.uri === "") {
    throw new CaptureUnavailableError(source, "The picker returned no file.");
  }
  if (options.signal?.aborted) throw new AbortError();
  return media.uploadFile({ uri: file.uri, type: file.type ?? null }, { signal: options.signal });
}

/** Binds `captureImageWith` to one picker, for an app that brings its own. */
export function createCapture(picker: ImagePicker): (options: CaptureOptions) => Promise<Media | null> {
  return (options) => captureImageWith(picker, options);
}

export * from "./attachments.js";
