// expo-av as a RecorderDevice. The module is passed in, not imported, so
// this file can be tested without it.
import type { RecorderDevice, Recording } from "./attachments.js";

interface ExpoRecording {
  stopAndUnloadAsync(): Promise<unknown>;
  getURI(): string | null;
}

/** The part of expo-av this package calls: its `Audio` object. */
export interface ExpoAudioModule {
  requestPermissionsAsync(): Promise<{ granted: boolean; canAskAgain?: boolean }>;
  setAudioModeAsync(mode: Record<string, unknown>): Promise<unknown>;
  Recording: { createAsync(options?: unknown): Promise<{ recording: ExpoRecording }> };
  RecordingOptionsPresets: { HIGH_QUALITY: unknown };
}

/**
 * Makes a `RecorderDevice` from expo-av's `Audio`. It records with the
 * high-quality preset: AAC in an MPEG-4 file (`.m4a`) on both iOS and
 * Android, which every phone and browser plays.
 */
export function fromExpoAudio(audio: ExpoAudioModule): RecorderDevice {
  let current: ExpoRecording | null = null;

  async function finish(): Promise<string | null> {
    const recording = current;
    current = null;
    if (!recording) return null;
    await recording.stopAndUnloadAsync();
    // Give the speaker back to whatever plays next.
    await audio.setAudioModeAsync({ allowsRecordingIOS: false }).catch(() => undefined);
    return recording.getURI();
  }

  return {
    allow: () => audio.requestPermissionsAsync(),
    async start(): Promise<void> {
      await audio.setAudioModeAsync({ allowsRecordingIOS: true, playsInSilentModeIOS: true });
      current = (await audio.Recording.createAsync(audio.RecordingOptionsPresets.HIGH_QUALITY)).recording;
    },
    async stop(): Promise<Recording | null> {
      const uri = await finish();
      if (!uri) return null;
      const name = uri.slice(uri.lastIndexOf("/") + 1);
      return { uri, fileName: name.toLowerCase().endsWith(".m4a") ? name : `voice-${Date.now()}.m4a`, contentType: "audio/mp4" };
    },
    async discard(): Promise<void> {
      await finish();
    },
  };
}
