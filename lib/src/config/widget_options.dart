import 'package:flutter/material.dart';

/// Options that control the default loading widget appearance.
class LoadingOptions {
  /// The widget shown while loading. Defaults to a [CircularProgressIndicator].
  final Widget? widget;

  /// The color of the default loading indicator.
  final Color? color;

  const LoadingOptions({this.widget, this.color});
}

/// Options that control the default error widget appearance.
class ErrorOptions {
  /// The widget shown when an error occurs. If null, a default error view is used.
  final Widget Function(BuildContext, Object, StackTrace?)? builder;

  /// Whether to show a retry button in the default error view.
  final bool showRetryButton;

  const ErrorOptions({this.builder, this.showRetryButton = true});
}

/// Options that control retry indicator appearance.
class RetryIndicatorOptions {
  /// Widget shown during a retry attempt. If null, defaults to the loading widget.
  final Widget Function(BuildContext, int attempt)? builder;

  const RetryIndicatorOptions({this.builder});
}
