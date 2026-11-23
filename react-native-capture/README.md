# @trackcore/community-react-native-capture

Opens the camera or the gallery and uploads the picture to Community, in one
call. An add-on to
[`@trackcore/community-react-native`](../react-native): the app writes no
picker code and never handles the file.

```ts
import { captureImage } from "@trackcore/community-react-native-capture";

const image = await captureImage({ source: "camera" });   // or "gallery"
if (image === null) return;                                // the user backed out
await Community.instance.posts.create({ topicId, body, mediaIds: [image.id] });
```

Documentation: https://community.trackcore.app/developer/sdk/react-native/media

## Install

It is installed from this repository's releases, beside the two packages it
builds on, and it uses `expo-image-picker` to open the camera and the gallery.

```sh
npm install https://github.com/TrackCore-S93/community-sdks/releases/download/react-native-capture-v0.1.1/trackcore-community-react-native-capture-0.1.1.tgz
npx expo install expo-image-picker
```

`expo-image-picker` works in Expo Go, in a development build, and in a
React Native app without Expo that has
[Expo modules installed](https://docs.expo.dev/bare/installing-expo-modules/).

## What the app still declares

A phone lets an app use the camera only if the app says why. That text is the
app's own, so it goes in the app's settings.

With Expo, in `app.json`:

```json
{
  "expo": {
    "plugins": [
      ["expo-image-picker", {
        "cameraPermission": "Take a photo to share in the community.",
        "photosPermission": "Choose a photo to share in the community.",
        "microphonePermission": false
      }]
    ]
  }
}
```

Without it, add `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription`
to `ios/<app>/Info.plist`.

## What the call does

| Step | Done by |
|---|---|
| Ask the user for camera permission | This package |
| Open the camera or the gallery | This package |
| Take or pick the picture | The user |
| Upload it and wait until the server has finished it | This package |
| Return the image, ready to attach | This package |

The gallery needs no permission: the phone's own picker runs outside the app
and hands back the one picture the user chose.

## Options

| Option | Default | Meaning |
|---|---|---|
| `source` | required | `"camera"` or `"gallery"` |
| `client` | `Community.instance` | The client to upload with |
| `signal` | none | Cancels the upload. It cannot close the camera |

## What it returns, and what it throws

It resolves with the `Media` an upload returns (`id`, `url`, `small_url` and
the sizes), or with `null` when the user backs out.

| Error | When |
|---|---|
| `CapturePermissionError` | The user refused the camera. `canAskAgain` is false when the phone will not ask again: send the user to the phone's Settings |
| `CaptureUnavailableError` | The camera or gallery could not be opened, such as a simulator with no camera. `cause` has the reason |
| `ValidationError` | `source` is neither `"camera"` nor `"gallery"`, or the file is over the upload limit |
| Every error `media.upload` throws | The upload itself failed |

Both capture errors extend the SDK's `CommunityClientError`.

```ts
import { captureImage, CapturePermissionError } from "@trackcore/community-react-native-capture";
import { Linking } from "react-native";

try {
  const image = await captureImage({ source: "camera" });
} catch (error) {
  if (error instanceof CapturePermissionError && !error.canAskAgain) Linking.openSettings();
  else throw error;
}
```

## An app with another picker

An app that does not use Expo's picker passes its own, and imports from
`/core`, which never loads `expo-image-picker`:

```ts
import { createCapture, CapturePermissionError } from "@trackcore/community-react-native-capture/core";
import { launchCamera, launchImageLibrary } from "react-native-image-picker";

export const captureImage = createCapture({
  async pick(source) {
    const open = source === "camera" ? launchCamera : launchImageLibrary;
    const result = await open({ mediaType: "photo" });
    if (result.errorCode === "permission") throw new CapturePermissionError(source, false);
    if (result.didCancel || !result.assets?.[0]?.uri) return null;
    return { uri: result.assets[0].uri, type: result.assets[0].type ?? null };
  },
});
```

## Files and voice notes

For the coaching chat, two more entries pick a file and record a voice note, and upload the result. Each names its own Expo library, so install only what the app offers: `npx expo install expo-document-picker expo-av`.

```ts
import { pickFile } from "@trackcore/community-react-native-capture/files";
import { VoiceRecorder } from "@trackcore/community-react-native-capture/voice";

const file = await pickFile();                       // null when the user backs out
if (file) await community.coachChat.send({ fileIds: [file.id] });

const recorder = new VoiceRecorder();
await recorder.start();                              // asks for the microphone the first time
const note = await recorder.stop();                  // uploads it; cancel() throws it away
if (note) await community.coachChat.send({ fileIds: [note.id] });
```

A member may send these only when the creator allows it: check `coach_chat_files_enabled` and `coach_chat_voice_enabled` in the settings first.

## Developing

Build the two packages it depends on first (`npm pack` in `../typescript`,
then in `../react-native`).

```sh
npm install
npm test
```

The tests run under Node with a stand-in picker. The package has not yet been
run on a device.
