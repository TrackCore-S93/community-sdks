# trackcore_community_capture

Opens the camera or the gallery and uploads the picture to Community, in one
call. An add-on to [`trackcore_community`](../flutter): the app writes no
picker code and never handles the file.

```dart
import 'package:trackcore_community_capture/trackcore_community_capture.dart';

final image = await captureImage(source: CaptureSource.camera);   // or CaptureSource.gallery
if (image == null) return;                                        // the user backed out
await Community.instance.posts.create(topicId: topicId, body: body, mediaIds: [image.id]);
```

Documentation: https://community.trackcore.app/developer/sdk/flutter/media

## Install

The package is not on pub.dev. Add it from git, beside the SDK:

```yaml
dependencies:
  trackcore_community:
    git:
      url: https://github.com/TrackCore-S93/community-sdks.git
      ref: flutter-v0.1.2
      path: flutter
  trackcore_community_capture:
    git:
      url: https://github.com/TrackCore-S93/community-sdks.git
      ref: flutter-capture-v0.1.2
      path: flutter-capture
```

It needs Flutter, because opening the camera needs the phone. The SDK itself
stays pure Dart.

## What the app still declares

A phone lets an app use the camera only if the app says why. That text is the
app's own, so it goes in the app's settings.

iOS, in `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Take a photo to share in the community.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Choose a photo to share in the community.</string>
```

Android needs nothing.

## What the call does

| Step | Done by |
|---|---|
| Ask the user for camera permission | This package |
| Open the camera or the gallery | This package |
| Take or pick the picture | The user |
| Upload it and wait until the server has finished it | This package |
| Return the image, ready to attach | This package |

## Arguments

| Argument | Default | Meaning |
|---|---|---|
| `source` | required | `CaptureSource.camera` or `CaptureSource.gallery` |
| `client` | `Community.instance` | The client to upload with |

## What it returns, and what it throws

It returns the `Media` an upload returns (`id`, `url`, `smallUrl` and the
sizes), or `null` when the user backs out.

| Exception | When |
|---|---|
| `CapturePermissionException` | The user, or a restriction on the phone, refused the camera or the photo library. Send the user to the phone's Settings |
| `CaptureUnavailableException` | The camera or gallery could not be opened, such as a simulator with no camera. `cause` has what the phone reported |
| Every exception `media.upload` throws | The upload itself failed |

```dart
try {
  final image = await captureImage(source: CaptureSource.camera);
} on CapturePermissionException {
  // Show "Turn on camera access in Settings".
}
```

## Files and voice notes

For the coaching chat, the add-on also picks a file and records a voice note, and uploads the result.

```dart
final file = await pickFile();                       // null when the user backs out
if (file != null) await community.coachChat.send(fileIds: [file.id]);

final recorder = VoiceRecorder();
await recorder.start();                              // asks for the microphone the first time
final note = await recorder.stop();                  // uploads it; cancel() throws it away
if (note != null) await community.coachChat.send(fileIds: [note.id]);
```

A member may send these only when the creator allows it: check `coachChatFilesEnabled` and `coachChatVoiceEnabled` in the settings first. Recording needs `NSMicrophoneUsageDescription` in Info.plist and `RECORD_AUDIO` in the Android manifest. The add-on needs iOS 14 or later.

## Developing

Inside this repository the package builds against the SDK in `../flutter`
(see `pubspec_overrides.yaml`).

```sh
flutter pub get
flutter analyze
flutter test
```
