import { ConnectionError, ValidationError, AbortError } from "./errors.js";
import type { CallOptions, FetchLike } from "./options.js";
import type { Transport } from "./transport.js";
import type { Media, Upload } from "./generated/types.js";

const enc = encodeURIComponent;

/** A file to upload: bytes, or anything `fetch` accepts as a body. */
export type UploadSource = Blob | ArrayBuffer | Uint8Array;

/** Uploading images, for posts, comments and profile pictures. */
export class MediaAPI {
  constructor(
    private readonly transport: Transport,
    private readonly fetchImpl: FetchLike,
  ) {}

  /** Step 1 of 3: asks for a link to send a file to. `upload` does all three steps. */
  start(options: CallOptions = {}): Promise<Upload> {
    return this.transport.request({ method: "POST", path: "/v1/media", audience: "member", signal: options.signal });
  }

  /** Step 3 of 3: tells the server the file has arrived. It checks, resizes and stores the image. */
  complete(mediaId: string, options: CallOptions = {}): Promise<Media> {
    if (!mediaId) throw new ValidationError("mediaId", "mediaId is required.");
    return this.transport.request({
      method: "POST", path: `/v1/media/${enc(mediaId)}/complete`, audience: "member",
      // Completing an upload twice returns the same image.
      repeatable: true, signal: options.signal,
    });
  }

  /** One of the user's uploads. */
  get(mediaId: string, options: CallOptions = {}): Promise<Media> {
    if (!mediaId) throw new ValidationError("mediaId", "mediaId is required.");
    return this.transport.request({ method: "GET", path: `/v1/media/${enc(mediaId)}`, audience: "member", signal: options.signal });
  }

  /**
   * Uploads one image: asks for a link, sends the file to it, and finishes
   * the upload. The returned image's `id` goes in a post's or comment's
   * `mediaIds`, or in `updateProfile`.
   */
  upload(file: UploadSource, options: { contentType?: string } & CallOptions = {}): Promise<Media> {
    return sendUpload(this.fetchImpl, file, options, () => this.start(options), (id) => this.complete(id, options));
  }
}

/**
 * The three steps of an upload, shared by every kind of image: ask for a
 * link, send the file to it, and finish.
 */
export async function sendUpload(
  fetchImpl: FetchLike,
  file: UploadSource,
  options: { contentType?: string } & CallOptions,
  start: () => Promise<Upload>,
  complete: (mediaId: string) => Promise<Media>,
): Promise<Media> {
  const size = file instanceof Blob ? file.size : file.byteLength;
  if (!size) throw new ValidationError("file", "The file is empty.");
  const started = await start();
  if (size > started.max_bytes) {
    throw new ValidationError("file", `The file is larger than the upload limit of ${started.max_bytes} bytes.`);
  }
  const contentType = options.contentType ?? (file instanceof Blob && file.type ? file.type : "application/octet-stream");
  let response: Response;
  try {
    // The link carries its own permission, so no key is sent with the file.
    response = await fetchImpl(started.upload.url, {
      method: started.upload.method,
      headers: { "Content-Type": contentType },
      body: file as BodyInit,
      signal: options.signal,
    });
  } catch (error) {
    if (options.signal?.aborted) throw new AbortError();
    throw new ConnectionError("The file could not be sent to storage.", { cause: error });
  }
  if (!response.ok) {
    throw new ConnectionError(`Storage refused the file (HTTP ${response.status}).`);
  }
  return complete(started.id);
}
