/// The capture call without a picker of its own, and what it throws.
library;

import 'dart:typed_data';

import 'package:trackcore_community/trackcore_community.dart';

/// Where the picture comes from.
enum CaptureSource {
  /// Takes a new picture.
  camera,

  /// Picks one the user already has.
  gallery,
}

/// The user has refused access to the camera or the photo library. The phone
/// may not ask again: send the user to the phone's Settings.
final class CapturePermissionException implements Exception {
  const CapturePermissionException(this.source);

  /// What was refused.
  final CaptureSource source;

  String get message => source == CaptureSource.camera
      ? 'The user has not allowed this app to use the camera.'
      : 'The user has not allowed this app to read the photo library.';

  @override
  String toString() => 'CapturePermissionException: $message';
}

/// The camera or the gallery could not be opened, or gave back nothing
/// usable: a simulator with no camera, for one.
final class CaptureUnavailableException implements Exception {
  const CaptureUnavailableException(this.source, this.message, {this.cause});

  final CaptureSource source;
  final String message;

  /// What the phone reported, when it reported anything.
  final Object? cause;

  @override
  String toString() => 'CaptureUnavailableException: $message';
}

/// A picture as the picker hands it over.
typedef PickedImage = ({Uint8List bytes, String contentType});

/// Opens the camera or the gallery. Returns `null` when the user backs out.
typedef PickImage = Future<PickedImage?> Function(CaptureSource source);

/// Sends the picture and returns it once the server has finished it.
typedef UploadImage = Future<Media> Function(
    Uint8List bytes, String contentType);

/// Picks with [pick], then uploads with [upload]. `captureImage` is this,
/// bound to the phone's picker and a client.
Future<Media?> captureImageWith({
  required CaptureSource source,
  required PickImage pick,
  required UploadImage upload,
}) async {
  final PickedImage? picked;
  try {
    picked = await pick(source);
  } on CapturePermissionException {
    rethrow;
  } on CaptureUnavailableException {
    rethrow;
  } catch (error) {
    throw CaptureUnavailableException(
      source,
      source == CaptureSource.camera
          ? 'The camera could not be opened.'
          : 'The gallery could not be opened.',
      cause: error,
    );
  }
  if (picked == null) return null;
  if (picked.bytes.isEmpty) {
    throw CaptureUnavailableException(source, 'The picker returned no file.');
  }
  return upload(picked.bytes, picked.contentType);
}
