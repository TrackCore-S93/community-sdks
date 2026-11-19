import { test } from "node:test";
import assert from "node:assert/strict";
import * as capture from "../dist/esm/core.js";
import { fromExpoImagePicker } from "../dist/esm/expo.js";
import { Community, CommunityClientError, ValidationError, AbortError, ConfigurationError } from "@trackcore/community-react-native";

const { captureImageWith, createCapture, CapturePermissionError, CaptureUnavailableError } = capture;
const MEDIA = { id: "cm_med_1", status: "ready", url: "https://img.test/a.jpg" };

/** A client that records what it was asked to upload. */
function fakeClient(reply = MEDIA) {
  const uploads = [];
  return {
    uploads,
    media: {
      uploadFile: async (file, options) => {
        uploads.push({ file, options });
        if (reply instanceof Error) throw reply;
        return reply;
      },
    },
  };
}
const pickerOf = (answer) => {
  const asked = [];
  return { asked, pick: async (source) => { asked.push(source); if (answer instanceof Error) throw answer; return answer; } };
};

test("it opens the picker asked for, uploads the file and returns the image", async () => {
  for (const source of ["camera", "gallery"]) {
    const client = fakeClient();
    const picker = pickerOf({ uri: "file:///photo.heic", type: "image/heic" });
    const image = await captureImageWith(picker, { client, source });
    assert.deepEqual(picker.asked, [source]);
    assert.deepEqual(client.uploads.map((u) => u.file), [{ uri: "file:///photo.heic", type: "image/heic" }]);
    assert.equal(image, MEDIA);
  }
});

test("backing out returns null and uploads nothing", async () => {
  const client = fakeClient();
  assert.equal(await captureImageWith(pickerOf(null), { client, source: "gallery" }), null);
  assert.equal(client.uploads.length, 0);
});

test("a source that is neither camera nor gallery is refused before the picker opens", async () => {
  const picker = pickerOf({ uri: "file:///a.jpg" });
  for (const options of [{ source: "video" }, {}, undefined]) {
    await assert.rejects(captureImageWith(picker, options && { client: fakeClient(), ...options }), (e) => e instanceof ValidationError && e.field === "source");
  }
  assert.equal(picker.asked.length, 0);
});

test("a refused permission is its own error and says whether the phone will ask again", async () => {
  const client = fakeClient();
  const refused = new CapturePermissionError("camera", false);
  await assert.rejects(captureImageWith(pickerOf(refused), { client, source: "camera" }), (e) =>
    e === refused && e instanceof CommunityClientError && e.source === "camera" && e.canAskAgain === false && e.name === "CapturePermissionError");
  assert.equal(client.uploads.length, 0);
});

test("a picker that breaks, or returns no file, is CaptureUnavailableError with the cause kept", async () => {
  const cause = new Error("no camera on this device");
  await assert.rejects(captureImageWith(pickerOf(cause), { client: fakeClient(), source: "camera" }), (e) =>
    e instanceof CaptureUnavailableError && e.cause === cause && e.source === "camera");
  await assert.rejects(captureImageWith(pickerOf({ uri: "" }), { client: fakeClient(), source: "gallery" }), CaptureUnavailableError);
});

test("an upload error reaches the caller unchanged", async () => {
  const failure = new ValidationError("file", "The file is larger than the upload limit.");
  await assert.rejects(captureImageWith(pickerOf({ uri: "file:///big.jpg" }), { client: fakeClient(failure), source: "gallery" }), (e) => e === failure);
});

test("a signal that has fired stops it before the picker and before the upload", async () => {
  const fired = AbortSignal.abort();
  const picker = pickerOf({ uri: "file:///a.jpg" });
  await assert.rejects(captureImageWith(picker, { client: fakeClient(), source: "camera", signal: fired }), AbortError);
  assert.equal(picker.asked.length, 0);

  const controller = new AbortController();
  const client = fakeClient();
  const slow = { pick: async () => { controller.abort(); return { uri: "file:///a.jpg" }; } };
  await assert.rejects(captureImageWith(slow, { client, source: "camera", signal: controller.signal }), AbortError);
  assert.equal(client.uploads.length, 0);
});

