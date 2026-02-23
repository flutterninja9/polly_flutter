import 'package:flutter/material.dart';
import 'package:polly_flutter/polly_flutter.dart';

import 'pages/button_demo.dart';
import 'pages/future_builder_demo.dart';
import 'pages/infinite_scroll_demo.dart';
import 'pages/stream_builder_demo.dart';
import 'services/demo_api_service.dart';

void main() {
  runApp(const PollyFlutterExampleApp());
}

class PollyFlutterExampleApp extends StatelessWidget {
  const PollyFlutterExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ResilienceTheme(
      data: const ResilienceThemeData(),
      child: MaterialApp(
        title: 'polly_flutter Demo',
        theme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          useMaterial3: true,
        ),
        home: const _HomePage(),
      ),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    final api = DemoApiService();
    return Scaffold(
      appBar: AppBar(title: const Text('polly_flutter Demo')),
      body: ListView(
        children: [
          _DemoTile(
            title: 'ResilientFutureBuilder',
            subtitle: 'Auto-retry a Future with progress feedback',
            icon: Icons.refresh,
            page: FutureBuilderDemo(api: api),
          ),
          _DemoTile(
            title: 'ResilientInfiniteScroll',
            subtitle: 'Paginated list with per-page error recovery',
            icon: Icons.list,
            page: InfiniteScrollDemo(api: api),
          ),
          _DemoTile(
            title: 'ResilientButton & Form',
            subtitle: 'Debounced button & form with resilient submit',
            icon: Icons.touch_app,
            page: ButtonDemo(api: api),
          ),
          _DemoTile(
            title: 'ResilientStreamBuilder',
            subtitle: 'Auto-reconnecting stream with retry feedback',
            icon: Icons.stream,
            page: StreamBuilderDemo(api: api),
          ),
        ],
      ),
    );
  }
}

class _DemoTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget page;

  const _DemoTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.page,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => page),
      ),
    );
  }
}
