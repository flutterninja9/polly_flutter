import 'dart:math';

/// A fake API service that simulates network behaviour for the demo app.
class DemoApiService {
  final _random = Random();

  /// Simulates a network delay and occasionally fails.
  Future<T> _simulate<T>(T Function() producer,
      {double failureRate = 0.3}) async {
    await Future.delayed(Duration(milliseconds: 400 + _random.nextInt(600)));
    if (_random.nextDouble() < failureRate) {
      throw Exception('Simulated network error');
    }
    return producer();
  }

  Future<String> fetchWelcomeMessage() =>
      _simulate(() => 'Welcome to polly_flutter!');

  Future<List<Map<String, String>>> fetchPosts({int page = 1}) =>
      _simulate(() => List.generate(
            10,
            (i) => {
              'id': '${(page - 1) * 10 + i + 1}',
              'title': 'Post ${(page - 1) * 10 + i + 1}',
              'body': 'Body of post ${(page - 1) * 10 + i + 1}.',
            },
          ));

  Future<void> submitForm(Map<String, dynamic> data) =>
      _simulate(() {}, failureRate: 0.2);

  Stream<String> liveUpdates() async* {
    var count = 0;
    while (true) {
      await Future.delayed(const Duration(seconds: 2));
      if (_random.nextDouble() < 0.1) throw Exception('Stream error');
      yield 'Update #${++count} at ${DateTime.now().toIso8601String()}';
    }
  }
}
