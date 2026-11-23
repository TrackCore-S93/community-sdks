// Picking a document and recording a voice note for the coaching chat: the
// calls, their errors and their types, with no picker or recorder of their
// own. `files.ts` binds the first to expo-document-picker and `voice.ts` the
// second to expo-av; an app with other libraries imports from here.
import {
  AbortError,
  Community,
  CommunityClientError,
  type CoachFile,
  type CoachFileParams,
  type DeviceFile,
} from "@trackcore/community-react-native";

/** The endings a document may have, and the type each stands for: the same list the server accepts. */
export const DOCUMENT_TYPES: Readonly<Record<string, string>> = Object.freeze({
  pdf: "application/pdf",
  doc: "application/msword",
  docx: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  xls: "application/vnd.ms-excel",
  xlsx: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  ppt: "application/vnd.ms-powerpoint",
  pptx: "application/vnd.openxmlformats-officedocument.presentationml.presentation",
  rtf: "application/rtf",
  txt: "text/plain",
  csv: "text/csv",
});

/** The type a document's name stands for, or `null` when the chat does not take that kind of file. */
export function documentTypeOf(name: string): string | null {
  const dot = name.lastIndexOf(".");
  if (dot < 0 || dot === name.length - 1) return null;
  return DOCUMENT_TYPES[name.slice(dot + 1).toLowerCase()] ?? null;
}

/** The user has refused the microphone. */
export class MicrophonePermissionError extends CommunityClientError {
  constructor(
    /**
     * False when the phone will not ask again: the user has to turn the
     * permission on in the phone's Settings. Send them there.
     */
    readonly canAskAgain: boolean,
  ) {
    super("The user has not allowed this app to use the microphone.");
  }
}

/** The file picker or the recorder could not be used, or gave back nothing usable. */
export class AttachmentUnavailableError extends CommunityClientError {
  constructor(message: string, options?: { cause?: unknown }) {
    super(message);
    if (options?.cause !== undefined) (this as { cause?: unknown }).cause = options.cause;
  }
}

/** The part of a Community client these calls use. */
export interface AttachmentClient {
  readonly coachChat: { uploadDeviceFile(file: DeviceFile, params: CoachFileParams): Promise<CoachFile> };
}

/** A document as a picker hands it over. */
export interface PickedDocument {
  uri: string;
  /** The file's name, with its ending. */
  name: string;
}

/** What opens the phone's file picker. `pick` resolves with `null` when the user backs out. */
export interface DocumentPicker {
  pick(): Promise<PickedDocument | null>;
}

export interface PickFileOptions {
  /** The client to upload with. Left out, `Community.instance`. */
  client?: AttachmentClient;
  /** Cancels the upload. It cannot close the file picker. */
  signal?: AbortSignal;
}

/**
 * Opens the file picker with `picker`, uploads the document the user chose,
 * and resolves with it once it is ready: the `id` goes in `fileIds` when
 * sending a coaching-chat message.
 *
 * Resolves with `null` when the user backs out. Nothing is uploaded then.
 */
export async function pickFileWith(picker: DocumentPicker, options: PickFileOptions = {}): Promise<CoachFile | null> {
  if (options.signal?.aborted) throw new AbortError();
  // Read the client before the picker opens, so a client that was never
  // configured fails now and not after the user has chosen a file.
  const chat = (options.client ?? (Community.instance as unknown as AttachmentClient)).coachChat;

  let picked: PickedDocument | null;
  try {
    picked = await picker.pick();
  } catch (error) {
    if (error instanceof CommunityClientError) throw error;
    throw new AttachmentUnavailableError("The file picker could not be opened.", { cause: error });
  }
  if (picked === null) return null;
  if (typeof picked?.uri !== "string" || picked.uri === "" || typeof picked.name !== "string") {
    throw new AttachmentUnavailableError("The picker returned no file.");
  }
  const contentType = documentTypeOf(picked.name);
  if (contentType === null) {
    throw new AttachmentUnavailableError(
      "This kind of file cannot be sent. Choose a PDF, Word, Excel, PowerPoint, RTF, text or CSV file.",
    );
  }
  if (options.signal?.aborted) throw new AbortError();
  return chat.uploadDeviceFile(
    { uri: picked.uri, type: contentType },
    { kind: "file", fileName: picked.name, contentType, signal: options.signal },
  );
}

