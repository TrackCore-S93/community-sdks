/// The entry point: configure once, sign a user in, call a method.
library;

import 'api/apis.dart';
import 'api/coach_chat_api.dart';
import 'api/live_api.dart';
import 'api/live_socket_types.dart';
import 'api/media_api.dart';
import 'api/reactions_api.dart';
import 'errors/exceptions.dart';
import 'generated/models.dart';
import 'http/default_adapter.dart';
import 'http/http_adapter.dart';
import 'http/retry_policy.dart';
import 'http/transport.dart';

/// A Community client you hold yourself. [Community.instance] is one for the
/// whole app.
final class CommunityClient {
  CommunityClient._(this._transport, LiveSocketConnector? liveSocket)
      : auth = AuthApi(_transport),
        users = UsersApi(_transport),
        community = CommunityApi(_transport),
        members = MembersApi(_transport),
        topics = TopicsApi(_transport),
        posts = PostsApi(_transport),
        comments = CommentsApi(_transport),
        reactions = ReactionsApi(_transport),
        media = MediaApi(_transport),
        blocks = BlocksApi(_transport),
        reports = ReportsApi(_transport),
        archive = ArchiveApi(_transport),
        notifications = NotificationsApi(_transport),
        coachChat = CoachChatApi(_transport),
        push = PushApi(_transport),
        settings = SettingsApi(_transport),
        live = LiveApi(_transport, liveSocket);

  /// A client for an app, with a publishable key. A secret key is refused.
  factory CommunityClient.publishable({
    required String apiKey,
    String baseUrl = communityDefaultBaseUrl,
    int sessionTtlSeconds = 86400,
    Duration timeout = const Duration(seconds: 10),
    CommunityRetryPolicy? retryPolicy,
    CommunityHttpAdapter? httpAdapter,
    Map<String, String> headers = const {},
    void Function(CommunityDiagnostic)? onDiagnostic,
    LiveSocketConnector? liveSocket,
  }) {
    if (apiKey.startsWith('cm_sk_')) {
      throw const CommunityConfigurationException(
        CommunityConfigurationReason.secretKeyInApp,
        'A Community secret key was given to a client for an app. Anything shipped in an app is readable by '
        'whoever holds the app, so this key must be treated as compromised: revoke it and issue a new one. '
        'Use a publishable key (cm_pk_…) here.',
      );
    }
    return _build(apiKey, baseUrl, sessionTtlSeconds, timeout, retryPolicy,
        httpAdapter, headers, onDiagnostic, liveSocket);
  }

  /// A client for a server, with a secret key. Never use this in an app: a
  /// key in an app binary can be read by anyone who has the app.
  factory CommunityClient.serverSideSecret({
    required String apiKey,
    String baseUrl = communityDefaultBaseUrl,
    Duration timeout = const Duration(seconds: 10),
    CommunityRetryPolicy? retryPolicy,
    CommunityHttpAdapter? httpAdapter,
    Map<String, String> headers = const {},
    void Function(CommunityDiagnostic)? onDiagnostic,
    LiveSocketConnector? liveSocket,
  }) {
    if (!apiKey.startsWith('cm_sk_')) {
      throw const CommunityConfigurationException(
          CommunityConfigurationReason.apiKeyMalformed,
          'serverSideSecret needs a secret key (cm_sk_…).');
    }
    return _build(apiKey, baseUrl, 86400, timeout, retryPolicy, httpAdapter,
        headers, onDiagnostic, liveSocket);
  }

