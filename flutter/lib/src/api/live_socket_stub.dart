import '../errors/exceptions.dart';
import 'live_socket_types.dart';

/// Where `dart:io` does not exist (the web), a WebSocket cannot send the
/// request headers the API needs.
Future<LiveSocket> connectLiveSocket(Uri uri, Map<String, String> headers) =>
    throw const CommunityConfigurationException(
        CommunityConfigurationReason.liveUnsupported,
        'Live updates are not available on this platform: its WebSocket cannot send the headers the API needs.');
