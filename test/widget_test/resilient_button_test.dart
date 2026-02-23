import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polly_flutter/polly_flutter.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('ResilientButton', () {
    testWidgets('shows child and invokes onAsyncPressed', (tester) async {
      var pressed = false;
      await tester.pumpWidget(_wrap(
        ResilientButton(
          onAsyncPressed: () async => pressed = true,
          pipelineBuilder: (b) => b,
          child: const Text('Go'),
        ),
      ));

      expect(find.text('Go'), findsOneWidget);
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      expect(pressed, isTrue);
    });

    testWidgets('shows loadingChild while async action is in flight',
        (tester) async {
      final completer = Completer<void>();

      await tester.pumpWidget(_wrap(
        ResilientButton(
          onAsyncPressed: () => completer.future,
          pipelineBuilder: (b) => b,
          loadingChild: const Text('loading…'),
          child: const Text('Go'),
        ),
      ));

      await tester.tap(find.text('Go'));
      await tester.pump(); // one frame — action in flight

      expect(find.text('loading…'), findsOneWidget);
      expect(find.text('Go'), findsNothing);

      completer.complete();
      await tester.pumpAndSettle();

      expect(find.text('Go'), findsOneWidget);
    });

    testWidgets('onSuccess is called after successful press', (tester) async {
      var success = false;
      await tester.pumpWidget(_wrap(
        ResilientButton(
          onAsyncPressed: () async {},
          pipelineBuilder: (b) => b,
          onSuccess: () => success = true,
          child: const Text('Go'),
        ),
      ));

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      expect(success, isTrue);
    });

    testWidgets('onError is called after failed press', (tester) async {
      Object? caughtError;
      await tester.pumpWidget(_wrap(
        ResilientButton(
          onAsyncPressed: () async => throw Exception('oops'),
          pipelineBuilder: (b) => b,
          onError: (e, _) => caughtError = e,
          child: const Text('Go'),
        ),
      ));

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      expect(caughtError, isNotNull);
    });

    testWidgets('debounce prevents double-tap', (tester) async {
      var count = 0;
      await tester.pumpWidget(_wrap(
        ResilientButton(
          onAsyncPressed: () async => count++,
          pipelineBuilder: (b) => b,
          debounceTime: const Duration(seconds: 1),
          child: const Text('Go'),
        ),
      ));

      await tester.tap(find.text('Go'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Go')); // within debounce window — ignored
      await tester.pumpAndSettle();

      expect(count, 1);
    });
  });
}
