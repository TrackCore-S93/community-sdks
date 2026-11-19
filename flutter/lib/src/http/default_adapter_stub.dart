import '../errors/exceptions.dart';
import 'http_adapter.dart';

/// Where `dart:io` does not exist (the web), there is no built-in adapter yet.
CommunityHttpAdapter createDefaultAdapter() =>
    throw const CommunityConfigurationException(
      CommunityConfigurationReason.optionInvalid,
      'This platform has no built-in HTTP adapter. Pass one as httpAdapter.',
    );
