/// The part of a WebSocket the SDK uses.
abstract interface class LiveSocket {
  /// Each text message the server sends. Closes when the connection does.
  Stream<String> get messages;

  /// Sends a text message.
  void send(String text);

  /// Closes the connection.
  Future<void> close();
}

/// Opens a WebSocket to [uri] with the given request headers.
typedef LiveSocketConnector = Future<LiveSocket> Function(
    Uri uri, Map<String, String> headers);
