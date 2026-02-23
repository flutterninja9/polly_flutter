import 'package:flutter/foundation.dart';

/// Represents the current status of a resilience operation.
enum ResilienceStatus {
  /// No operation has been started.
  idle,

  /// The operation is currently loading.
  loading,

  /// The operation completed successfully.
  success,

  /// The operation encountered an error.
  error,

  /// The operation is being retried.
  retrying,

  /// The operation is rate-limited.
  rateLimited,

  /// The circuit breaker is open; operation is blocked.
  circuitOpen,
}

/// A snapshot of the current resilience state for a typed value.
class ResilienceSnapshot<T> {
  final ResilienceStatus status;
  final T? data;
  final Object? error;
  final StackTrace? stackTrace;
  final int attemptNumber;

  const ResilienceSnapshot({
    required this.status,
    this.data,
    this.error,
    this.stackTrace,
    this.attemptNumber = 0,
  });

  bool get hasData => data != null;
  bool get hasError => error != null;
  bool get isLoading => status == ResilienceStatus.loading;
  bool get isSuccess => status == ResilienceStatus.success;
  bool get isRetrying => status == ResilienceStatus.retrying;
  bool get isRateLimited => status == ResilienceStatus.rateLimited;
  bool get isCircuitOpen => status == ResilienceStatus.circuitOpen;
  bool get isIdle => status == ResilienceStatus.idle;

  ResilienceSnapshot<T> copyWith({
    ResilienceStatus? status,
    T? data,
    Object? error,
    StackTrace? stackTrace,
    int? attemptNumber,
  }) {
    return ResilienceSnapshot<T>(
      status: status ?? this.status,
      data: data ?? this.data,
      error: error ?? this.error,
      stackTrace: stackTrace ?? this.stackTrace,
      attemptNumber: attemptNumber ?? this.attemptNumber,
    );
  }

  static ResilienceSnapshot<T> idle<T>() =>
      const ResilienceSnapshot(status: ResilienceStatus.idle);

  static ResilienceSnapshot<T> loading<T>() =>
      const ResilienceSnapshot(status: ResilienceStatus.loading);

  static ResilienceSnapshot<T> success<T>(T data) =>
      ResilienceSnapshot<T>(status: ResilienceStatus.success, data: data);

  static ResilienceSnapshot<T> failure<T>(
          Object error, StackTrace? stackTrace) =>
      ResilienceSnapshot<T>(
          status: ResilienceStatus.error,
          error: error,
          stackTrace: stackTrace);

  static ResilienceSnapshot<T> retrying<T>(int attempt) =>
      ResilienceSnapshot<T>(
          status: ResilienceStatus.retrying, attemptNumber: attempt);
}

/// A [ChangeNotifier] that holds and broadcasts a [ResilienceSnapshot].
class ResilienceStateNotifier<T> extends ChangeNotifier {
  ResilienceSnapshot<T> _snapshot = ResilienceSnapshot.idle<T>();

  ResilienceSnapshot<T> get snapshot => _snapshot;

  void update(ResilienceSnapshot<T> snapshot) {
    _snapshot = snapshot;
    notifyListeners();
  }

  void setIdle() => update(ResilienceSnapshot.idle<T>());
  void setLoading() => update(ResilienceSnapshot.loading<T>());
  void setSuccess(T data) => update(ResilienceSnapshot.success<T>(data));
  void setError(Object error, [StackTrace? stackTrace]) =>
      update(ResilienceSnapshot.failure<T>(error, stackTrace));
  void setRetrying(int attempt) => update(ResilienceSnapshot.retrying<T>(attempt));
}
