/// Image uploads, for posts, comments and profile pictures.
library;

import 'dart:typed_data';

import '../errors/exceptions.dart';
import '../generated/models.dart';
import '../http/transport.dart';

final class MediaApi {
  MediaApi(this._transport);
  final Transport _transport;

  Map<String, Object?> _object(Object? json) =>
      (json! as Map).cast<String, Object?>();

  /// Step 1 of 3: asks for a link to send a file to. [upload] does all three.
  Future<Upload> start() async => Upload.fromJson(_object(await _transport
      .request('POST', '/v1/media', audience: Audience.member)));

  /// Step 3 of 3: tells the server the file has arrived. It checks, resizes
  /// and stores the image.
  Future<Media> complete(String mediaId) async {
    if (mediaId.isEmpty) {
      throw const CommunityValidationException(
          'mediaId', 'mediaId is required.');
    }
    return Media.fromJson(_object(await _transport.request(
        'POST', '/v1/media/${Uri.encodeComponent(mediaId)}/complete',
        audience: Audience.member, repeatable: true)));
  }

  /// One of the user's uploads.
  Future<Media> get(String mediaId) async {
    if (mediaId.isEmpty) {
      throw const CommunityValidationException(
          'mediaId', 'mediaId is required.');
    }
    return Media.fromJson(_object(await _transport.request(
        'GET', '/v1/media/${Uri.encodeComponent(mediaId)}',
        audience: Audience.member)));
  }

  /// Uploads one image: asks for a link, sends the bytes to it, and finishes
  /// the upload. The returned image's `id` goes in a post's or comment's
  /// `mediaIds`, or in `updateProfile`.
  Future<Media> upload(Uint8List bytes,
          {String contentType = 'application/octet-stream'}) =>
      sendUpload(_transport, bytes, contentType, start, complete);
}

/// The three steps of an upload, shared by every kind of image: ask for a
/// link, send the bytes to it, and finish.
Future<Media> sendUpload(
    Transport transport,
    Uint8List bytes,
    String contentType,
    Future<Upload> Function() start,
    Future<Media> Function(String mediaId) complete) async {
  if (bytes.isEmpty) {
    throw const CommunityValidationException('bytes', 'The file is empty.');
  }
  final started = await start();
  if (bytes.length > started.maxBytes) {
    throw CommunityValidationException('bytes',
        'The file is larger than the upload limit of ${started.maxBytes} bytes.');
  }
  final response = await transport.sendTo(
      Uri.parse(started.upload.url), started.upload.method, bytes, contentType);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw CommunityTransportException(
        'Storage refused the file (HTTP ${response.statusCode}).',
        kind: CommunityTransportFailure.other,
        attempts: 1);
  }
  return complete(started.id);
}