/** What a recording is once it is stopped. */
export interface Recording {
  uri: string;
  fileName: string;
  contentType: string;
}

/** The phone's microphone, as much of it as a voice note needs. */
export interface RecorderDevice {
  /** Asks for the microphone if it has not been asked yet. */
  allow(): Promise<{ granted: boolean; canAskAgain?: boolean }>;
  start(): Promise<void>;
  /** Stops and resolves with what was recorded, or `null` when there is nothing. */
  stop(): Promise<Recording | null>;
  /** Stops and throws the recording away. */
  discard(): Promise<void>;
}

export interface VoiceRecorderOptions {
  /** The client to upload with. Left out, `Community.instance`. */
  client?: AttachmentClient;
  /** The clock, for tests. */
  now?: () => number;
}

/**
 * Records one voice note at a time with `device` and uploads it.
 *
 * ```ts
 * await recorder.start();               // asks for the microphone the first time
 * const note = await recorder.stop();   // uploads it; null when nothing was recorded
 * if (note) await community.coachChat.send({ fileIds: [note.id] });
 * ```
 */
export class VoiceRecorderCore {
  readonly #device: RecorderDevice;
  readonly #client: AttachmentClient | undefined;
  readonly #now: () => number;
  #startedAt: number | null = null;

  constructor(device: RecorderDevice, options: VoiceRecorderOptions = {}) {
    this.#device = device;
    this.#client = options.client;
    this.#now = options.now ?? (() => Date.now());
  }

  /** Whether a recording is in progress. */
  get isRecording(): boolean {
    return this.#startedAt !== null;
  }

  /** How long the recording in progress has run, in milliseconds. Zero when there is none. */
  get elapsedMs(): number {
    return this.#startedAt === null ? 0 : this.#now() - this.#startedAt;
  }

  /**
   * Starts recording. Asks the user for the microphone the first time.
   * Throws `MicrophonePermissionError` when the user has refused it. Calling
   * it while already recording does nothing.
   */
  async start(): Promise<void> {
    if (this.isRecording) return;
    // A client that was never configured fails now, not after the recording.
    void (this.#client ?? (Community.instance as unknown as AttachmentClient)).coachChat;
    let answer: { granted: boolean; canAskAgain?: boolean };
    try {
      answer = await this.#device.allow();
    } catch (error) {
      throw new AttachmentUnavailableError("The microphone could not be used.", { cause: error });
    }
    if (!answer.granted) throw new MicrophonePermissionError(answer.canAskAgain !== false);
    try {
      await this.#device.start();
    } catch (error) {
      throw new AttachmentUnavailableError("The recording could not be started.", { cause: error });
    }
    this.#startedAt = this.#now();
  }

  /**
   * Stops, uploads the voice note and resolves with it: its `id` goes in
   * `fileIds` when sending a message. Resolves with `null` when nothing was
   * being recorded or nothing was captured.
   */
  async stop(options: { signal?: AbortSignal } = {}): Promise<CoachFile | null> {
    const startedAt = this.#startedAt;
    if (startedAt === null) return null;
    const durationMs = Math.max(0, this.#now() - startedAt);
    this.#startedAt = null;
    let recording: Recording | null;
    try {
      recording = await this.#device.stop();
    } catch (error) {
      throw new AttachmentUnavailableError("The recording could not be saved.", { cause: error });
    }
    if (recording === null || typeof recording.uri !== "string" || recording.uri === "") return null;
    if (options.signal?.aborted) throw new AbortError();
    const chat = (this.#client ?? (Community.instance as unknown as AttachmentClient)).coachChat;
    return chat.uploadDeviceFile(
      { uri: recording.uri, type: recording.contentType },
      { kind: "voice", fileName: recording.fileName, contentType: recording.contentType, durationMs, signal: options.signal },
    );
  }

  /** Stops and throws the recording away. Nothing is uploaded. */
  async cancel(): Promise<void> {
    if (this.#startedAt === null) return;
    this.#startedAt = null;
    try {
      await this.#device.discard();
    } catch {
      // Nothing to keep either way.
    }
  }
}
