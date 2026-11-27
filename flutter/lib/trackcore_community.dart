/// The Community client for Flutter and Dart.
///
/// ```dart
/// import 'package:trackcore_community/trackcore_community.dart';
///
/// await Community.instance.configure(apiKey: 'cm_pk_live_…');
/// await Community.instance.initialize(user.uid);   // after your own sign-in
///
/// final feed = await Community.instance.posts.feed();
/// ```
library;

export 'src/api/apis.dart';
export 'src/api/coach_chat_api.dart';
export 'src/api/live_api.dart';
export 'src/api/live_socket_types.dart';
export 'src/api/media_api.dart';
export 'src/api/reactions_api.dart';
export 'src/client.dart';
export 'src/errors/exceptions.dart';
export 'src/generated/error_code.dart';
export 'src/generated/models.dart';
export 'src/generated/operations.dart';
export 'src/http/http_adapter.dart';
export 'src/http/retry_policy.dart';
export 'src/http/transport.dart'
    show
        CommunityDiagnostic,
        CommunityEnvironment,
        CommunityKeyKind,
        LiveDiagnostic,
        RetryDiagnostic,
        SessionDiagnostic,
        assertValidExternalId,
        communityDefaultBaseUrl,
        communityExternalIdHeader,
        communityIdempotencyHeader,
        communityMaxExternalIdLength,
        communitySessionHeader;

/// The version of this SDK.
const String communitySdkVersion = '0.1.2';
