import 'package:flutter/material.dart';
import 'package:polly_flutter/polly_flutter.dart';

import '../services/demo_api_service.dart';

class InfiniteScrollDemo extends StatelessWidget {
  final DemoApiService api;
  const InfiniteScrollDemo({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ResilientInfiniteScroll')),
      body: ResilientInfiniteScroll<Map<String, String>>(
        fetchPage: (page) => api.fetchPosts(page: page),
        pageSize: 10,
        itemBuilder: (context, post) => ListTile(
          leading: CircleAvatar(child: Text(post['id']!)),
          title: Text(post['title']!),
          subtitle: Text(post['body']!),
        ),
      ),
    );
  }
}
