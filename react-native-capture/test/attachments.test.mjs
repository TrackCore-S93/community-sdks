import { test } from "node:test";
import assert from "node:assert/strict";
import * as core from "../dist/esm/attachments.js";
import { fromExpoDocumentPicker } from "../dist/esm/expo-document-picker.js";
import { fromExpoAudio } from "../dist/esm/expo-av.js";
import { CommunityClientError, AbortError } from "@trackcore/community-react-native";

const { pickFileWith, VoiceRecorderCore, documentTypeOf, MicrophonePermissionError, AttachmentUnavailableError } = core;
const FILE = { id: "cm_att_1", kind: "file", name: "Food diary.pdf" };

/** A client that records what it was asked to upload. */
function fakeClient(reply = FILE) {
  const uploads = [];
  return {
    uploads,
    coachChat: {
      uploadDeviceFile: async (file, params) => {
        uploads.push({ file, params });
        if (reply instanceof Error) throw reply;
        return reply;
      },
    },
  };
}
const pickerOf = (answer) => ({ pick: async () => { if (answer instanceof Error) throw answer; return answer; } });

test("pickFile uploads the chosen document as a file, with its type", async () => {
  const client = fakeClient();
  const got = await pickFileWith(pickerOf({ uri: "file:///cache/Food diary.PDF", name: "Food diary.PDF" }), { client });
  assert.equal(got, FILE);
  assert.deepEqual(client.uploads[0].file, { uri: "file:///cache/Food diary.PDF", type: "application/pdf" });
  assert.equal(client.uploads[0].params.kind, "file");
  assert.equal(client.uploads[0].params.fileName, "Food diary.PDF");
  assert.equal(client.uploads[0].params.contentType, "application/pdf");
});

test("it knows every kind of document the chat takes", () => {
  assert.match(documentTypeOf("a.docx"), /wordprocessingml/);
  assert.match(documentTypeOf("a.xlsx"), /spreadsheetml/);
  assert.equal(documentTypeOf("notes.txt"), "text/plain");
  assert.equal(documentTypeOf("data.CSV"), "text/csv");
  assert.equal(documentTypeOf("photo.jpg"), null);
  assert.equal(documentTypeOf("noending"), null);
});

test("backing out of the file picker uploads nothing", async () => {
  const client = fakeClient();
  assert.equal(await pickFileWith(pickerOf(null), { client }), null);
  assert.equal(client.uploads.length, 0);
});

test("a file the chat does not take, a picker that fails and a cancelled call are refused", async () => {
  const client = fakeClient();
  await assert.rejects(pickFileWith(pickerOf({ uri: "file:///m.mp4", name: "movie.mp4" }), { client }), AttachmentUnavailableError);
  await assert.rejects(pickFileWith(pickerOf({ uri: "", name: "a.pdf" }), { client }), AttachmentUnavailableError);
  const cause = new Error("no picker");
  await assert.rejects(pickFileWith(pickerOf(cause), { client }), (e) => e instanceof AttachmentUnavailableError && e.cause === cause && e instanceof CommunityClientError);
  const stopped = new AbortController();
  stopped.abort();
  await assert.rejects(pickFileWith(pickerOf({ uri: "file:///a.pdf", name: "a.pdf" }), { client, signal: stopped.signal }), AbortError);
  assert.equal(client.uploads.length, 0);
});

test("the expo document picker asks for one file of the chat's kinds", async () => {
  const asked = [];
  const expo = { getDocumentAsync: async (options) => { asked.push(options); return { canceled: false, assets: [{ uri: "file:///cache/plan.pdf", name: "plan.pdf" }] }; } };
  assert.deepEqual(await fromExpoDocumentPicker(expo).pick(), { uri: "file:///cache/plan.pdf", name: "plan.pdf" });
  assert.equal(asked[0].multiple, false);
  assert.equal(asked[0].copyToCacheDirectory, true);
  assert.ok(asked[0].type.includes("application/pdf") && asked[0].type.includes("text/csv"));
  // Backing out, in the new and the old shape.
  assert.equal(await fromExpoDocumentPicker({ getDocumentAsync: async () => ({ canceled: true, assets: null }) }).pick(), null);
  assert.equal(await fromExpoDocumentPicker({ getDocumentAsync: async () => ({ type: "cancel" }) }).pick(), null);
  // No name given: it comes from the address.
  assert.deepEqual(
    await fromExpoDocumentPicker({ getDocumentAsync: async () => ({ canceled: false, assets: [{ uri: "file:///cache/My%20plan.pdf" }] }) }).pick(),
    { uri: "file:///cache/My%20plan.pdf", name: "My plan.pdf" },
  );
});