  static CommunityClient _build(
    String apiKey,
    String baseUrl,
    int sessionTtlSeconds,
    Duration timeout,
    CommunityRetryPolicy? retryPolicy,
    CommunityHttpAdapter? httpAdapter,
    Map<String, String> headers,
    void Function(CommunityDiagnostic)? onDiagnostic,
    LiveSocketConnector? liveSocket,
  ) {
    if (apiKey.isEmpty) {
      throw const CommunityConfigurationException(
          CommunityConfigurationReason.apiKeyMissing, 'No API key.');
    }
    if (timeout <= Duration.zero) {
      throw const CommunityConfigurationException(
          CommunityConfigurationReason.optionInvalid,
          'timeout must be positive.');
    }
    final transport = Transport(
      apiKey: apiKey,
      baseUrl: baseUrl,
      adapter: httpAdapter ?? createDefaultAdapter(),
      retryPolicy: retryPolicy ?? CommunityRetryPolicy(),
      timeout: timeout,
      sessionTtlSeconds: sessionTtlSeconds,
      headers: headers,
      onDiagnostic: onDiagnostic,
    );
    return CommunityClient._(transport, liveSocket);
  }

  final Transport _transport;

  /// Sessions.
  final AuthApi auth;

  /// Erasing end users. Secret key only.
  final UsersApi users;

  /// Joining the community, and profiles.
  final CommunityApi community;

  /// The creator's member list and roles. Secret key only.
  final MembersApi members;

  /// Topics.
  final TopicsApi topics;

  /// Posts, the feed and search.
  final PostsApi posts;

  /// Comments and replies.
  final CommentsApi comments;

  /// Emoji reactions.
  final ReactionsApi reactions;

  /// Image uploads.
  final MediaApi media;

  /// Blocking members.
  final BlocksApi blocks;

  /// Reports.
  final ReportsApi reports;

  /// The moderation archive: what reports removed. Secret key only.
  final ArchiveApi archive;

  /// Notifications.
  final NotificationsApi notifications;

  /// The coaching chat: a member's one-to-one chat with their coach.
  final CoachChatApi coachChat;

  /// Push notifications to the phone.
  final PushApi push;

  /// The creator's settings.
  final SettingsApi settings;

  /// Live updates.
  final LiveApi live;

  /// Signs a user in, after your own sign-in. With a publishable key this
  /// mints a session for them and renews it when it nears its end. With a
  /// secret key it names the user and makes no network call.
  Future<void> initialize(String externalId) =>
      _transport.initialize(externalId);

  /// Signs the user out: unregisters the phone from push, ends the session
  /// where there is one, and forgets the user.
  Future<void> signOut() async {
    // A phone registered for push must stop getting this user's
    // notifications. A failure here must not keep the user signed in.
    if (push.registeredToken != null) {
      try {
        await push.unregister();
      } on Object {
        // The server forgets the token when the next user registers it.
      }
    }
    await _transport.signOut();
  }

  /// Names the user every later request acts for. For a server.
  void setUser(String externalId) => _transport.setUser(externalId);

  /// Stops naming a user.
  void clearUser() => _transport.clearUser();

  /// Carries a session token your backend minted for this user.
  void setSession(String sessionToken) => _transport.setSession(sessionToken);

  /// Forgets the session token.
  void clearSession() => _transport.clearSession();

  /// The user requests act for, or null.
  String? get externalId => _transport.externalId;

  /// The session token in use, or null.
  String? get sessionToken => _transport.sessionToken;

  /// `live` or `test`, from the key.
  CommunityEnvironment get environment => _transport.environment;

  /// `secret` or `publishable`, from the key.
  CommunityKeyKind get keyKind => _transport.keyKind;

  /// Where the API answers.
  Uri get baseUrl => _transport.baseUrl;

  /// The key, masked: safe to log.
  String describeCredential() => _transport.describeCredential();

  /// Which customer and environment the key belongs to.
  Future<WhoAmI> whoAmI() async => WhoAmI.fromJson(((await _transport
          .request('GET', '/v1/me', audience: Audience.anyKey))! as Map)
      .cast<String, Object?>());

  /// The user a call acts for, as the server sees it.
  Future<EndUser> currentUser() async => EndUser.fromJson(((await _transport
          .request('GET', '/v1/users/me', audience: Audience.member))! as Map)
      .cast<String, Object?>());

  /// Releases the client's connections.
  void close() => _transport.close();