test("the signal is passed on to the upload", async () => {
  const controller = new AbortController();
  const client = fakeClient();
  await captureImageWith(pickerOf({ uri: "file:///a.jpg" }), { client, source: "gallery", signal: controller.signal });
  assert.equal(client.uploads[0].options.signal, controller.signal);
});

test("with no client it uses Community.instance, and fails before the picker if that is not configured", async () => {
  const picker = pickerOf({ uri: "file:///a.jpg" });
  await assert.rejects(captureImageWith(picker, { source: "camera" }), (e) => e instanceof ConfigurationError && e.reason === "not_configured");
  assert.equal(picker.asked.length, 0);
  assert.ok(Community.instance);
});

test("createCapture binds a picker", async () => {
  const client = fakeClient();
  const captureImage = createCapture(pickerOf({ uri: "content://media/1", type: null }));
  assert.equal(await captureImage({ client, source: "gallery" }), MEDIA);
  assert.deepEqual(client.uploads[0].file, { uri: "content://media/1", type: null });
});

// ---- the expo-image-picker binding ----

function fakeExpo({ permission = { granted: true, canAskAgain: true }, result }) {
  const calls = [];
  return {
    calls,
    requestCameraPermissionsAsync: async () => { calls.push("permission"); return permission; },
    launchCameraAsync: async (options) => { calls.push(["camera", options]); return result; },
    launchImageLibraryAsync: async (options) => { calls.push(["gallery", options]); return result; },
  };
}
const picked = { canceled: false, assets: [{ uri: "file:///p.jpg", mimeType: "image/jpeg", width: 10, height: 10 }] };

test("expo: the camera asks for permission first, the gallery does not", async () => {
  const expo = fakeExpo({ result: picked });
  assert.deepEqual(await fromExpoImagePicker(expo).pick("camera"), { uri: "file:///p.jpg", type: "image/jpeg" });
  assert.deepEqual(expo.calls.map((c) => (Array.isArray(c) ? c[0] : c)), ["permission", "camera"]);

  const other = fakeExpo({ result: picked });
  await fromExpoImagePicker(other).pick("gallery");
  assert.deepEqual(other.calls.map((c) => (Array.isArray(c) ? c[0] : c)), ["gallery"]);
});

test("expo: one picture, untouched, without its location", async () => {
  const expo = fakeExpo({ result: picked });
  await fromExpoImagePicker(expo).pick("gallery");
  assert.deepEqual(expo.calls[0][1], { allowsEditing: false, allowsMultipleSelection: false, quality: 1, exif: false });
});

test("expo: a refused camera permission throws, and never opens the camera", async () => {
  for (const [canAskAgain, expected] of [[false, false], [true, true], [undefined, true]]) {
    const expo = fakeExpo({ permission: { granted: false, canAskAgain }, result: picked });
    await assert.rejects(fromExpoImagePicker(expo).pick("camera"), (e) => e instanceof CapturePermissionError && e.source === "camera" && e.canAskAgain === expected);
    assert.deepEqual(expo.calls, ["permission"]);
  }
});

test("expo: backing out is null, under either spelling, and so is an empty result", async () => {
  for (const result of [{ canceled: true, assets: null }, { cancelled: true }, { canceled: false, assets: [] }, { canceled: false, assets: null }]) {
    assert.equal(await fromExpoImagePicker(fakeExpo({ result })).pick("gallery"), null);
  }
});

test("expo: a picture with no type is passed on without one", async () => {
  const expo = fakeExpo({ result: { canceled: false, assets: [{ uri: "ph://ABC" }] } });
  assert.deepEqual(await fromExpoImagePicker(expo).pick("gallery"), { uri: "ph://ABC", type: null });
});
