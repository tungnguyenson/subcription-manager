import 'package:meta/meta.dart';
import 'package:subdock/i18n.dart';

/// What went wrong, and crucially whether retrying could ever help.
///
/// HTTP 429 covers five distinct conditions and three of them are permanent:
/// treating every 429 as "back off and retry" leaves a user with no credit
/// watching a spinner forever. So the branch is on the error `code` in the body,
/// never on the status alone. See product-spec.md section 8.7.
@immutable
sealed class ExtractionError {
  const ExtractionError();

  bool get retryable;

  /// Message shown to the user.
  String get message;
}

/// Genuine rate limiting. Honour [retryAfterSeconds] when present.
class RateLimited extends ExtractionError {
  final int? retryAfterSeconds;

  const RateLimited(this.retryAfterSeconds);

  @override
  bool get retryable => true;

  @override
  String get message => S.t.errRateLimited;

  @override
  bool operator ==(Object other) =>
      other is RateLimited && other.retryAfterSeconds == retryAfterSeconds;

  @override
  int get hashCode => retryAfterSeconds.hashCode;
}

/// The account has no prepaid credit. Retrying never succeeds.
class CreditExhausted extends ExtractionError {
  const CreditExhausted();

  @override
  bool get retryable => false;

  @override
  String get message => S.t.errCreditExhausted;

  @override
  bool operator ==(Object other) => other is CreditExhausted;

  @override
  int get hashCode => 'CreditExhausted'.hashCode;
}

/// A spend cap the user set on their own account.
class SpendLimitReached extends ExtractionError {
  const SpendLimitReached();

  @override
  bool get retryable => false;

  @override
  String get message => S.t.errSpendLimit;

  @override
  bool operator ==(Object other) => other is SpendLimitReached;

  @override
  int get hashCode => 'SpendLimitReached'.hashCode;
}

/// The most common failure with a user-supplied key.
class InvalidKey extends ExtractionError {
  const InvalidKey();

  @override
  bool get retryable => false;

  @override
  String get message => S.t.errInvalidKey;

  @override
  bool operator ==(Object other) => other is InvalidKey;

  @override
  int get hashCode => 'InvalidKey'.hashCode;
}

class RegionUnsupported extends ExtractionError {
  const RegionUnsupported();

  @override
  bool get retryable => false;

  @override
  String get message => S.t.errRegionUnsupported;

  @override
  bool operator ==(Object other) => other is RegionUnsupported;

  @override
  int get hashCode => 'RegionUnsupported'.hashCode;
}

class ServerError extends ExtractionError {
  final int status;

  const ServerError(this.status);

  @override
  bool get retryable => true;

  @override
  String get message => S.t.errUpstream;

  @override
  bool operator ==(Object other) =>
      other is ServerError && other.status == status;

  @override
  int get hashCode => status.hashCode;
}

class NoNetwork extends ExtractionError {
  const NoNetwork();

  @override
  bool get retryable => true;

  @override
  String get message => S.t.errNoNetwork;

  @override
  bool operator ==(Object other) => other is NoNetwork;

  @override
  int get hashCode => 'NoNetwork'.hashCode;
}

/// The model declined. The schema is not honoured in this case.
class Refused extends ExtractionError {
  final String? reason;

  const Refused(this.reason);

  @override
  bool get retryable => false;

  @override
  String get message => S.t.errUnreadable;

  @override
  bool operator ==(Object other) => other is Refused && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;
}

/// Output hit the token cap, so the JSON is cut off mid-structure.
/// Unparseable, not partially valid.
class Truncated extends ExtractionError {
  const Truncated();

  @override
  bool get retryable => true;

  @override
  String get message => S.t.errTruncated;

  @override
  bool operator ==(Object other) => other is Truncated;

  @override
  int get hashCode => 'Truncated'.hashCode;
}

class Malformed extends ExtractionError {
  final String? detail;

  const Malformed(this.detail);

  @override
  bool get retryable => false;

  @override
  String get message => S.t.errBadShape;

  @override
  bool operator ==(Object other) =>
      other is Malformed && other.detail == detail;

  @override
  int get hashCode => detail.hashCode;
}

class NoApiKey extends ExtractionError {
  const NoApiKey();

  @override
  bool get retryable => false;

  @override
  String get message => S.t.errNoApiKey;

  @override
  bool operator ==(Object other) => other is NoApiKey;

  @override
  int get hashCode => 'NoApiKey'.hashCode;
}

/// Maps an API failure onto the right branch.
///
/// Deliberately takes the error code as well as the status, because the status
/// alone cannot distinguish "wait a moment" from "you have no money".
abstract final class ErrorMapper {
  static ExtractionError map(
    int status, {
    String? errorCode,
    String? errorType,
    int? retryAfterSeconds,
  }) {
    final code = errorCode ?? errorType;

    if (status == 401) return const InvalidKey();
    if (status == 403) return const RegionUnsupported();

    if (status == 429) {
      return switch (code) {
        'credit_balance_exhausted' ||
        'insufficient_quota' => const CreditExhausted(),
        'organization_spend_limit_exceeded' ||
        'project_spend_limit_exceeded' ||
        'organization_usage_limit_exceeded' => const SpendLimitReached(),
        _ => RateLimited(retryAfterSeconds),
      };
    }

    if (status >= 500) return ServerError(status);
    return Malformed(code);
  }
}
