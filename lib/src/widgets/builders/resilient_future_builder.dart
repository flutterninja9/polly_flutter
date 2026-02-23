import 'dart:async';

import 'package:flutter/material.dart';
import 'package:polly_dart/polly_dart.dart';

import '../../state/resilience_state.dart';

/// A widget that executes a [Future]-producing factory through a
/// [ResiliencePipeline] and rebuilds based on the resulting [ResilienceSnapshot].
///
/// Example:
/// ```dart
/// ResilientFutureBuilder<User>(
///   futureFactory: () => userService.getUser(id),
///   pipelineBuilder: (b) => b.addRetry().addTimeout(Duration(seconds: 5)),
///   builder: (context, snapshot) {
///     if (snapshot.isSuccess) return UserCard(user: snapshot.data!);
///     if (snapshot.isLoading) return const CircularProgressIndicator();
///     return ErrorView(error: snapshot.error);
///   },
/// )
/// ```
class ResilientFutureBuilder<T> extends StatefulWidget {
  /// Factory that produces a new [Future<T>] on each execution.
  final Future<T> Function() futureFactory;

  /// Optional customizer for the resilience pipeline. If null, a default
  /// retry pipeline is used.
  final ResiliencePipelineBuilder Function(ResiliencePipelineBuilder)?
      pipelineBuilder;

  /// Main builder called whenever the snapshot changes.
  final Widget Function(BuildContext, ResilienceSnapshot<T>) builder;

  /// Optional dedicated loading widget.
  final Widget Function(BuildContext)? loadingBuilder;

  /// Optional dedicated error widget.
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  /// Optional widget shown while retrying. Receives the current attempt number.
  final Widget Function(BuildContext, int)? retryBuilder;

  /// Periodically refresh the data at this interval.
  final Duration? refreshInterval;

  /// Whether to start fetching immediately when the widget is first built.
  final bool autoExecute;

  /// Called after a successful execution.
  final void Function(T)? onSuccess;

  /// Called after a failed execution (after all retries).
  final void Function(Object, StackTrace?)? onError;

  const ResilientFutureBuilder({
    super.key,
    required this.futureFactory,
    required this.builder,
    this.pipelineBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.retryBuilder,
    this.refreshInterval,
    this.autoExecute = true,
    this.onSuccess,
    this.onError,
  });

  @override
  State<ResilientFutureBuilder<T>> createState() =>
      _ResilientFutureBuilderState<T>();
}

class _ResilientFutureBuilderState<T>
    extends State<ResilientFutureBuilder<T>> {
  late ResiliencePipeline _pipeline;
  late ResilienceSnapshot<T> _snapshot;
  Timer? _refreshTimer;
  bool _mounted = true;

  @override
  void initState() {
    super.initState();
    _snapshot = ResilienceSnapshot.idle<T>();
    _buildPipeline();
    if (widget.autoExecute) _execute();
    _startRefreshTimer();
  }

  @override
  void didUpdateWidget(ResilientFutureBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pipelineBuilder != widget.pipelineBuilder) {
      _buildPipeline();
    }
    if (oldWidget.refreshInterval != widget.refreshInterval) {
      _stopRefreshTimer();
      _startRefreshTimer();
    }
  }

  @override
  void dispose() {
    _mounted = false;
    _stopRefreshTimer();
    super.dispose();
  }

  void _buildPipeline() {
    final builder = ResiliencePipelineBuilder();
    if (widget.pipelineBuilder != null) {
      _pipeline = widget.pipelineBuilder!(builder).build();
    } else {
      _pipeline = builder
          .addRetry(RetryStrategyOptions(
            maxRetryAttempts: 3,
            delay: const Duration(milliseconds: 500),
            backoffType: DelayBackoffType.exponential,
            useJitter: true,
            onRetry: (args) async {
              if (_mounted) {
                setState(() {
                  _snapshot = ResilienceSnapshot<T>(
                    status: ResilienceStatus.retrying,
                    attemptNumber: args.attemptNumber + 1,
                    data: _snapshot.data,
                  );
                });
              }
            },
          ))
          .build();
    }
  }

  void _startRefreshTimer() {
    if (widget.refreshInterval != null) {
      _refreshTimer =
          Timer.periodic(widget.refreshInterval!, (_) => _execute());
    }
  }

  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> _execute() async {
    if (!_mounted) return;
    setState(() {
      _snapshot = ResilienceSnapshot.loading<T>();
    });

    final outcome =
        await _pipeline.executeAndCapture<T>((ctx) => widget.futureFactory());

    if (!_mounted) return;

    if (outcome.hasResult) {
      setState(() {
        _snapshot = ResilienceSnapshot.success<T>(outcome.result);
      });
      widget.onSuccess?.call(outcome.result);
    } else {
      setState(() {
        _snapshot = ResilienceSnapshot.failure<T>(
            outcome.exception, outcome.stackTrace);
      });
      widget.onError?.call(outcome.exception, outcome.stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Delegate to dedicated builders when available
    if (_snapshot.isLoading || _snapshot.isRetrying) {
      if (_snapshot.isRetrying && widget.retryBuilder != null) {
        return widget.retryBuilder!(context, _snapshot.attemptNumber);
      }
      if (widget.loadingBuilder != null) {
        return widget.loadingBuilder!(context);
      }
    }

    if (_snapshot.hasError && widget.errorBuilder != null) {
      return widget.errorBuilder!(context, _snapshot.error!, _snapshot.stackTrace);
    }

    return widget.builder(context, _snapshot);
  }
}
