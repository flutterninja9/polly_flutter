import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polly_flutter/polly_flutter.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

void main() {
  group('ResilientFutureBuilder', () {
    testWidgets('shows loading then success', (tester) async {
      final completer = Completer<String>();

      await tester.pumpWidget(_wrap(
        ResilientFutureBuilder<String>(
          futureFactory: () => completer.future,
          // No retry so the test doesn't time out waiting for retries
          pipelineBuilder: (b) => b,
          builder: (ctx, snap) {
            if (snap.isLoading) return const Text('loading');
            if (snap.isSuccess) return Text('data:${snap.data}');
            return const Text('other');
          },
        ),
      ));

      expect(find.text('loading'), findsOneWidget);

      completer.complete('hello');
      await tester.pumpAndSettle();

      expect(find.text('data:hello'), findsOneWidget);
    });

    testWidgets('shows error state on failure', (tester) async {
      await tester.pumpWidget(_wrap(
        ResilientFutureBuilder<String>(
          futureFactory: () async => throw Exception('boom'),
          pipelineBuilder: (b) => b, // no retry
          builder: (ctx, snap) {
            if (snap.isLoading) return const Text('loading');
            if (snap.hasError) return const Text('error');
            return const Text('other');
          },
        ),
      ));

      await tester.pumpAndSettle();
      expect(find.text('error'), findsOneWidget);
    });

    testWidgets('dedicated loadingBuilder is shown while loading',
        (tester) async {
      final completer = Completer<String>();

      await tester.pumpWidget(_wrap(
        ResilientFutureBuilder<String>(
          futureFactory: () => completer.future,
          pipelineBuilder: (b) => b,
          loadingBuilder: (_) => const Text('custom-loading'),
          builder: (ctx, snap) => const Text('done'),
        ),
      ));

      expect(find.text('custom-loading'), findsOneWidget);
      completer.complete('ok');
      await tester.pumpAndSettle();
      expect(find.text('done'), findsOneWidget);
    });

    testWidgets('dedicated errorBuilder is shown on failure', (tester) async {
      await tester.pumpWidget(_wrap(
        ResilientFutureBuilder<String>(
          futureFactory: () async => throw Exception('fail'),
          pipelineBuilder: (b) => b,
          errorBuilder: (_, err, st) => Text('custom-error:$err'),
          builder: (ctx, snap) => const Text('done'),
        ),
      ));

      await tester.pumpAndSettle();
      expect(find.textContaining('custom-error'), findsOneWidget);
    });

    testWidgets('onSuccess callback is invoked', (tester) async {
      String? received;
      await tester.pumpWidget(_wrap(
        ResilientFutureBuilder<String>(
          futureFactory: () async => 'result',
          pipelineBuilder: (b) => b,
          onSuccess: (v) => received = v,
          builder: (ctx, snap) => const SizedBox(),
        ),
      ));

      await tester.pumpAndSettle();
      expect(received, 'result');
    });

    testWidgets('onError callback is invoked on failure', (tester) async {
      Object? receivedError;
      await tester.pumpWidget(_wrap(
        ResilientFutureBuilder<String>(
          futureFactory: () async => throw Exception('err'),
          pipelineBuilder: (b) => b,
          onError: (e, _) => receivedError = e,
          builder: (ctx, snap) => const SizedBox(),
        ),
      ));

      await tester.pumpAndSettle();
      expect(receivedError, isNotNull);
    });
  });
}
