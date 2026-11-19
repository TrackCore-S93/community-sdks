import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:trackcore_community/trackcore_community.dart';
import 'package:trackcore_community_capture/src/capture.dart';
import 'package:trackcore_community_capture/src/device_picker.dart';
import 'package:trackcore_community_capture/trackcore_community_capture.dart'
    as capture;

const media = Media(id: 'cm_med_1', status: MediaStatus.ready, attached: false);
final jpeg = Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0]);

/// Records what was uploaded.
class Uploads {
  final sent = <({Uint8List bytes, String contentType})>[];
  Object? failure;

  Future<Media> call(Uint8List bytes, String contentType) async {
    sent.add((bytes: bytes, contentType: contentType));
    if (failure != null) throw failure!;
    return media;
  }
}

/// Stands in for the phone's picker.
class FakePicker extends ImagePickerPlatform with MockPlatformInterfaceMixin {
  FakePicker({this.file, this.error});
  final XFile? file;
  final PlatformException? error;
  final asked = <ImageSource>[];
  ImagePickerOptions? options;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    asked.add(source);
    this.options = options;
    if (error != null) throw error!;
    return file;
  }
}

void main() {
  group('captureImageWith', () {
    test('picks from the source asked for, uploads, and returns the image',
        () async {
      for (final source in CaptureSource.values) {
        final uploads = Uploads();
        final asked = <CaptureSource>[];
        final image = await captureImageWith(
          source: source,
          pick: (s) async {
            asked.add(s);
            return (bytes: jpeg, contentType: 'image/heic');
          },
          upload: uploads.call,
        );
        expect(asked, [source]);
        expect(uploads.sent.single.bytes, jpeg);
        expect(uploads.sent.single.contentType, 'image/heic');
        expect(image, same(media));
      }
    });

    test('backing out returns null and uploads nothing', () async {
      final uploads = Uploads();
      final image = await captureImageWith(
          source: CaptureSource.gallery,
          pick: (_) async => null,
          upload: uploads.call);
      expect(image, isNull);
      expect(uploads.sent, isEmpty);
    });

    test('a refused permission reaches the caller as it is', () async {
      final uploads = Uploads();
      await expectLater(
        captureImageWith(
            source: CaptureSource.camera,
            pick: (_) async =>
                throw const CapturePermissionException(CaptureSource.camera),
            upload: uploads.call),
        throwsA(isA<CapturePermissionException>()
            .having((e) => e.source, 'source', CaptureSource.camera)
            .having((e) => e.message, 'message', contains('camera'))),
      );
      expect(uploads.sent, isEmpty);
    });

    test('a picker that breaks is CaptureUnavailableException, cause kept',
        () async {
      final cause = StateError('no camera');
      await expectLater(
        captureImageWith(
            source: CaptureSource.camera,
            pick: (_) async => throw cause,
            upload: Uploads().call),
        throwsA(isA<CaptureUnavailableException>()
            .having((e) => e.cause, 'cause', same(cause))
            .having((e) => e.source, 'source', CaptureSource.camera)),
      );
    });

    test('an empty file is refused before the upload', () async {
      final uploads = Uploads();
      await expectLater(
        captureImageWith(
            source: CaptureSource.gallery,
            pick: (_) async => (bytes: Uint8List(0), contentType: 'image/jpeg'),
            upload: uploads.call),
        throwsA(isA<CaptureUnavailableException>()),
      );
      expect(uploads.sent, isEmpty);
    });

    test('an upload error reaches the caller unchanged', () async {
      const failure = CommunityValidationException('bytes', 'too large');
      final uploads = Uploads()..failure = failure;
      await expectLater(
        captureImageWith(
            source: CaptureSource.gallery,
            pick: (_) async => (bytes: jpeg, contentType: 'image/jpeg'),
            upload: uploads.call),
        throwsA(same(failure)),
      );
    });
  });

  group('the phone picker', () {
    test('opens the camera or the gallery, and asks for no extra metadata',
        () async {
      for (final (source, expected) in [
        (CaptureSource.camera, ImageSource.camera),
        (CaptureSource.gallery, ImageSource.gallery),
      ]) {
        final picker = FakePicker(
            file: XFile.fromData(jpeg, name: 'p.jpg', mimeType: 'image/jpeg'));
        ImagePickerPlatform.instance = picker;
        final picked = await pickFromDevice(source);
        expect(picker.asked, [expected]);
        expect(picker.options!.requestFullMetadata, isFalse);
        expect(picker.options!.maxWidth, isNull);
        expect(picker.options!.imageQuality, isNull);
        expect(picked!.bytes, jpeg);
        expect(picked.contentType, 'image/jpeg');
      }
    });

    test('backing out is null', () async {
      ImagePickerPlatform.instance = FakePicker();
      expect(await pickFromDevice(CaptureSource.gallery), isNull);
    });

    test('a refusal by the user or the phone is CapturePermissionException',
        () async {
      for (final code in [
        'camera_access_denied',
        'camera_access_restricted',
        'photo_access_denied',
        'photo_access_restricted',
      ]) {
        ImagePickerPlatform.instance =
            FakePicker(error: PlatformException(code: code));
        await expectLater(pickFromDevice(CaptureSource.camera),
            throwsA(isA<CapturePermissionException>()));
      }
    });

    test('any other failure is CaptureUnavailableException', () async {
      final error = PlatformException(code: 'no_available_camera');
      ImagePickerPlatform.instance = FakePicker(error: error);
      await expectLater(
          pickFromDevice(CaptureSource.camera),
          throwsA(isA<CaptureUnavailableException>()
              .having((e) => e.cause, 'cause', same(error))));
    });

    test('the type comes from the file name when the phone gives none', () {
      expect(contentTypeOf('IMG_0001.HEIC'), 'image/heic');
      expect(contentTypeOf('a.b.png'), 'image/png');
      expect(contentTypeOf('photo.jpeg'), 'image/jpeg');
      expect(contentTypeOf('noending'), 'image/jpeg');
      expect(contentTypeOf('clip.mov'), 'image/jpeg');
    });
  });

  test('captureImage fails before the picker when no client is configured',
      () async {
    final picker = FakePicker(
        file: XFile.fromData(jpeg, name: 'p.jpg', mimeType: 'image/jpeg'));
    ImagePickerPlatform.instance = picker;
    expect(() => capture.captureImage(source: CaptureSource.camera),
        throwsA(isA<CommunityConfigurationException>()));
    expect(picker.asked, isEmpty);
  });
}
