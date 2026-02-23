import 'package:flutter/material.dart';
import 'package:polly_dart/polly_dart.dart';

import '../../state/resilience_state.dart';

/// A [ListView] with resilient infinite-scroll pagination.
///
/// Fetches the next page through a [ResiliencePipeline] whenever the user
/// scrolls near the bottom. Supports pull-to-refresh and per-page error recovery.
///
/// Example:
/// ```dart
/// ResilientInfiniteScroll<Post>(
///   fetchPage: (page) => api.getPosts(page: page),
///   itemBuilder: (context, post) => PostCard(post: post),
/// )
/// ```
class ResilientInfiniteScroll<T> extends StatefulWidget {
  /// Called with the 1-based page number; must return items for that page.
  final Future<List<T>> Function(int page) fetchPage;

  /// Builds a single list item.
  final Widget Function(BuildContext, T) itemBuilder;

  /// Optional pipeline customizer applied to each page fetch.
  final ResiliencePipelineBuilder Function(ResiliencePipelineBuilder)?
      pipelineBuilder;

  /// Number of items in a full page. Used to detect end-of-list.
  final int pageSize;

  /// Scroll offset (pixels from bottom) that triggers the next page load.
  final double loadMoreThreshold;

  /// Widget shown beneath the list while loading the next page.
  final Widget? loadingIndicator;

  /// Widget shown when a page fetch fails, with a retry button.
  final Widget Function(BuildContext, Object, VoidCallback retry)? errorBuilder;

  /// Widget shown when the list is empty after the first fetch.
  final Widget? emptyWidget;

  const ResilientInfiniteScroll({
    super.key,
    required this.fetchPage,
    required this.itemBuilder,
    this.pipelineBuilder,
    this.pageSize = 20,
    this.loadMoreThreshold = 200.0,
    this.loadingIndicator,
    this.errorBuilder,
    this.emptyWidget,
  });

  @override
  State<ResilientInfiniteScroll<T>> createState() =>
      _ResilientInfiniteScrollState<T>();
}

class _ResilientInfiniteScrollState<T>
    extends State<ResilientInfiniteScroll<T>> {
  late ResiliencePipeline _pipeline;
  final ScrollController _scrollController = ScrollController();

  final List<T> _items = [];
  int _page = 1;
  bool _isLoadingPage = false;
  bool _hasMore = true;
  Object? _pageError;

  // Overall first-load state
  ResilienceStatus _status = ResilienceStatus.loading;

  @override
  void initState() {
    super.initState();
    _buildPipeline();
    _scrollController.addListener(_onScroll);
    _loadPage();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
            ))
            .addTimeout(const Duration(seconds: 15))
            .build();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final remaining = _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;
    if (remaining <= widget.loadMoreThreshold && _hasMore && !_isLoadingPage) {
      _loadPage();
    }
  }

  Future<void> _loadPage() async {
    if (_isLoadingPage || !_hasMore) return;
    setState(() {
      _isLoadingPage = true;
      _pageError = null;
    });

    final outcome = await _pipeline
        .executeAndCapture<List<T>>((_) => widget.fetchPage(_page));

    if (!mounted) return;

    if (outcome.hasResult) {
      final newItems = outcome.result;
      setState(() {
        _items.addAll(newItems);
        _page++;
        _hasMore = newItems.length >= widget.pageSize;
        _isLoadingPage = false;
        _status = ResilienceStatus.success;
      });
    } else {
      setState(() {
        _isLoadingPage = false;
        _pageError = outcome.exception;
        if (_items.isEmpty) _status = ResilienceStatus.error;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _page = 1;
      _hasMore = true;
      _pageError = null;
      _status = ResilienceStatus.loading;
    });
    await _loadPage();
  }

  @override
  Widget build(BuildContext context) {
    if (_status == ResilienceStatus.loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_status == ResilienceStatus.error && _items.isEmpty) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(context, _pageError!, _refresh);
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error: $_pageError'),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _refresh, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_items.isEmpty && _status == ResilienceStatus.success) {
      return widget.emptyWidget ??
          const Center(child: Text('No items found.'));
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _items.length + (_isLoadingPage || _pageError != null ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < _items.length) {
            return widget.itemBuilder(context, _items[index]);
          }
          // Footer: loading or per-page error
          if (_pageError != null) {
            if (widget.errorBuilder != null) {
              return widget.errorBuilder!(context, _pageError!, _loadPage);
            }
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Failed to load more: $_pageError'),
                  TextButton(
                      onPressed: _loadPage, child: const Text('Retry')),
                ],
              ),
            );
          }
          return widget.loadingIndicator ??
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
        },
      ),
    );
  }
}
