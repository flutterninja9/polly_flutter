import 'package:flutter/material.dart';
import 'package:polly_flutter/polly_flutter.dart';

import '../services/demo_api_service.dart';

class FutureBuilderDemo extends StatelessWidget {
  final DemoApiService api;
  const FutureBuilderDemo({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ResilientFutureBuilder')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ResilientFutureBuilder<String>(
          futureFactory: api.fetchWelcomeMessage,
          builder: (context, snapshot) {
            if (snapshot.isLoading || snapshot.isRetrying) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(
                    snapshot.isRetrying
                        ? 'Retrying... attempt ${snapshot.attemptNumber}'
                        : 'Loading…',
                  ),
                ],
              );
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            return Center(
              child: Text(
                snapshot.data ?? '',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
            );
          },
        ),
      ),
    );
  }
}
