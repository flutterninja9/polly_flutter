import 'package:flutter/material.dart';
import 'package:polly_dart/polly_dart.dart';

import '../../state/resilience_state.dart';

/// A general-purpose container that lazily runs an async initializer through a
/// [ResiliencePipeline] and renders different widgets for each [ResilienceStatus].
///
/// Use this as a lightweight alternative to [ResilientFutureBuilder] when you
/// want to wrap an entire screen section (not just a single data value).
///
/// Example:
/// ```dart
/// ResilientContainer(
///   initializer: () => service.init(),
///   child: MyFeatureWidget(),
///   loadingChild: const LoadingScreen(),
/// )
/// ```
class ResilientContainer extends StatefulWidget {
  /// Async task run on first build. The container enters `success` state once
  /// this completes successfully.
  final Future<void> Function()? initializer;

  /// Widget shown in `success` (or `idle` when no initializer is provided).
  final Widget child;

  final Widget? loadingChild;
  final Widget Function(BuildContext, Object, StackTrace?, VoidCallback retry)?
      errorBuilder;

  /// Optional pipeline customizer.
  final ResiliencePipelineBuilder Function(ResiliencePipelineBuilder)?
      pipelineBuilder;

  const ResilientContainer({
    super.key,
    required this.child,
    this.initializer,
    this.loadingChild,
    this.errorBuilder,
    this.pipelineBuilder,
  });

  @override
  State<ResilientContainer> createState() => _ResilientContainerState();
}

class _ResilientContainerState extends State<ResilientContainer> {
  late ResiliencePipeline _pipeline;
  ResilienceSnapshot<void> _snapshot = ResilienceSnapshot.idle<void>();

  @override
  void initState() {
    super.initState();
    _buildPipeline();
    if (widget.initializer != null) {
      _run();
    } else {
      _snapshot = ResilienceSnapshot.success<void>(null);
    }
  }

  void _buildPipeline() {
    final b = ResiliencePipelineBuilder();
    _pipeline = widget.pipelineBuilder != null
        ? widget.pipelineBuilder!(b).build()
        : b
            .addRetry(RetryStrategyOptions(
              maxRetryAttempts: 2,
              delay: const Duration(milliseconds: 500),
              backoffType: DelayBackoffType.exponential,
            ))
            .build();
  }

  Future<void> _run() async {
    if (!mounted) return;
    setState(() => _snapshot = ResilienceSnapshot.loading<void>());

    final outcome =
        await _pipeline.executeAndCapture<void>((_) => widget.initializer!());

    if (!mounted) return;
    setState(() {
      _snapshot = outcome.hasResult
          ? ResilienceSnapshot.success<void>(null)
          : ResilienceSnapshot.failure<void>(
              outcome.exception, outcome.stackTrace);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_snapshot.isLoading) {
      return widget.loadingChild ?? const Center(child: CircularProgressIndicator());
    }

    if (_snapshot.hasError) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(
            context, _snapshot.error!, _snapshot.stackTrace, _run);
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error: ${_snapshot.error}'),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _run, child: const Text('Retry')),
          ],
        ),
      );
    }

    return widget.child;
  }
}
