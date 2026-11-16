/// When a failed attempt is tried again.
library;

import 'dart:math';

import 'http_adapter.dart';

/// The retry rules for one client.
///
/// | Outcome | Retried |
/// |---|---|
/// | connection failure, attempt timeout, 408, 429, 503, 504 | yes, up to [maxAttempts] |
/// | 502 | up to [badGatewayMaxAttempts] |
/// | 500, and every other 4xx | no |
final class CommunityRetryPolicy {
  CommunityRetryPolicy({
    this.maxAttempts = 3,
    this.badGatewayMaxAttempts = 2,
    this.backoffBase = const Duration(milliseconds: 250),
    this.backoffMax = const Duration(seconds: 4),
    this.totalDeadline = const Duration(seconds: 30),
    Random? random,
  }) : _random = random ?? Random() {
    if (maxAttempts < 1) {
      throw ArgumentError.value(
          maxAttempts, 'maxAttempts', 'must be at least 1');
    }
    if (badGatewayMaxAttempts < 1 || badGatewayMaxAttempts > maxAttempts) {
      throw ArgumentError.value(badGatewayMaxAttempts, 'badGatewayMaxAttempts',
          'must be between 1 and maxAttempts');
    }
  }

  /// A policy that never retries.
  factory CommunityRetryPolicy.none() =>
      CommunityRetryPolicy(maxAttempts: 1, badGatewayMaxAttempts: 1);

  /// The most attempts one call makes, the first included.
  final int maxAttempts;

  /// The most attempts for a 502, the first included.
  final int badGatewayMaxAttempts;

  /// The first backoff ceiling. It doubles each attempt.
  final Duration backoffBase;

  /// The longest backoff.
  final Duration backoffMax;

  /// The time allowed for the whole call, retries and backoff included.
  final Duration totalDeadline;

  final Random _random;

  /// Whether a failure before any reply is worth another attempt.
  bool shouldRetryTransport(CommunityAdapterFailureKind kind) =>
      kind == CommunityAdapterFailureKind.connectFailed ||
      kind == CommunityAdapterFailureKind.timeout;

  /// Whether a reply with this status is worth another attempt.
  bool shouldRetryStatus(int statusCode) =>
      statusCode == 408 ||
      statusCode == 429 ||
      statusCode == 502 ||
      statusCode == 503 ||
      statusCode == 504;

  /// The most attempts for a reply with this status.
  int attemptCeilingFor(int statusCode) =>
      statusCode == 502 ? badGatewayMaxAttempts : maxAttempts;

  /// How long to wait before attempt number [attempt] + 1: exponential
  /// backoff with full jitter.
  Duration backoffFor(int attempt) {
    final ceiling = min(backoffMax.inMicroseconds,
        backoffBase.inMicroseconds * pow(2, attempt - 1).toInt());
    return Duration(microseconds: (_random.nextDouble() * ceiling).round());
  }
}
