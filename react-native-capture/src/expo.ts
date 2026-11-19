// expo-image-picker as an ImagePicker. The module is passed in, not imported,
// so this file can be tested without it and has no opinion on its version.
import type { DeviceFile } from "@trackcore/community-react-native";
import { CapturePermissionError, type CaptureSource, type ImagePicker } from "./core.js";

interface PermissionAnswer {
  granted: boolean;
  canAskAgain?: boolean;
}

interface PickedAsset {
  uri: string;
  mimeType?: string | null;
}

interface PickerResult {
  canceled?: boolean;
  /** The name older versions used. */
  cancelled?: boolean;
  assets?: PickedAsset[] | null;
}

/** The part of expo-image-picker this package calls. */
export interface ExpoImagePickerModule {
  requestCameraPermissionsAsync(): Promise<PermissionAnswer>;
  launchCameraAsync(options?: Record<string, unknown>): Promise<PickerResult>;
  launchImageLibraryAsync(options?: Record<string, unknown>): Promise<PickerResult>;
}

// Images only is the picker's default. One picture, as it is: the server
// turns it the right way up and makes the sizes, so nothing is cropped or
// squeezed on the phone. `exif: false` keeps the location out of the result.
const OPTIONS = { allowsEditing: false, allowsMultipleSelection: false, quality: 1, exif: false };

/** Makes an `ImagePicker` from the expo-image-picker module. */
export function fromExpoImagePicker(expo: ExpoImagePickerModule): ImagePicker {
  return {
    async pick(source: CaptureSource): Promise<DeviceFile | null> {
      let result: PickerResult;
      if (source === "camera") {
        // The camera needs the user's permission. The gallery does not: the
        // phone's own picker runs outside the app and hands back one file.
        const permission = await expo.requestCameraPermissionsAsync();
        if (!permission.granted) throw new CapturePermissionError("camera", permission.canAskAgain !== false);
        result = await expo.launchCameraAsync(OPTIONS);
      } else {
        result = await expo.launchImageLibraryAsync(OPTIONS);
      }
      if (result.canceled === true || result.cancelled === true) return null;
      const asset = result.assets?.[0];
      if (!asset) return null;
      return { uri: asset.uri, type: asset.mimeType ?? null };
    },
  };
}
