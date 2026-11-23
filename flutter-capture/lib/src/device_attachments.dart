/// The phone's file picker and microphone, through the file_picker and
/// record plugins.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'attachments.dart';

/// Opens the phone's file picker, showing only the kinds of document the chat
/// takes, and reads the one file the user chose.
Future<PickedFile?> pickDocumentFromDevice() async {
  final files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: documentTypes.keys.toList(growable: false),
  );
  if (files.isEmpty) return null;
  final file = files.first;
  return (bytes: await file.xFile.readAsBytes(), name: file.name);
}

/// The phone's microphone. Records AAC in an MPEG-4 file (`.m4a`), which
/// every phone and browser plays.
final class DeviceRecorder implements RecorderDevice {
  final AudioRecorder _recorder = AudioRecorder();
  String? _path;

  @override
  Future<bool> allowed() => _recorder.hasPermission();

  @override
  Future<void> start() async {
    final folder = await getTemporaryDirectory();
    final path =
        '${folder.path}/voice-${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path);
    _path = path;
  }

  @override
  Future<Recording?> stop() async {
    final path = await _recorder.stop() ?? _path;
    _path = null;
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    // The copy on the phone is not needed once it is read.
    await file.delete().catchError((_) => file);
    return (
      bytes: bytes,
      fileName: path.substring(path.lastIndexOf('/') + 1),
      contentType: 'audio/mp4',
    );
  }

  @override
  Future<void> discard() async {
    _path = null;
    await _recorder.cancel();
  }
}
