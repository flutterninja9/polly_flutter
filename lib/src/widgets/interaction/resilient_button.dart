import 'dart:async';

import 'package:flutter/material.dart';
import 'package:polly_dart/polly_dart.dart';

/// A button widget that wraps an async action in a [ResiliencePipeline],
/// providing debouncing, rate-limiting, retry, and loading-state management.
///
/// Example:
/// ```dart
/// ResilientButton(
///   onAsyncPressed: () => api.submitOrder(order),
///   child: const Text('Submit Order'),
/// )
/// ```
class ResilientButton extends StatefulWidget {
  /// Synchronous callback — used when no resilience is needed.
  final VoidCallback? onPressed;

  /// Async callback wrapped by the resilience pipeline.
  final Future<void> Function()? onAsyncPressed;

  /// Optional pipeline customizer. Defaults to timeout + single retry.
  final ResiliencePipelineBuilder Function(ResiliencePipelineBuilder)?
      pipelineBuilder;

  /// Minimum time between taps (debounce). Defaults to 300 ms.
  final Duration debounceTime;

  final Widget child;

  /// Widget shown while the async action is in flight.
  final Widget? loadingChild;

  final ButtonStyle? style;

  /// Called after a successful async execution.
  final VoidCallback? onSuccess;

  /// Called after a failed execution.
  final void Function(Object, StackTrace?)? onError;

  const ResilientButton({
    super.key,
    this.onPressed,
    this.onAsyncPressed,
    this.pipelineBuilder,
    this.debounceTime = const Duration(milliseconds: 300),
    required this.child,
    this.loadingChild,
    this.style,
    this.onSuccess,
    this.onError,
  }) : assert(onPressed != null || onAsyncPressed != null,
            'Provide either onPressed or onAsyncPressed');

  @override
  State<ResilientButton> createState() => _ResilientButtonState();
}

class _ResilientButtonState extends State<ResilientButton> {
  late ResiliencePipeline _pipeline;
  bool _loading = false;
  DateTime? _lastTap;

  @override
  void initState() {
    super.initState();
    _buildPipeline();
  }

  @override
  void didUpdateWidget(ResilientButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pipelineBuilder != widget.pipelineBuilder) {
      _buildPipeline();
    }
  }

  void _buildPipeline() {
    final b = ResiliencePipelineBuilder();
    _pipeline = widget.pipelineBuilder != null
        ? widget.pipelineBuilder!(b).build()
        : b
            .addTimeout(const Duration(seconds: 10))
            .addRetry(RetryStrategyOptions(
              maxRetryAttempts: 1,
              delay: const Duration(milliseconds: 200),
              backoffType: DelayBackoffType.constant,
            ))
            .build();
  }

  Future<void> _handlePress() async {
    if (widget.onPressed != null) {
      widget.onPressed!();
      return;
    }

    // Debounce
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!) < widget.debounceTime) {
      return;
    }
    _lastTap = now;

    if (_loading) return;
    setState(() => _loading = true);

    final outcome = await _pipeline.executeAndCapture<void>(
        (_) => widget.onAsyncPressed!());

    if (!mounted) return;
    setState(() => _loading = false);

    if (outcome.hasResult) {
      widget.onSuccess?.call();
    } else {
      widget.onError?.call(outcome.exception, outcome.stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveChild =
        _loading ? (widget.loadingChild ?? _defaultLoading()) : widget.child;

    return ElevatedButton(
      onPressed: _loading ? null : _handlePress,
      style: widget.style,
      child: effectiveChild,
    );
  }

  Widget _defaultLoading() => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
}
