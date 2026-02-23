import 'package:flutter_test/flutter_test.dart';
import 'package:polly_flutter/polly_flutter.dart';

void main() {
  group('ResilienceSnapshot', () {
    test('idle snapshot has correct status', () {
      final snap = ResilienceSnapshot.idle<String>();
      expect(snap.isIdle, isTrue);
      expect(snap.isLoading, isFalse);
      expect(snap.hasData, isFalse);
      expect(snap.hasError, isFalse);
    });

    test('loading snapshot has correct status', () {
      final snap = ResilienceSnapshot.loading<String>();
      expect(snap.isLoading, isTrue);
      expect(snap.hasData, isFalse);
    });

    test('success snapshot carries data', () {
      final snap = ResilienceSnapshot.success<String>('hello');
      expect(snap.isSuccess, isTrue);
      expect(snap.data, 'hello');
      expect(snap.hasData, isTrue);
      expect(snap.hasError, isFalse);
    });

    test('failure snapshot carries error', () {
      final error = Exception('oops');
      final snap = ResilienceSnapshot.failure<String>(error, null);
      expect(snap.hasError, isTrue);
      expect(snap.error, error);
      expect(snap.hasData, isFalse);
    });

    test('retrying snapshot carries attempt number', () {
      final snap = ResilienceSnapshot.retrying<String>(2);
      expect(snap.isRetrying, isTrue);
      expect(snap.attemptNumber, 2);
    });

    test('copyWith overrides selected fields', () {
      final original = ResilienceSnapshot.success<String>('v1');
      final updated = original.copyWith(data: 'v2');
      expect(updated.data, 'v2');
      expect(updated.status, ResilienceStatus.success);
    });
  });

  group('ResilienceStateNotifier', () {
    test('notifies listeners on update', () {
      final notifier = ResilienceStateNotifier<int>();
      var notified = false;
      notifier.addListener(() => notified = true);
      notifier.setSuccess(42);
      expect(notified, isTrue);
      expect(notifier.snapshot.data, 42);
    });

    test('setLoading transitions to loading', () {
      final notifier = ResilienceStateNotifier<int>();
      notifier.setLoading();
      expect(notifier.snapshot.isLoading, isTrue);
    });

    test('setError carries error object', () {
      final notifier = ResilienceStateNotifier<int>();
      final err = Exception('fail');
      notifier.setError(err);
      expect(notifier.snapshot.hasError, isTrue);
      expect(notifier.snapshot.error, err);
    });
  });

  group('ResilienceSnapshotExtensions.when', () {
    test('routes to correct callback', () {
      final snap = ResilienceSnapshot.success<int>(7);
      final result = snap.when(
        idle: () => 'idle',
        loading: () => 'loading',
        success: (d) => 'success:$d',
        error: (e, _) => 'error',
      );
      expect(result, 'success:7');
    });

    test('routes error snapshot correctly', () {
      final snap = ResilienceSnapshot.failure<int>(Exception('e'), null);
      final result = snap.when(
        idle: () => 'idle',
        loading: () => 'loading',
        success: (d) => 'success',
        error: (e, _) => 'error',
      );
      expect(result, 'error');
    });

    test('retrying falls back to loading when no retrying callback', () {
      final snap = ResilienceSnapshot.retrying<int>(1);
      final result = snap.when(
        idle: () => 'idle',
        loading: () => 'loading',
        success: (d) => 'success',
        error: (e, _) => 'error',
      );
      expect(result, 'loading');
    });
  });
}
