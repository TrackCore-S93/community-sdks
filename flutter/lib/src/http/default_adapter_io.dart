import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'http_adapter.dart';

/// The adapter for phones, desktops and servers, on `dart:io`.
CommunityHttpAdapter createDefaultAdapter() => _IoAdapter();

final class _IoAdapter implements CommunityHttpAdapter {
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10);

  @override
  Future<CommunityRawResponse> send(CommunityRawRequest request) async {
    try {
      return await _send(request).timeout(request.timeout);
    } on TimeoutException catch (error) {
      throw CommunityAdapterException(
          'No reply within ${request.timeout.inMilliseconds} ms.',
          kind: CommunityAdapterFailureKind.timeout,
          cause: error);
    } on SocketException catch (error) {
      throw CommunityAdapterException('The API could not be reached.',
          kind: CommunityAdapterFailureKind.connectFailed, cause: error);
    } on HandshakeException catch (error) {
      throw CommunityAdapterException('A secure connection could not be made.',
          kind: CommunityAdapterFailureKind.connectFailed, cause: error);
    } on HttpException catch (error) {
      throw CommunityAdapterException('The connection was lost.',
          kind: CommunityAdapterFailureKind.connectFailed, cause: error);
    } on CommunityAdapterException {
      rethrow;
    } catch (error) {
      throw CommunityAdapterException('The request failed.',
          kind: CommunityAdapterFailureKind.other, cause: error);
    }
  }

  Future<CommunityRawResponse> _send(CommunityRawRequest request) async {
    final outgoing = await _client.openUrl(request.method, request.uri);
    outgoing.followRedirects = false;
    request.headers.forEach(outgoing.headers.set);
    final body = request.body;
    if (body != null) {
      outgoing.contentLength = body.length;
      outgoing.add(body);
    }
    final incoming = await outgoing.close();
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in incoming) {
      bytes.add(chunk);
    }
    final headers = <String, String>{};
    incoming.headers.forEach(
        (name, values) => headers[name.toLowerCase()] = values.join(', '));
    return CommunityRawResponse(
        statusCode: incoming.statusCode,
        headers: headers,
        bodyBytes: bytes.takeBytes());
  }

  @override
  void close() => _client.close(force: true);
}
