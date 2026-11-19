/// The phone's camera and gallery, through the image_picker plugin.
library;

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'capture.dart';

/// The codes image_picker reports when the user, or a restriction on the
/// phone, has refused access.
const _refused = {
  'camera_access_denied',
  'camera_access_restricted',
  'photo_access_denied',
  'photo_access_restricted',
};

const _types = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'heic': 'image/heic',
  'heif': 'image/heif',
  'webp': 'image/webp',
  'gif': 'image/gif',
};

/// Opens the camera or the gallery and reads the one picture the user chose.
///
/// The picture is taken as it is: the server turns it the right way up and
/// makes the sizes, so nothing is cropped or squeezed on the phone.
Future<PickedImage?> pickFromDevice(CaptureSource source) async {
  final XFile? file;
  try {
    file = await ImagePicker().pickImage(
      source: source == CaptureSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      // Without the full metadata the gallery needs no permission: the
      // phone's own picker hands back just the picture.
      requestFullMetadata: false,
    );
  } on PlatformException catch (error) {
    if (_refused.contains(error.code)) {
      throw CapturePermissionException(source);
    }
    throw CaptureUnavailableException(
      source,
      source == CaptureSource.camera
          ? 'The camera could not be opened.'
          : 'The gallery could not be opened.',
      cause: error,
    );
  }
  if (file == null) return null;
  return (
    bytes: await file.readAsBytes(),
    contentType: file.mimeType ?? contentTypeOf(file.name),
  );
}

/// The type a file name's ending stands for. JPEG when it says nothing: the
/// server reads the file itself and refuses anything that is not an image.
String contentTypeOf(String name) {
  final dot = name.lastIndexOf('.');
  final ending = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  return _types[ending] ?? 'image/jpeg';
}
