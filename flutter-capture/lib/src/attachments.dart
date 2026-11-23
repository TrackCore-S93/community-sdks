/// Picking a document and recording a voice note for the coaching chat,
/// without a picker or a recorder of their own, and what they throw.
library;

import 'dart:typed_data';

import 'package:trackcore_community/trackcore_community.dart';

/// The user has refused the microphone. The phone may not ask again: send the
/// user to the phone's Settings.
final class MicrophonePermissionException implements Exception {
  const MicrophonePermissionException();

  String get message =>
      'The user has not allowed this app to use the microphone.';

  @override
  String toString() => 'MicrophonePermissionException: $message';
}

/// The file picker or the recorder could not be used, or gave back nothing
/// usable: a file of a type the chat does not take, an empty recording.
final class AttachmentUnavailableException implements Exception {
  const AttachmentUnavailableException(this.message, {this.cause});

  final String message;

  /// What the phone reported, when it reported anything.
  final Object? cause;

  @override
  String toString() => 'AttachmentUnavailableException: $message';
}

/// The endings a document may have, and the type each stands for: the same
/// list the server accepts.
const Map<String, String> documentTypes = {
  'pdf': 'application/pdf',
  'doc': 'application/msword',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'ppt': 'application/vnd.ms-powerpoint',
  'pptx':
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'rtf': 'application/rtf',
  'txt': 'text/plain',
  'csv': 'text/csv',
};

/// The type a document's name stands for, or `null` when the chat does not
/// take that kind of file.
String? documentTypeOf(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return null;
  return documentTypes[name.substring(dot + 1).toLowerCase()];
}

/// A document as the picker hands it over.
typedef PickedFile = ({Uint8List bytes, String name});

/// Opens the phone's file picker. Returns `null` when the user backs out.
typedef PickDocument = Future<PickedFile?> Function();

/// Sends a voice note or a document and returns it once it is ready.
typedef UploadFile = Future<CoachFile> Function(
  Uint8List bytes, {
  required CoachFileKind kind,
  required String fileName,
  required String contentType,
  int? durationMs,
});

/// Picks with [pick], then uploads with [upload]. `pickFile` is this, bound
/// to the phone's picker and a client.
Future<CoachFile?> pickFileWith({
  required PickDocument pick,
  required UploadFile upload,
}) async {
  final PickedFile? picked;
  try {
    picked = await pick();
  } on AttachmentUnavailableException {
    rethrow;
  } catch (error) {
    throw AttachmentUnavailableException('The file picker could not be opened.',
        cause: error);
  }
  if (picked == null) return null;
  final contentType = documentTypeOf(picked.name);
  if (contentType == null) {
    throw const AttachmentUnavailableException(
        'This kind of file cannot be sent. Choose a PDF, Word, Excel, PowerPoint, RTF, text or CSV file.');
  }
  if (picked.bytes.isEmpty) {
    throw const AttachmentUnavailableException('The file is empty.');
  }
  return upload(picked.bytes,
      kind: CoachFileKind.file,
      fileName: picked.name,
      contentType: contentType);
}

/// What a recording is once it is stopped.
typedef Recording = ({Uint8List bytes, String fileName, String contentType});

/// The phone's microphone, as much of it as a voice note needs.
abstract interface class RecorderDevice {
  /// Asks for the microphone if it has not been asked yet, and says whether
  /// the app may use it.
  Future<bool> allowed();

  /// Starts recording.
  Future<void> start();

  /// Stops and returns what was recorded, or `null` when there is nothing.
  Future<Recording?> stop();

  /// Stops and throws the recording away.
  Future<void> discard();
}

/// Records one voice note at a time and uploads it.
///
/// ```dart
/// final recorder = VoiceRecorder();
/// await recorder.start();            // asks for the microphone the first time
/// final note = await recorder.stop();   // uploads; null when nothing was recorded
/// if (note != null) await community.coachChat.send(fileIds: [note.id]);
/// ```
///
/// `VoiceRecorder()` is this, bound to the phone's microphone and a client.
final class VoiceRecorderCore {
  VoiceRecorderCore(
      {required RecorderDevice device,
      required UploadFile upload,
      DateTime Function()? now})
      : _device = device,
        _upload = upload,
        _now = now ?? DateTime.now;

  final RecorderDevice _device;
  final UploadFile _upload;
  final DateTime Function() _now;
  DateTime? _startedAt;

  /// Whether a recording is in progress.
  bool get isRecording => _startedAt != null;

  /// How long the recording in progress has run. Zero when there is none.
  Duration get elapsed =>
      _startedAt == null ? Duration.zero : _now().difference(_startedAt!);

  /// Starts recording. Asks the user for the microphone the first time.
  ///
  /// Throws [MicrophonePermissionException] when the user has refused it and
  /// [AttachmentUnavailableException] when the microphone could not be used.
  /// Calling it while already recording does nothing.
  Future<void> start() async {
    if (isRecording) return;
    final bool allowed;
    try {
      allowed = await _device.allowed();
    } catch (error) {
      throw AttachmentUnavailableException('The microphone could not be used.',
          cause: error);
    }
    if (!allowed) throw const MicrophonePermissionException();
    try {
      await _device.start();
    } catch (error) {
      throw AttachmentUnavailableException(
          'The recording could not be started.',
          cause: error);
    }
    _startedAt = _now();
  }

  /// Stops, uploads the voice note and returns it: its `id` goes in
  /// `fileIds` when sending a message.
  ///
  /// Returns `null` when nothing was being recorded or nothing was captured.
  /// Throws whatever the upload throws; the recording is gone either way.
  Future<CoachFile?> stop() async {
    final startedAt = _startedAt;
    if (startedAt == null) return null;
    final length = _now().difference(startedAt);
    _startedAt = null;
    final Recording? recording;
    try {
      recording = await _device.stop();
    } catch (error) {
      throw AttachmentUnavailableException('The recording could not be saved.',
          cause: error);
    }
    if (recording == null || recording.bytes.isEmpty) return null;
    return _upload(recording.bytes,
        kind: CoachFileKind.voice,
        fileName: recording.fileName,
        contentType: recording.contentType,
        durationMs: length.inMilliseconds);
  }

  /// Stops and throws the recording away. Nothing is uploaded.
  Future<void> cancel() async {
    if (_startedAt == null) return;
    _startedAt = null;
    try {
      await _device.discard();
    } catch (_) {
      // Nothing to keep either way.
    }
  }
}