/** Stands in for the phone's microphone. */
function microphone({ granted = true, canAskAgain = true, recording = { uri: "file:///cache/v.m4a", fileName: "v.m4a", contentType: "audio/mp4" }, startError } = {}) {
  const calls = [];
  return {
    calls,
    allow: async () => { calls.push("allow"); return { granted, canAskAgain }; },
    start: async () => { calls.push("start"); if (startError) throw startError; },
    stop: async () => { calls.push("stop"); return recording; },
    discard: async () => { calls.push("discard"); },
  };
}

test("the recorder records, then uploads a voice note with its length", async () => {
  let now = 1_000;
  const client = fakeClient({ id: "cm_att_2", kind: "voice" });
  const device = microphone();
  const recorder = new VoiceRecorderCore(device, { client, now: () => now });
  assert.equal(recorder.isRecording, false);
  assert.equal(recorder.elapsedMs, 0);
  await recorder.start();
  assert.equal(recorder.isRecording, true);
  now += 9_000;
  assert.equal(recorder.elapsedMs, 9_000);
  await recorder.start(); // already recording: nothing happens
  const note = await recorder.stop();
  assert.equal(note.id, "cm_att_2");
  assert.equal(recorder.isRecording, false);
  assert.deepEqual(device.calls, ["allow", "start", "stop"]);
  assert.deepEqual(client.uploads[0].file, { uri: "file:///cache/v.m4a", type: "audio/mp4" });
  assert.equal(client.uploads[0].params.kind, "voice");
  assert.equal(client.uploads[0].params.fileName, "v.m4a");
  assert.equal(client.uploads[0].params.durationMs, 9_000);
});

test("a refused microphone records nothing, and says whether it can ask again", async () => {
  const client = fakeClient();
  const device = microphone({ granted: false, canAskAgain: false });
  const recorder = new VoiceRecorderCore(device, { client });
  await assert.rejects(recorder.start(), (e) => e instanceof MicrophonePermissionError && e.canAskAgain === false);
  assert.equal(recorder.isRecording, false);
  assert.deepEqual(device.calls, ["allow"]);
  assert.equal(await recorder.stop(), null);
});

test("cancel throws the recording away; nothing captured uploads nothing; a failed start is reported", async () => {
  const client = fakeClient();
  const device = microphone();
  const recorder = new VoiceRecorderCore(device, { client });
  await recorder.start();
  await recorder.cancel();
  assert.deepEqual(device.calls, ["allow", "start", "discard"]);
  assert.equal(await recorder.stop(), null);

  const empty = new VoiceRecorderCore(microphone({ recording: null }), { client });
  await empty.start();
  assert.equal(await empty.stop(), null);
  assert.equal(client.uploads.length, 0);

  const broken = new VoiceRecorderCore(microphone({ startError: new Error("busy") }), { client });
  await assert.rejects(broken.start(), AttachmentUnavailableError);
  assert.equal(broken.isRecording, false);
});

test("expo-av records an m4a and gives the speaker back", async () => {
  const modes = [];
  let stopped = 0;
  const audio = {
    requestPermissionsAsync: async () => ({ granted: true, canAskAgain: true }),
    setAudioModeAsync: async (mode) => { modes.push(mode); },
    Recording: { createAsync: async (preset) => ({ recording: { preset, stopAndUnloadAsync: async () => { stopped++; }, getURI: () => "file:///cache/rec-1.m4a" } }) },
    RecordingOptionsPresets: { HIGH_QUALITY: "high" },
  };
  const device = fromExpoAudio(audio);
  assert.deepEqual(await device.allow(), { granted: true, canAskAgain: true });
  await device.start();
  assert.deepEqual(modes[0], { allowsRecordingIOS: true, playsInSilentModeIOS: true });
  assert.deepEqual(await device.stop(), { uri: "file:///cache/rec-1.m4a", fileName: "rec-1.m4a", contentType: "audio/mp4" });
  assert.equal(stopped, 1);
  assert.deepEqual(modes[1], { allowsRecordingIOS: false });
  // Nothing in progress: nothing to stop.
  assert.equal(await device.stop(), null);
  await device.start();
  await device.discard();
  assert.equal(stopped, 2);
});
