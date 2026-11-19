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

import 'src/capture.dart';
import 'src/device_picker.dart';

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
