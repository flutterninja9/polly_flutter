import 'package:flutter/material.dart';
import 'package:polly_dart/polly_dart.dart';

/// A [RefreshIndicator] wrapper that applies a [ResiliencePipeline] to the
/// refresh callback and rate-limits rapid pull-to-refresh actions.
///
/// Example:
/// ```dart
/// ResilientRefreshIndicator(
///   onRefresh: () => controller.reload(),
///   child: ListView(...),
/// )
/// ```
class ResilientRefreshIndicator extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  /// Minimum duration between successive refresh attempts.
  final Duration rateLimitInterval;

  /// Optional pipeline customizer.
  final ResiliencePipelineBuilder Function(ResiliencePipelineBuilder)?
      pipelineBuilder;

  final void Function(Object, StackTrace?)? onError;

  const ResilientRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.rateLimitInterval = const Duration(seconds: 3),
    this.pipelineBuilder,
    this.onError,
  });

  @override
  State<ResilientRefreshIndicator> createState() =>
      _ResilientRefreshIndicatorState();
}

class _ResilientRefreshIndicatorState
    extends State<ResilientRefreshIndicator> {
  late ResiliencePipeline _pipeline;
  DateTime? _lastRefresh;

  @override
  void initState() {
    super.initState();
    _buildPipeline();
  }

  void _buildPipeline() {
    final b = ResiliencePipelineBuilder();
    _pipeline = widget.pipelineBuilder != null
        ? widget.pipelineBuilder!(b).build()
        : b
            .addRetry(RetryStrategyOptions(
              maxRetryAttempts: 2,
              delay: const Duration(milliseconds: 300),
              backoffType: DelayBackoffType.linear,
            ))
            .build();
  }

  Future<void> _handleRefresh() async {
    final now = DateTime.now();
    if (_lastRefresh != null &&
        now.difference(_lastRefresh!) < widget.rateLimitInterval) {
      return;
    }
    _lastRefresh = now;

    final outcome =
        await _pipeline.executeAndCapture<void>((_) => widget.onRefresh());

    if (outcome.hasException) {
      widget.onError?.call(outcome.exception, outcome.stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: widget.child,
    );
  }
}
