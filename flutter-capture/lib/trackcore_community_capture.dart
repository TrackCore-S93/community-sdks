/// Opens the camera or the gallery and uploads the picture to Community in
/// one call, so an app writes no picker code and never handles the file.
///
/// ```dart
/// final image = await captureImage(source: CaptureSource.camera);
/// if (image == null) return;   // the user backed out
/// await Community.instance.posts.create(topicId: topicId, body: body, mediaIds: [image.id]);
/// ```
library;

import 'package:trackcore_community/trackcore_community.dart';

import 'src/attachments.dart';
import 'src/capture.dart';
import 'src/device_attachments.dart';
import 'src/device_picker.dart';

export 'src/attachments.dart'
    show AttachmentUnavailableException, MicrophonePermissionException;
export 'src/capture.dart'
    show CapturePermissionException, CaptureSource, CaptureUnavailableException;

/// Opens the camera or the gallery, uploads the picture the user chose, and
/// returns it once the server has finished it: its `id` goes in `mediaIds`
/// on a post or comment, or in `updateProfile`.
///
/// Returns `null` when the user backs out. Nothing is uploaded then.
///
/// Uploads with [client], or with `Community.instance` when it is left out.
///
/// Throws [CapturePermissionException] when the user has refused the camera
/// or the photo library, [CaptureUnavailableException] when neither could be
/// opened, and whatever `media.upload` throws when the upload fails.
Future<Media?> captureImage({
  required CaptureSource source,
  CommunityClient? client,
}) {
  // Read the client before the picker opens, so a client that was never
  // configured fails now and not after the user has taken a picture.
  final media = (client ?? Community.instance.client).media;
  return captureImageWith(
    source: source,
    pick: pickFromDevice,
    upload: (bytes, contentType) =>
        media.upload(bytes, contentType: contentType),
  );
}

/// Opens the phone's file picker, uploads the document the user chose, and
/// returns it once it is ready: its `id` goes in `fileIds` when sending a
/// coaching-chat message.
///
/// The picker shows only what the chat takes: PDF, Word, Excel, PowerPoint,
/// RTF, text and CSV files. Returns `null` when the user backs out; nothing
/// is uploaded then.
///
/// Uploads with [client], or with `Community.instance` when it is left out.
/// A member may send files only when the creator allows it: check
/// `coachChatFilesEnabled` in the settings before offering this.
///
/// Throws [AttachmentUnavailableException] when the picker could not be
/// opened or the file cannot be sent, and whatever `coachChat.uploadFile`
/// throws when the upload fails.
Future<CoachFile?> pickFile({CommunityClient? client}) {
  // Read the client before the picker opens, so a client that was never
  // configured fails now and not after the user has chosen a file.
  final chat = (client ?? Community.instance.client).coachChat;
  return pickFileWith(pick: pickDocumentFromDevice, upload: chat.uploadFile);
}

/// Records a voice note with the phone's microphone and uploads it, for the
/// coaching chat.
///
/// ```dart
/// final recorder = VoiceRecorder();
/// await recorder.start();               // asks for the microphone the first time
/// final note = await recorder.stop();   // uploads it; null when nothing was recorded
/// if (note != null) await community.coachChat.send(fileIds: [note.id]);
/// ```
///
/// [cancel] throws the recording away instead. [elapsed] is how long it has
/// run, for a timer on screen.
///
/// A member may send voice notes only when the creator allows it: check
/// `coachChatVoiceEnabled` in the settings before offering this. The app
/// needs the microphone permission: `NSMicrophoneUsageDescription` in
/// Info.plist, `RECORD_AUDIO` in the Android manifest.
final class VoiceRecorder {
  /// Uploads with [client], or with `Community.instance` when it is left out.
  VoiceRecorder({CommunityClient? client})
      : _core = VoiceRecorderCore(
          device: DeviceRecorder(),
          upload: (client ?? Community.instance.client).coachChat.uploadFile,
        );

  final VoiceRecorderCore _core;

  /// Whether a recording is in progress.
  bool get isRecording => _core.isRecording;

  /// How long the recording in progress has run.
  Duration get elapsed => _core.elapsed;

  /// Starts recording. Throws [MicrophonePermissionException] when the user
  /// has refused the microphone.
  Future<void> start() => _core.start();

  /// Stops, uploads the voice note and returns it. `null` when nothing was
  /// recorded.
  Future<CoachFile?> stop() => _core.stop();

  /// Stops and throws the recording away.
  Future<void> cancel() => _core.cancel();
}
