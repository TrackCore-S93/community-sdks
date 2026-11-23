import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:trackcore_community/trackcore_community.dart';
import 'package:trackcore_community_capture/src/attachments.dart';

const file = CoachFile(
    id: 'cm_att_1',
    kind: 'file',
    name: 'Food diary.pdf',
    contentType: 'application/pdf',
    bytes: 4,
    durationMs: null,
    url: null);

/// Records what was uploaded.
class Uploads {
  final sent = <({
    Uint8List bytes,
    CoachFileKind kind,
    String fileName,
    String contentType,
    int? durationMs
  })>[];
  Object? failure;

  Future<CoachFile> call(Uint8List bytes,
      {required CoachFileKind kind,
      required String fileName,
      required String contentType,
      int? durationMs}) async {
    sent.add((
      bytes: bytes,
      kind: kind,
      fileName: fileName,
      contentType: contentType,
      durationMs: durationMs
    ));
    if (failure != null) throw failure!;
    return file;
  }
}

/// Stands in for the phone's microphone.
class FakeMicrophone implements RecorderDevice {
  FakeMicrophone({this.permitted = true, this.recording, this.startError});
  bool permitted;
  Recording? recording;
  Object? startError;
  final calls = <String>[];

  @override
  Future<bool> allowed() async {
    calls.add('allowed');
    return permitted;
  }

  @override
  Future<void> start() async {
    calls.add('start');
    if (startError != null) throw startError!;
  }

  @override
  Future<Recording?> stop() async {
    calls.add('stop');
    return recording;
  }

  @override
  Future<void> discard() async => calls.add('discard');
}

final pdf = Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);
final sound = Uint8List.fromList([1, 2, 3]);

void main() {
  group('pickFileWith', () {
    test('uploads the chosen document as a file, with its type', () async {
      final uploads = Uploads();
      final got = await pickFileWith(
          pick: () async => (bytes: pdf, name: 'Food diary.PDF'),
          upload: uploads.call);
      expect(got, same(file));
      expect(uploads.sent.single.kind, CoachFileKind.file);
      expect(uploads.sent.single.fileName, 'Food diary.PDF');
      expect(uploads.sent.single.contentType, 'application/pdf');
      expect(uploads.sent.single.durationMs, isNull);
    });

    test('knows every kind of document the chat takes', () {
      expect(documentTypeOf('a.docx'), contains('wordprocessingml'));
      expect(documentTypeOf('a.xlsx'), contains('spreadsheetml'));
      expect(documentTypeOf('a.pptx'), contains('presentationml'));
      expect(documentTypeOf('notes.txt'), 'text/plain');
      expect(documentTypeOf('data.csv'), 'text/csv');
      expect(documentTypeOf('photo.jpg'), isNull);
      expect(documentTypeOf('noending'), isNull);
      expect(documentTypeOf('dot.'), isNull);
    });

    test('uploads nothing when the user backs out', () async {
      final uploads = Uploads();
      expect(await pickFileWith(pick: () async => null, upload: uploads.call),
          isNull);
      expect(uploads.sent, isEmpty);
    });

    test('refuses a file the chat does not take, and an empty one', () async {
      final uploads = Uploads();
      await expectLater(
          pickFileWith(
              pick: () async => (bytes: pdf, name: 'movie.mp4'),
              upload: uploads.call),
          throwsA(isA<AttachmentUnavailableException>()));
      await expectLater(
          pickFileWith(
              pick: () async => (bytes: Uint8List(0), name: 'a.pdf'),
              upload: uploads.call),
          throwsA(isA<AttachmentUnavailableException>()));
      expect(uploads.sent, isEmpty);
    });

    test('a picker that fails is reported with its cause', () async {
      final cause = StateError('no picker');
      await expectLater(
          pickFileWith(pick: () async => throw cause, upload: Uploads().call),
          throwsA(isA<AttachmentUnavailableException>()
              .having((e) => e.cause, 'cause', same(cause))));
    });

    test('an upload that fails is passed on', () async {
      final uploads = Uploads()..failure = StateError('offline');
      await expectLater(
          pickFileWith(
              pick: () async => (bytes: pdf, name: 'a.pdf'),
              upload: uploads.call),
          throwsStateError);
    });
  });

  group('VoiceRecorderCore', () {
    test('records, then uploads a voice note with its length', () async {
      var now = DateTime(2026, 11, 23, 10);
      final microphone = FakeMicrophone(recording: (
        bytes: sound,
        fileName: 'voice-1.m4a',
        contentType: 'audio/mp4'
      ));
      final uploads = Uploads();
      final recorder = VoiceRecorderCore(
          device: microphone, upload: uploads.call, now: () => now);

      expect(recorder.isRecording, isFalse);
      expect(recorder.elapsed, Duration.zero);
      await recorder.start();
      expect(recorder.isRecording, isTrue);
      now = now.add(const Duration(seconds: 9));
      expect(recorder.elapsed, const Duration(seconds: 9));
      // Starting again while recording does nothing.
      await recorder.start();

      final note = await recorder.stop();
      expect(note, same(file));
      expect(recorder.isRecording, isFalse);
      expect(microphone.calls, ['allowed', 'start', 'stop']);
      expect(uploads.sent.single.kind, CoachFileKind.voice);
      expect(uploads.sent.single.fileName, 'voice-1.m4a');
      expect(uploads.sent.single.contentType, 'audio/mp4');
      expect(uploads.sent.single.durationMs, 9000);
    });

    test('a refused microphone records nothing', () async {
      final microphone = FakeMicrophone(permitted: false);
      final recorder =
          VoiceRecorderCore(device: microphone, upload: Uploads().call);
      await expectLater(
          recorder.start(), throwsA(isA<MicrophonePermissionException>()));
      expect(recorder.isRecording, isFalse);
      expect(microphone.calls, ['allowed']);
      expect(await recorder.stop(), isNull);
    });

    test('a recorder that will not start is reported', () async {
      final recorder = VoiceRecorderCore(
          device: FakeMicrophone(startError: StateError('busy')),
          upload: Uploads().call);
      await expectLater(
          recorder.start(), throwsA(isA<AttachmentUnavailableException>()));
      expect(recorder.isRecording, isFalse);
    });

    test('cancel throws the recording away and uploads nothing', () async {
      final microphone = FakeMicrophone(recording: (
        bytes: sound,
        fileName: 'v.m4a',
        contentType: 'audio/mp4'
      ));
      final uploads = Uploads();
      final recorder =
          VoiceRecorderCore(device: microphone, upload: uploads.call);
      await recorder.start();
      await recorder.cancel();
      expect(recorder.isRecording, isFalse);
      expect(microphone.calls, ['allowed', 'start', 'discard']);
      expect(uploads.sent, isEmpty);
      // Nothing is left to stop.
      expect(await recorder.stop(), isNull);
    });

    test('stopping with nothing captured uploads nothing', () async {
      final uploads = Uploads();
      final recorder = VoiceRecorderCore(
          device: FakeMicrophone(recording: null), upload: uploads.call);
      await recorder.start();
      expect(await recorder.stop(), isNull);
      expect(uploads.sent, isEmpty);
    });

    test('an upload that fails is passed on, and the recorder is free again',
        () async {
      final uploads = Uploads()..failure = StateError('offline');
      final recorder = VoiceRecorderCore(
          device: FakeMicrophone(recording: (
            bytes: sound,
            fileName: 'v.m4a',
            contentType: 'audio/mp4'
          )),
          upload: uploads.call);
      await recorder.start();
      await expectLater(recorder.stop(), throwsStateError);
      expect(recorder.isRecording, isFalse);
    });
  });
}
