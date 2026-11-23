// The voice note entry: `VoiceRecorder`, bound to expo-av. Kept out of the
// default entry so an app that only takes pictures installs nothing more.
import { Audio } from "expo-av";
import { VoiceRecorderCore, type VoiceRecorderOptions } from "./attachments.js";
import { fromExpoAudio } from "./expo-av.js";

export * from "./attachments.js";
export { fromExpoAudio, type ExpoAudioModule } from "./expo-av.js";

/**
 * Records a voice note with the phone's microphone and uploads it, for the
 * coaching chat.
 *
 * ```ts
 * const recorder = new VoiceRecorder();
 * await recorder.start();               // asks for the microphone the first time
 * const note = await recorder.stop();   // uploads it; null when nothing was recorded
 * if (note) await Community.instance.coachChat.send({ fileIds: [note.id] });
 * ```
 *
 * `cancel()` throws the recording away instead. `elapsedMs` is how long it
 * has run, for a timer on screen.
 *
 * A member may send voice notes only when the creator allows it: check
 * `coach_chat_voice_enabled` in the settings before offering this.
 */
export class VoiceRecorder extends VoiceRecorderCore {
  constructor(options: VoiceRecorderOptions = {}) {
    super(fromExpoAudio(Audio), options);
  }
}
