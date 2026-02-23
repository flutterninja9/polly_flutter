import 'dart:async';

import 'package:flutter/material.dart';
import 'package:polly_dart/polly_dart.dart';

import '../../state/resilience_state.dart';

/// A widget that subscribes to a [Stream] and automatically reconnects on error,
/// applying a [ResiliencePipeline] to each re-subscription attempt.
///
/// Example:
/// ```dart
/// ResilientStreamBuilder<ChatMessage>(
///   streamFactory: () => chatService.messageStream(),
///   builder: (context, snapshot) {
///     if (snapshot.isLoading) return const CircularProgressIndicator();
///     if (snapshot.hasError) return ErrorView(error: snapshot.error);
///     return MessageTile(message: snapshot.data!);
///   },
/// )
/// ```
class ResilientStreamBuilder<T> extends StatefulWidget {
  /// Factory that creates a fresh stream on each (re)connection attempt.
  final Stream<T> Function() streamFactory;

  /// Optional pipeline customizer. Used to wrap each re-subscription attempt.
  final ResiliencePipelineBuilder Function(ResiliencePipelineBuilder)?
      pipelineBuilder;

  /// Builder called on every snapshot change.
  final Widget Function(BuildContext, ResilienceSnapshot<T>) builder;

  /// Optional widget while connecting.
  final Widget Function(BuildContext)? loadingBuilder;

  /// Optional widget on error.
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  /// Maximum reconnect attempts. 0 means unlimited.
  final int maxReconnectAttempts;

  /// Base delay between reconnect attempts.
  final Duration reconnectDelay;

  const ResilientStreamBuilder({
    super.key,
    required this.streamFactory,
    required this.builder,
    this.pipelineBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.maxReconnectAttempts = 5,
    this.reconnectDelay = const Duration(seconds: 2),
  });

  @override
  State<ResilientStreamBuilder<T>> createState() =>
      _ResilientStreamBuilderState<T>();
}

class _ResilientStreamBuilderState<T>
    extends State<ResilientStreamBuilder<T>> {
  StreamSubscription<T>? _subscription;
  ResilienceSnapshot<T> _snapshot = ResilienceSnapshot.idle<T>();
  int _reconnectAttempts = 0;
  bool _mounted = true;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _mounted = false;
    _subscription?.cancel();
    super.dispose();
  }

  void _connect() {
    if (!_mounted) return;
    setState(() => _snapshot = ResilienceSnapshot.loading<T>());

    _subscription?.cancel();
    _subscription = widget.streamFactory().listen(
      (data) {
        _reconnectAttempts = 0;
        if (_mounted) {
          setState(() => _snapshot = ResilienceSnapshot.success<T>(data));
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!_mounted) return;
        final canRetry = widget.maxReconnectAttempts == 0 ||
            _reconnectAttempts < widget.maxReconnectAttempts;

        if (canRetry) {
          _reconnectAttempts++;
          final delay = _calculateDelay(_reconnectAttempts);
          setState(() => _snapshot = ResilienceSnapshot<T>(
                status: ResilienceStatus.retrying,
                attemptNumber: _reconnectAttempts,
              ));
          Future.delayed(delay, _connect);
        } else {
          setState(() =>
              _snapshot = ResilienceSnapshot.failure<T>(error, stackTrace));
        }
      },
      cancelOnError: true,
    );
  }

  Duration _calculateDelay(int attempt) {
    final ms = widget.reconnectDelay.inMilliseconds * (1 << (attempt - 1).clamp(0, 5));
    return Duration(milliseconds: ms.clamp(0, 30000));
  }

  @override
  Widget build(BuildContext context) {
    if ((_snapshot.isLoading || _snapshot.isRetrying) &&
        widget.loadingBuilder != null) {
      return widget.loadingBuilder!(context);
    }
    if (_snapshot.hasError && widget.errorBuilder != null) {
      return widget.errorBuilder!(
          context, _snapshot.error!, _snapshot.stackTrace);
    }
    return widget.builder(context, _snapshot);
  }
}
