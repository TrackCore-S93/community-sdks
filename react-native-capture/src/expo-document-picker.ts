// expo-document-picker as a DocumentPicker. The module is passed in, not
// imported, so this file can be tested without it.
import { DOCUMENT_TYPES, type DocumentPicker, type PickedDocument } from "./attachments.js";

interface DocumentResult {
  canceled?: boolean;
  assets?: Array<{ uri: string; name?: string | null }> | null;
  /** What older versions returned. */
  type?: string;
  uri?: string;
  name?: string;
}

/** The part of expo-document-picker this package calls. */
export interface ExpoDocumentPickerModule {
  getDocumentAsync(options?: Record<string, unknown>): Promise<DocumentResult>;
}

// One file, of the kinds the chat takes, copied where the app can read it.
const OPTIONS = { type: Object.values(DOCUMENT_TYPES), multiple: false, copyToCacheDirectory: true };

/** Makes a `DocumentPicker` from the expo-document-picker module. */
export function fromExpoDocumentPicker(expo: ExpoDocumentPickerModule): DocumentPicker {
  return {
    async pick(): Promise<PickedDocument | null> {
      const result = await expo.getDocumentAsync(OPTIONS);
      if (result.canceled === true || result.type === "cancel") return null;
      const asset = result.assets?.[0] ?? (result.uri ? { uri: result.uri, name: result.name } : undefined);
      if (!asset) return null;
      // A picker that gives no name still gave an address that ends in one.
      const name = asset.name ?? decodeURIComponent(asset.uri.slice(asset.uri.lastIndexOf("/") + 1));
      return { uri: asset.uri, name };
    },
  };
}
