import 'dart:async';

import 'package:flutter/material.dart';
import 'package:polly_dart/polly_dart.dart';

import '../../state/resilience_state.dart';

/// A [ResilientFutureBuilder] variant that adds an in-memory cache layer.
///
/// Data is cached using a [MemoryCacheProvider] with the provided [cacheKey]
/// and optional [cacheTtl]. Subsequent builds within the TTL return cached data
/// without hitting the network, while still applying retry resilience on misses.
///
/// Example:
/// ```dart
/// ResilientCachedBuilder<List<Post>>(
///   cacheKey: 'home_feed',
///   cacheTtl: Duration(minutes: 5),
///   futureFactory: () => api.getPosts(),
///   builder: (context, snapshot) => PostList(posts: snapshot.data ?? []),
/// )
/// ```
class ResilientCachedBuilder<T> extends StatefulWidget {
  final String cacheKey;
  final Future<T> Function() futureFactory;
  final Widget Function(BuildContext, ResilienceSnapshot<T>) builder;
  final Duration cacheTtl;
  final Widget Function(BuildContext)? loadingBuilder;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;
  final void Function(T)? onSuccess;
  final void Function(Object, StackTrace?)? onError;

  const ResilientCachedBuilder({
    super.key,
    required this.cacheKey,
    required this.futureFactory,
    required this.builder,
    this.cacheTtl = const Duration(minutes: 5),
    this.loadingBuilder,
    this.errorBuilder,
    this.onSuccess,
    this.onError,
  });

  @override
  State<ResilientCachedBuilder<T>> createState() =>
      _ResilientCachedBuilderState<T>();
}

class _ResilientCachedBuilderState<T>
    extends State<ResilientCachedBuilder<T>> {
  late ResiliencePipeline _pipeline;
  late MemoryCacheProvider _cache;
  ResilienceSnapshot<T> _snapshot = ResilienceSnapshot.idle<T>();
  bool _mounted = true;

  @override
  void initState() {
    super.initState();
    _cache = MemoryCacheProvider(defaultTtl: widget.cacheTtl);
    _pipeline = ResiliencePipelineBuilder()
        .addCache<T>(CacheStrategyOptions<T>(
          cache: _cache,
          keyGenerator: (_) => widget.cacheKey,
          ttl: widget.cacheTtl,
        ))
        .addRetry(RetryStrategyOptions(
          maxRetryAttempts: 3,
          delay: const Duration(milliseconds: 500),
          backoffType: DelayBackoffType.exponential,
          useJitter: true,
        ))
        .build();
    _execute();
  }

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }

  Future<void> _execute() async {
    if (!_mounted) return;
    setState(() => _snapshot = ResilienceSnapshot.loading<T>());

    final outcome = await _pipeline
        .executeAndCapture<T>((ctx) => widget.futureFactory());

    if (!_mounted) return;

    if (outcome.hasResult) {
      setState(() => _snapshot = ResilienceSnapshot.success<T>(outcome.result));
      widget.onSuccess?.call(outcome.result);
    } else {
      setState(() => _snapshot =
          ResilienceSnapshot.failure<T>(outcome.exception, outcome.stackTrace));
      widget.onError?.call(outcome.exception, outcome.stackTrace);
    }
  }

  /// Invalidates the cache and re-fetches.
  void refresh() {
    _cache.remove(widget.cacheKey);
    _execute();
  }

  @override
  Widget build(BuildContext context) {
    if (_snapshot.isLoading && widget.loadingBuilder != null) {
      return widget.loadingBuilder!(context);
    }
    if (_snapshot.hasError && widget.errorBuilder != null) {
      return widget.errorBuilder!(
          context, _snapshot.error!, _snapshot.stackTrace);
    }
    return widget.builder(context, _snapshot);
  }
}
