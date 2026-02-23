import 'package:flutter/material.dart';
import 'package:polly_dart/polly_dart.dart';

/// A [Form] wrapper that submits through a [ResiliencePipeline], managing
/// validation, loading state, and error display automatically.
///
/// Example:
/// ```dart
/// ResilientForm(
///   onSubmit: (data) => api.register(data['email'], data['password']),
///   builder: (context, state) => Column(
///     children: [
///       TextFormField(onSaved: (v) => state.setValue('email', v)),
///       if (state.error != null) Text(state.error.toString()),
///       ElevatedButton(
///         onPressed: state.isLoading ? null : state.submit,
///         child: const Text('Register'),
///       ),
///     ],
///   ),
/// )
/// ```
class ResilientForm extends StatefulWidget {
  /// Called with the form field values when the form is valid and submitted.
  final Future<void> Function(Map<String, dynamic> data)? onSubmit;

  /// Optional pipeline customizer.
  final ResiliencePipelineBuilder Function(ResiliencePipelineBuilder)?
      pipelineBuilder;

  /// Builder receives the current [ResilientFormState] to expose loading/error
  /// state and the [submit] callback.
  final Widget Function(BuildContext, ResilientFormState) builder;

  /// External form key. One is created internally if not provided.
  final GlobalKey<FormState>? formKey;

  const ResilientForm({
    super.key,
    required this.builder,
    this.onSubmit,
    this.pipelineBuilder,
    this.formKey,
  });

  @override
  State<ResilientForm> createState() => _ResilientFormWidgetState();
}

/// Exposes form submission state to the [ResilientForm.builder].
class ResilientFormState {
  final bool isLoading;
  final Object? error;
  final StackTrace? stackTrace;
  final Future<void> Function() submit;
  final Map<String, dynamic> _values = {};

  ResilientFormState({
    required this.isLoading,
    required this.error,
    required this.stackTrace,
    required this.submit,
  });

  void setValue(String key, dynamic value) => _values[key] = value;
  Map<String, dynamic> get values => Map.unmodifiable(_values);
}

class _ResilientFormWidgetState extends State<ResilientForm> {
  late GlobalKey<FormState> _formKey;
  late ResiliencePipeline _pipeline;
  bool _loading = false;
  Object? _error;
  StackTrace? _stackTrace;
  late ResilientFormState _formState;

  @override
  void initState() {
    super.initState();
    _formKey = widget.formKey ?? GlobalKey<FormState>();
    _buildPipeline();
    _updateFormState();
  }

  @override
  void didUpdateWidget(ResilientForm oldWidget) {
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
            .addTimeout(const Duration(seconds: 15))
            .addRetry(RetryStrategyOptions(
              maxRetryAttempts: 2,
              delay: const Duration(milliseconds: 500),
              backoffType: DelayBackoffType.exponential,
            ))
            .build();
  }

  void _updateFormState() {
    _formState = ResilientFormState(
      isLoading: _loading,
      error: _error,
      stackTrace: _stackTrace,
      submit: _submit,
    );
  }

  Future<void> _submit() async {
    if (_loading) return;
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;
    formState.save();

    setState(() {
      _loading = true;
      _error = null;
      _stackTrace = null;
      _updateFormState();
    });

    final outcome = await _pipeline.executeAndCapture<void>(
        (_) => widget.onSubmit!(_formState._values));

    if (!mounted) return;

    setState(() {
      _loading = false;
      if (outcome.hasException) {
        _error = outcome.exception;
        _stackTrace = outcome.stackTrace;
      }
      _updateFormState();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: widget.builder(context, _formState),
    );
  }
}
