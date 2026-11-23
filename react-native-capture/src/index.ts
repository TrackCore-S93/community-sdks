// The default entry: the capture call, bound to expo-image-picker.
import * as ExpoImagePicker from "expo-image-picker";
import type { Media } from "@trackcore/community-react-native";
import { captureImageWith, type CaptureOptions } from "./core.js";
import { fromExpoImagePicker } from "./expo.js";

export * from "./core.js";
export { fromExpoImagePicker, type ExpoImagePickerModule } from "./expo.js";

const picker = fromExpoImagePicker(ExpoImagePicker);

/**
 * Opens the camera or the gallery, uploads the picture the user chose, and
 * resolves with it, ready to attach: put its `id` in `mediaIds`.
 *
 * Resolves with `null` when the user backs out.
 *
 * ```ts
 * const image = await captureImage({ source: "camera" });   // or "gallery"
 * if (image === null) return;
 * await Community.instance.posts.create({ topicId, body, mediaIds: [image.id] });
 * ```
 */
export function captureImage(options: CaptureOptions): Promise<Media | null> {
  return captureImageWith(picker, options);
}

/** The version of this package. */
export const CAPTURE_VERSION = "0.1.1";
