import 'package:polly_dart/polly_dart.dart';

/// Pre-built resilience pipelines for common Flutter use cases.
class DefaultPipelines {
  DefaultPipelines._();

  /// A simple retry pipeline: 3 attempts with exponential backoff.
  static ResiliencePipeline standardRetry() {
    return ResiliencePipelineBuilder()
        .addRetry(RetryStrategyOptions(
          maxRetryAttempts: 3,
          delay: const Duration(milliseconds: 500),
          backoffType: DelayBackoffType.exponential,
          useJitter: true,
        ))
        .build();
  }

  /// A pipeline suited for network image loading: retry + circuit breaker.
  static ResiliencePipeline networkImage() {
    return ResiliencePipelineBuilder()
        .addRetry(RetryStrategyOptions(
          maxRetryAttempts: 2,
          delay: const Duration(milliseconds: 300),
          backoffType: DelayBackoffType.linear,
        ))
        .addCircuitBreaker(CircuitBreakerStrategyOptions(
          failureRatio: 0.5,
          minimumThroughput: 5,
          breakDuration: const Duration(seconds: 30),
        ))
        .build();
  }

  /// A pipeline suitable for user-triggered actions (e.g., button taps):
  /// single timeout + single retry.
  static ResiliencePipeline userAction() {
    return ResiliencePipelineBuilder()
        .addTimeout(const Duration(seconds: 10))
        .addRetry(RetryStrategyOptions(
          maxRetryAttempts: 1,
          delay: const Duration(milliseconds: 200),
          backoffType: DelayBackoffType.constant,
        ))
        .build();
  }

  /// A pipeline for long-lived data fetches with caching.
  static ResiliencePipeline cachedFetch<T>({Duration? ttl}) {
    return ResiliencePipelineBuilder()
        .addMemoryCache<T>(ttl: ttl ?? const Duration(minutes: 5))
        .addRetry(RetryStrategyOptions(
          maxRetryAttempts: 3,
          delay: const Duration(seconds: 1),
          backoffType: DelayBackoffType.exponential,
          useJitter: true,
        ))
        .build();
  }

  /// A pipeline for infinite scroll / paginated data.
  static ResiliencePipeline pagination() {
    return ResiliencePipelineBuilder()
        .addRetry(RetryStrategyOptions(
          maxRetryAttempts: 3,
          delay: const Duration(milliseconds: 500),
          backoffType: DelayBackoffType.exponential,
        ))
        .addTimeout(const Duration(seconds: 15))
        .build();
  }
}
