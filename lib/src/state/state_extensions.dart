import 'resilience_state.dart';

/// Extensions on [ResilienceSnapshot] for convenient widget building.
extension ResilienceSnapshotExtensions<T> on ResilienceSnapshot<T> {
  /// Calls the appropriate callback based on the current status.
  R when<R>({
    required R Function() idle,
    required R Function() loading,
    required R Function(T data) success,
    required R Function(Object error, StackTrace? stackTrace) error,
    R Function(int attempt)? retrying,
    R Function()? rateLimited,
    R Function()? circuitOpen,
  }) {
    switch (status) {
      case ResilienceStatus.idle:
        return idle();
      case ResilienceStatus.loading:
        return loading();
      case ResilienceStatus.success:
        return success(data as T);
      case ResilienceStatus.error:
        return error(this.error!, stackTrace);
      case ResilienceStatus.retrying:
        return retrying != null ? retrying(attemptNumber) : loading();
      case ResilienceStatus.rateLimited:
        return rateLimited != null ? rateLimited() : loading();
      case ResilienceStatus.circuitOpen:
        return circuitOpen != null
            ? circuitOpen()
            : error(
                Exception('Circuit breaker is open'), null);
    }
  }

  /// Calls one of two callbacks: [orElse] for non-success states, [data] for success.
  R maybeWhen<R>({
    required R Function(T data) data,
    required R Function() orElse,
  }) {
    if (isSuccess && hasData) {
      return data(this.data as T);
    }
    return orElse();
  }
}
