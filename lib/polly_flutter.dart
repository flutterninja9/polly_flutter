/// polly_flutter — Flutter widgets with built-in resilience via polly_dart.
///
/// Import this library to access all resilient widgets:
/// ```dart
/// import 'package:polly_flutter/polly_flutter.dart';
/// ```
library;

// State
export 'src/state/resilience_state.dart';
export 'src/state/state_extensions.dart';

// Theme
export 'src/themes/resilience_theme.dart';

// Config
export 'src/config/default_pipelines.dart';
export 'src/config/widget_options.dart';

// Widgets — builders
export 'src/widgets/builders/resilient_future_builder.dart';
export 'src/widgets/builders/resilient_stream_builder.dart';
export 'src/widgets/builders/resilient_cached_builder.dart';

// Widgets — images
export 'src/widgets/images/resilient_network_image.dart';

// Widgets — interaction
export 'src/widgets/interaction/resilient_button.dart';
export 'src/widgets/interaction/resilient_form.dart';
export 'src/widgets/interaction/resilient_refresh_indicator.dart';

// Widgets — lists
export 'src/widgets/lists/resilient_infinite_scroll.dart';
export 'src/widgets/lists/resilient_list_view.dart';

// Widgets — connectivity
export 'src/widgets/connectivity/resilient_connectivity_wrapper.dart';

// Widgets — utils
export 'src/widgets/utils/resilient_container.dart';
