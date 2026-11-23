// The file picker entry: `pickFile`, bound to expo-document-picker. Kept out
// of the default entry so an app that only takes pictures installs nothing
// more.
import * as ExpoDocumentPicker from "expo-document-picker";
import type { CoachFile } from "@trackcore/community-react-native";
import { pickFileWith, type PickFileOptions } from "./attachments.js";
import { fromExpoDocumentPicker } from "./expo-document-picker.js";

export * from "./attachments.js";
export { fromExpoDocumentPicker, type ExpoDocumentPickerModule } from "./expo-document-picker.js";

const picker = fromExpoDocumentPicker(ExpoDocumentPicker);

/**
 * Opens the phone's file picker, uploads the document the user chose, and
 * resolves with it, ready to send: put its `id` in `fileIds`.
 *
 * The picker shows only what the chat takes: PDF, Word, Excel, PowerPoint,
 * RTF, text and CSV. Resolves with `null` when the user backs out.
 *
 * A member may send files only when the creator allows it: check
 * `coach_chat_files_enabled` in the settings before offering this.
 *
 * ```ts
 * const file = await pickFile();
 * if (file === null) return;
 * await Community.instance.coachChat.send({ fileIds: [file.id] });
 * ```
 */
export function pickFile(options: PickFileOptions = {}): Promise<CoachFile | null> {
  return pickFileWith(picker, options);
}
