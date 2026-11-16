/// The one seam between this SDK and the network. The default adapter uses
/// `dart:io`; pass your own to route requests through another client.
library;

import 'dart:typed_data';

/// One HTTP request, ready to send.
final class CommunityRawRequest {
  const CommunityRawRequest({
    required this.method,
    required this.uri,
    required this.headers,
    this.body,
    this.timeout = const Duration(seconds: 10),
  });

  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final Uint8List? body;

  /// The time allowed for this one attempt.
  final Duration timeout;
}

/// One HTTP reply. Header names are lower-case.
final class CommunityRawResponse {
  const CommunityRawResponse({
    required this.statusCode,
    required this.headers,
    required this.bodyBytes,
  });

  final int statusCode;
  final Map<String, String> headers;
  final Uint8List bodyBytes;
}

/// How an attempt failed before a reply arrived.
enum CommunityAdapterFailureKind { connectFailed, timeout, other }

/// Thrown by an adapter when no reply arrived.
final class CommunityAdapterException implements Exception {
  const CommunityAdapterException(this.message,
      {required this.kind, this.cause});

  final String message;
  final CommunityAdapterFailureKind kind;
  final Object? cause;

  @override
  String toString() => 'CommunityAdapterException(${kind.name}): $message';
}

/// Sends requests. Implement this to use another HTTP client.
abstract interface class CommunityHttpAdapter {
  /// Sends [request] and returns the reply, whatever its status. Throws
  /// [CommunityAdapterException] when no reply arrives.
  Future<CommunityRawResponse> send(CommunityRawRequest request);

  /// Releases the adapter's connections.
  void close();
}
