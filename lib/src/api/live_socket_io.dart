import 'dart:io';

import 'live_socket_types.dart';

/// The WebSocket for phones, desktops and servers, on `dart:io`.
Future<LiveSocket> connectLiveSocket(
        Uri uri, Map<String, String> headers) async =>
    _IoSocket(await WebSocket.connect(uri.toString(), headers: headers));

final class _IoSocket implements LiveSocket {
  _IoSocket(this._socket);
  final WebSocket _socket;

  @override
  Stream<String> get messages =>
      _socket.where((message) => message is String).cast<String>();

  @override
  void send(String text) => _socket.add(text);

  @override
  Future<void> close() =>
      _socket.close(WebSocketStatus.normalClosure, 'closed by the app');
}
