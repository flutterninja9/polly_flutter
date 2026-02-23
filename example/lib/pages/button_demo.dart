import 'package:flutter/material.dart';
import 'package:polly_flutter/polly_flutter.dart';

import '../services/demo_api_service.dart';

class ButtonDemo extends StatefulWidget {
  final DemoApiService api;
  const ButtonDemo({super.key, required this.api});

  @override
  State<ButtonDemo> createState() => _ButtonDemoState();
}

class _ButtonDemoState extends State<ButtonDemo> {
  String _status = 'Press the button to submit';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ResilientButton & ResilientForm')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_status, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ResilientButton(
              onAsyncPressed: () async {
                await widget.api.submitForm({'action': 'demo'});
              },
              onSuccess: () => setState(() => _status = 'Success!'),
              onError: (e, _) => setState(() => _status = 'Error: $e'),
              loadingChild: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Submitting…'),
                ],
              ),
              child: const Text('Submit (with retry)'),
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            const Text('ResilientForm', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ResilientForm(
              onSubmit: widget.api.submitForm,
              builder: (context, formState) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                    onSaved: (v) => formState.setValue('name', v),
                  ),
                  const SizedBox(height: 8),
                  if (formState.error != null)
                    Text('${formState.error}',
                        style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: formState.isLoading ? null : formState.submit,
                    child: formState.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit Form'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