  @override
  String toString() =>
      'CommunityClient(${describeCredential()}, ${environment.name}, $baseUrl)';
}

/// The shared client: configure it once when the app starts, then use it
/// anywhere.
final class Community {
  Community._();

  /// The shared client.
  static final Community instance = Community._();

  CommunityClient? _client;

  /// Sets the key and the options. Call once, when the app starts. A secret
  /// key is refused unless [iUnderstandThisKeyMustNeverShipInAnAppBinary] is
  /// true, which is for a Dart server only.
  Future<void> configure({
    required String apiKey,
    String baseUrl = communityDefaultBaseUrl,
    int sessionTtlSeconds = 86400,
    Duration timeout = const Duration(seconds: 10),
    CommunityRetryPolicy? retryPolicy,
    CommunityHttpAdapter? httpAdapter,
    Map<String, String> headers = const {},
    void Function(CommunityDiagnostic)? onDiagnostic,
    LiveSocketConnector? liveSocket,
    bool iUnderstandThisKeyMustNeverShipInAnAppBinary = false,
  }) async {
    _client?.close();
    _client = null;
    if (apiKey.startsWith('cm_sk_') &&
        iUnderstandThisKeyMustNeverShipInAnAppBinary) {
      _client = CommunityClient.serverSideSecret(
        apiKey: apiKey,
        baseUrl: baseUrl,
        timeout: timeout,
        retryPolicy: retryPolicy,
        httpAdapter: httpAdapter,
        headers: headers,
        onDiagnostic: onDiagnostic,
        liveSocket: liveSocket,
      );
      return;
    }
    _client = CommunityClient.publishable(
      apiKey: apiKey,
      baseUrl: baseUrl,
      sessionTtlSeconds: sessionTtlSeconds,
      timeout: timeout,
      retryPolicy: retryPolicy,
      httpAdapter: httpAdapter,
      headers: headers,
      onDiagnostic: onDiagnostic,
      liveSocket: liveSocket,
    );
  }

  /// The configured client.
  CommunityClient get client {
    final client = _client;
    if (client == null) {
      throw const CommunityConfigurationException(
          CommunityConfigurationReason.notConfigured,
          'The client is not configured. Call configure(apiKey: …) first.');
    }
    return client;
  }

  /// Signs a user in, after your own sign-in.
  Future<void> initialize(String externalId) => client.initialize(externalId);

  /// Signs the user out.
  Future<void> signOut() => client.signOut();

  /// Carries a session token your backend minted for this user.
  void setSession(String sessionToken) => client.setSession(sessionToken);

  /// Forgets the session token.
  void clearSession() => client.clearSession();

  /// The user signed in, or null.
  String? get externalId => client.externalId;

  /// Joining the community, and profiles.
  CommunityApi get community => client.community;

  /// Topics.
  TopicsApi get topics => client.topics;

  /// Posts, the feed and search.
  PostsApi get posts => client.posts;

  /// Comments and replies.
  CommentsApi get comments => client.comments;

  /// Emoji reactions.
  ReactionsApi get reactions => client.reactions;

  /// Image uploads.
  MediaApi get media => client.media;

  /// Blocking members.
  BlocksApi get blocks => client.blocks;

  /// Reports.
  ReportsApi get reports => client.reports;

  /// The moderation archive: what reports removed. Secret key only.
  ArchiveApi get archive => client.archive;

  /// Notifications.
  NotificationsApi get notifications => client.notifications;

  /// The coaching chat: a member's one-to-one chat with their coach.
  CoachChatApi get coachChat => client.coachChat;

  /// Push notifications to the phone.
  PushApi get push => client.push;

  /// The creator's settings.
  SettingsApi get settings => client.settings;

  /// Live updates.
  LiveApi get live => client.live;

  /// The creator's member list and roles. Secret key only.
  MembersApi get members => client.members;

  /// Sessions.
  AuthApi get auth => client.auth;

  /// Erasing end users. Secret key only.
  UsersApi get users => client.users;
}
