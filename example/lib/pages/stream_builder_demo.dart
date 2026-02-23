import 'package:flutter/material.dart';
import 'package:polly_flutter/polly_flutter.dart';

import '../services/demo_api_service.dart';

class StreamBuilderDemo extends StatelessWidget {
  final DemoApiService api;
  const StreamBuilderDemo({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ResilientStreamBuilder')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ResilientStreamBuilder<String>(
          streamFactory: api.liveUpdates,
          builder: (context, snapshot) {
            if (snapshot.isLoading || snapshot.isRetrying) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(snapshot.isRetrying
                      ? 'Reconnecting… attempt ${snapshot.attemptNumber}'
                      : 'Connecting to stream…'),
                ],
              );
            }
            if (snapshot.hasError) {
              return Center(child: Text('Stream failed: ${snapshot.error}'));
            }
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi, size: 48, color: Colors.green),
                  const SizedBox(height: 12),
                  Text(snapshot.data ?? 'Waiting for data…',
                      textAlign: TextAlign.center),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
