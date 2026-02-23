import 'package:flutter/material.dart';
import 'package:polly_dart/polly_dart.dart';

import '../../state/resilience_state.dart';

/// A [ListView] that loads its items through a [ResiliencePipeline] and
/// exposes loading / error / success states with pull-to-refresh support.
///
/// Example:
/// ```dart
/// ResilientListView<User>(
///   dataLoader: () => api.getUsers(),
///   itemBuilder: (context, user) => UserTile(user: user),
/// )
/// ```
class ResilientListView<T> extends StatefulWidget {
  /// Fetches the full list of items.
  final Future<List<T>> Function() dataLoader;

  /// Builds a single item widget.
  final Widget Function(BuildContext, T) itemBuilder;

  /// Optional pipeline customizer. Defaults to retry with exponential backoff.
  final ResiliencePipelineBuilder Function(ResiliencePipelineBuilder)?
      pipelineBuilder;

  final Widget Function(BuildContext)? loadingBuilder;
  final Widget Function(BuildContext, Object, StackTrace?, VoidCallback retry)?
      errorBuilder;
  final Widget? emptyWidget;

  /// Whether to enable pull-to-refresh.
  final bool enableRefresh;

  const ResilientListView({
    super.key,
    required this.dataLoader,
    required this.itemBuilder,
    this.pipelineBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.emptyWidget,
    this.enableRefresh = true,
  });

  @override
  State<ResilientListView<T>> createState() => _ResilientListViewState<T>();
}

class _ResilientListViewState<T> extends State<ResilientListView<T>> {
  late ResiliencePipeline _pipeline;
  ResilienceSnapshot<List<T>> _snapshot = ResilienceSnapshot.idle<List<T>>();

  @override
  void initState() {
    super.initState();
    _buildPipeline();
    _load();
  }

  void _buildPipeline() {
    final b = ResiliencePipelineBuilder();
    _pipeline = widget.pipelineBuilder != null
        ? widget.pipelineBuilder!(b).build()
        : b
            .addRetry(RetryStrategyOptions(
              maxRetryAttempts: 3,
              delay: const Duration(milliseconds: 500),
              backoffType: DelayBackoffType.exponential,
              useJitter: true,
            ))
            .build();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _snapshot = ResilienceSnapshot.loading<List<T>>());

    final outcome =
        await _pipeline.executeAndCapture<List<T>>((_) => widget.dataLoader());

    if (!mounted) return;
    setState(() {
      _snapshot = outcome.hasResult
          ? ResilienceSnapshot.success<List<T>>(outcome.result)
          : ResilienceSnapshot.failure<List<T>>(
              outcome.exception, outcome.stackTrace);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_snapshot.isLoading) {
      return widget.loadingBuilder != null
          ? widget.loadingBuilder!(context)
          : const Center(child: CircularProgressIndicator());
    }

    if (_snapshot.hasError) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(
            context, _snapshot.error!, _snapshot.stackTrace, _load);
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error: ${_snapshot.error}'),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final items = _snapshot.data ?? [];
    if (items.isEmpty) {
      return widget.emptyWidget ?? const Center(child: Text('No items found.'));
    }

    final listView = ListView.builder(
      itemCount: items.length,
      itemBuilder: (ctx, i) => widget.itemBuilder(ctx, items[i]),
    );

    return widget.enableRefresh
        ? RefreshIndicator(onRefresh: _load, child: listView)
        : listView;
  }
}
