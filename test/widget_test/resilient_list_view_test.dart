import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polly_flutter/polly_flutter.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('ResilientListView', () {
    testWidgets('shows items on success', (tester) async {
      await tester.pumpWidget(_wrap(
        ResilientListView<String>(
          dataLoader: () async => ['A', 'B', 'C'],
          itemBuilder: (ctx, item) => Text(item),
          pipelineBuilder: (b) => b,
        ),
      ));

      await tester.pumpAndSettle();

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
    });

    testWidgets('shows emptyWidget when list is empty', (tester) async {
      await tester.pumpWidget(_wrap(
        ResilientListView<String>(
          dataLoader: () async => [],
          itemBuilder: (ctx, item) => Text(item),
          pipelineBuilder: (b) => b,
          emptyWidget: const Text('nothing here'),
        ),
      ));

      await tester.pumpAndSettle();
      expect(find.text('nothing here'), findsOneWidget);
    });

    testWidgets('shows errorBuilder on failure', (tester) async {
      await tester.pumpWidget(_wrap(
        ResilientListView<String>(
          dataLoader: () async => throw Exception('load failed'),
          itemBuilder: (ctx, item) => Text(item),
          pipelineBuilder: (b) => b,
          errorBuilder: (ctx, err, st, retry) => const Text('error-view'),
        ),
      ));

      await tester.pumpAndSettle();
      expect(find.text('error-view'), findsOneWidget);
    });

    testWidgets('shows loading indicator initially', (tester) async {
      // Use a Completer that never completes so the widget stays in loading state.
      final completer = Completer<List<String>>();
      await tester.pumpWidget(_wrap(
        ResilientListView<String>(
          dataLoader: () => completer.future,
          itemBuilder: (ctx, item) => Text(item),
          pipelineBuilder: (b) => b,
        ),
      ));

      // First frame — still loading
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete so no pending async work leaks after widget disposal.
      completer.complete([]);
    });
  });
}
