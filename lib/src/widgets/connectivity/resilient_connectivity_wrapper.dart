import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// Wraps child widgets and switches between [onlineChild] and [offlineChild]
/// based on network connectivity status.
///
/// Example:
/// ```dart
/// ResilientConnectivityWrapper(
///   onlineChild: MyApp(),
///   offlineChild: const OfflineBanner(),
/// )
/// ```
class ResilientConnectivityWrapper extends StatefulWidget {
  /// Widget displayed when a network connection is available.
  final Widget onlineChild;

  /// Widget displayed when no network connection is available.
  final Widget offlineChild;

  /// Optional builder that receives the raw [List<ConnectivityResult>] and
  /// returns a custom widget — overrides [onlineChild] / [offlineChild].
  final Widget Function(BuildContext, List<ConnectivityResult>)? statusBuilder;

  /// Invoked when connectivity changes. `true` = online, `false` = offline.
  final void Function(bool isOnline)? onConnectivityChanged;

  const ResilientConnectivityWrapper({
    super.key,
    required this.onlineChild,
    required this.offlineChild,
    this.statusBuilder,
    this.onConnectivityChanged,
  });

  @override
  State<ResilientConnectivityWrapper> createState() =>
      _ResilientConnectivityWrapperState();
}

class _ResilientConnectivityWrapperState
    extends State<ResilientConnectivityWrapper> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  List<ConnectivityResult> _results = [ConnectivityResult.none];

  @override
  void initState() {
    super.initState();
    _checkInitial();
    _subscription =
        _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _checkInitial() async {
    final results = await _connectivity.checkConnectivity();
    if (mounted) _onConnectivityChanged(results);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final wasOnline = _isOnline(_results);
    final isOnline = _isOnline(results);
    setState(() => _results = results);
    if (wasOnline != isOnline) {
      widget.onConnectivityChanged?.call(isOnline);
    }
  }

  bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  @override
  Widget build(BuildContext context) {
    if (widget.statusBuilder != null) {
      return widget.statusBuilder!(context, _results);
    }
    return _isOnline(_results) ? widget.onlineChild : widget.offlineChild;
  }
}
