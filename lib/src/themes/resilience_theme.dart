import 'package:flutter/material.dart';

/// Theme data for polly_flutter widgets.
@immutable
class ResilienceThemeData {
  /// Color used for loading indicators.
  final Color loadingColor;

  /// Color used for error states.
  final Color errorColor;

  /// Color used for success/online states.
  final Color successColor;

  /// Color used for offline/disconnected states.
  final Color offlineColor;

  /// TextStyle for error messages.
  final TextStyle errorTextStyle;

  /// TextStyle for status messages (retrying, rate-limited, etc.).
  final TextStyle statusTextStyle;

  const ResilienceThemeData({
    this.loadingColor = Colors.blue,
    this.errorColor = Colors.red,
    this.successColor = Colors.green,
    this.offlineColor = Colors.orange,
    this.errorTextStyle = const TextStyle(color: Colors.red),
    this.statusTextStyle = const TextStyle(color: Colors.grey),
  });

  ResilienceThemeData copyWith({
    Color? loadingColor,
    Color? errorColor,
    Color? successColor,
    Color? offlineColor,
    TextStyle? errorTextStyle,
    TextStyle? statusTextStyle,
  }) {
    return ResilienceThemeData(
      loadingColor: loadingColor ?? this.loadingColor,
      errorColor: errorColor ?? this.errorColor,
      successColor: successColor ?? this.successColor,
      offlineColor: offlineColor ?? this.offlineColor,
      errorTextStyle: errorTextStyle ?? this.errorTextStyle,
      statusTextStyle: statusTextStyle ?? this.statusTextStyle,
    );
  }
}

/// An [InheritedWidget] that provides [ResilienceThemeData] to the widget tree.
class ResilienceTheme extends InheritedWidget {
  final ResilienceThemeData data;

  const ResilienceTheme({
    super.key,
    required this.data,
    required super.child,
  });

  /// Returns the nearest [ResilienceThemeData] in the widget tree, or a default
  /// instance if none is found.
  static ResilienceThemeData of(BuildContext context) {
    final theme =
        context.dependOnInheritedWidgetOfExactType<ResilienceTheme>();
    return theme?.data ?? const ResilienceThemeData();
  }

  @override
  bool updateShouldNotify(ResilienceTheme oldWidget) => data != oldWidget.data;
}
