/// Live updates: a connection that receives each change as it happens.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../errors/exceptions.dart';
import '../generated/models.dart';
import '../http/transport.dart';
import 'live_socket.dart';
import 'live_socket_types.dart';

/// Where a live connection is in its life.
enum LiveStatus { connecting, open, reconnecting, closed }

/// An open live connection. It only listens; posting, reacting and
/// commenting use their own calls. A dropped connection is reopened with
/// backoff. After a reconnect, read the feed since your newest post to catch
/// up on what was missed.
final class LiveConnection {
  LiveConnection._(this._transport, this._connect, String? topicId)
      : _topic = topicId ?? '' {
    _setStatus(LiveStatus.connecting);
    unawaited(_dial());
  }

  static const Duration _firstRetry = Duration(seconds: 1);
  static const Duration _longestRetry = Duration(seconds: 30);

  final Transport _transport;
  final LiveSocketConnector _connect;
  final StreamController<LiveEvent> _events =
      StreamController<LiveEvent>.broadcast();
  final StreamController<LiveStatus> _statuses =
      StreamController<LiveStatus>.broadcast();
  final StreamController<Object> _errors = StreamController<Object>.broadcast();
  final Random _random = Random();

  LiveSocket? _socket;
  StreamSubscription<String>? _subscription;
  Timer? _timer;
  String _topic;
  int _attempt = 0;
  bool _closed = false;
  LiveStatus _status = LiveStatus.connecting;

  /// Each change, as it happens.
  Stream<LiveEvent> get events => _events.stream;

  /// Each change of [status].
  Stream<LiveStatus> get statuses => _statuses.stream;

  /// Each failed attempt. The connection keeps retrying.
  Stream<Object> get errors => _errors.stream;

  /// Where the connection is now.
  LiveStatus get status => _status;

  void _setStatus(LiveStatus next) {
    _status = next;
    _transport.emit(LiveDiagnostic(next.name, _attempt));
    if (!_statuses.isClosed) _statuses.add(next);
  }

  /// Follows one topic, or every topic when called with nothing.
  void watch([String? topicId]) {
    _topic = topicId ?? '';
    if (_status == LiveStatus.open) {
      _socket?.send(jsonEncode({'type': 'watch', 'topic_id': _topic}));
    }
  }

  Future<void> _dial() async {
    if (_closed) return;
    try {
      final headers = await _transport.liveHeaders();
      if (_closed) return;
      final base = _transport.baseUrl;
      final uri = base.replace(
        scheme: base.isScheme('https') ? 'wss' : 'ws',
        path: '${base.path}/v1/live',
        queryParameters: _topic.isEmpty ? null : {'topic_id': _topic},
      );
      final socket = await _connect(uri, headers);
      if (_closed) {
        unawaited(socket.close());
        return;
      }
      _socket = socket;
      _subscription = socket.messages.listen(_onMessage,
          onError: _onError, onDone: _onDone, cancelOnError: false);
    } on CommunityConfigurationException catch (error) {
      // A client that cannot connect at all (no user, no WebSocket) stops.
      if (!_errors.isClosed) _errors.add(error);
      await close();
    } catch (error) {
      if (!_errors.isClosed) _errors.add(error);
      _retry();
    }
  }

  void _onMessage(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      return;
    }
    if (decoded is! Map) return;
    final type = decoded['type'];
    if (type == 'ready') {
      _attempt = 0;
      _setStatus(LiveStatus.open);
      return;
    }
    // Anything else with a type is an event. A coaching-chat event has no
    // post, so the post's id is not what makes one.
    if (type == 'watching' || type is! String) return;
    if (!_events.isClosed) {
      _events.add(LiveEvent.fromJson(decoded.cast<String, Object?>()));
    }
  }

  void _onError(Object error) {
    if (!_errors.isClosed) _errors.add(error);
  }

  void _onDone() {
    _socket = null;
    _subscription = null;
    _retry();
  }

  void _retry() {
    if (_closed || _timer != null) return;
    _attempt++;
    final ceiling = min(_longestRetry.inMilliseconds,
        _firstRetry.inMilliseconds * pow(2, _attempt - 1).toInt());
    _setStatus(LiveStatus.reconnecting);
    _timer = Timer(
        Duration(
            milliseconds: ceiling ~/ 2 + _random.nextInt(ceiling ~/ 2 + 1)),
        () {
      _timer = null;
      unawaited(_dial());
    });
  }

  /// Stops listening and stops reconnecting.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    _timer = null;
    await _subscription?.cancel();
    _subscription = null;
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      try {
        await socket.close();
      } catch (_) {
        // Already gone.
      }
    }
    _setStatus(LiveStatus.closed);
    await _events.close();
    await _statuses.close();
    await _errors.close();
  }
}

final class LiveApi {
  LiveApi(this._transport, [LiveSocketConnector? connector])
      : _connector = connector ?? connectLiveSocket;
  final Transport _transport;
  final LiveSocketConnector _connector;

  /// Opens the connection and keeps it open until `close()`. [topicId]
  /// follows one topic only.
  LiveConnection connect({String? topicId}) =>
      LiveConnection._(_transport, _connector, topicId);
}
