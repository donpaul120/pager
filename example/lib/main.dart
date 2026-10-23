import 'package:flutter/material.dart' hide Page;
import 'package:pagerx/pagerx.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'pagerx example',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('pagerx example')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.dynamic_feed),
            title: const Text('Feed'),
            subtitle: const Text('Append on scroll, retry, total count'),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const FeedScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('Chat'),
            subtitle: const Text('Opens mid-conversation, prepends older'),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ChatScreen())),
          ),
        ],
      ),
    );
  }
}

// ─── Fake backend ────────────────────────────────────────────────────────────

/// Stands in for a network API: 100 items, 20 per page, with a short delay.
///
/// The first request for page 2 fails, so the feed shows its retry footer.
class FakeApi {
  static const totalCount = 100;
  bool _failedOnce = false;

  Future<List<String>> fetchPage(int page, int pageSize) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (page == 2 && !_failedOnce) {
      _failedOnce = true;
      throw Exception('Network error (simulated)');
    }
    final start = page * pageSize;
    final end = (start + pageSize).clamp(0, totalCount);
    if (start >= totalCount) return [];
    return [for (var i = start; i < end; i++) 'Item #${i + 1}'];
  }
}

// ─── Feed: append + error handling + external controller ─────────────────────

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  static const _pageSize = 20;
  final _api = FakeApi();

  // Owning the controller lets the app bar read totalItems and lets the
  // footer call retry().
  late final _controller = PagerController<int, String>(
    pagingConfig: PagingConfig(pageSize: _pageSize, initialPageSize: _pageSize),
    source: PagingSource<int, String>(
      localSource: (params) async* {
        final page = params.key ?? 0;
        final items = await _api.fetchPage(page, params.loadSize);
        yield Page(
          items,
          page > 0 ? page - 1 : null,
          // A short page means there is nothing after it.
          items.length == params.loadSize ? page + 1 : null,
          totalItems: FakeApi.totalCount,
        );
      },
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder<PagingData<String>>(
          valueListenable: _controller,
          builder: (_, data, __) =>
              Text('Feed (${data.itemCount} of ${data.totalItems})'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _controller.refresh,
          ),
        ],
      ),
      body: Pager<int, String>.withController(
        controller: _controller,
        builder: (context, data) {
          if (data.isLoading && data.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (data.refreshError != null) {
            return _ErrorView(
              message: '${data.refreshError}',
              onRetry: _controller.retry,
            );
          }
          if (data.isEmpty) {
            return const Center(child: Text('Nothing here yet'));
          }
          return ListView.builder(
            itemCount: data.itemCount + 1, // +1 for the footer
            itemBuilder: (_, i) {
              if (i < data.itemCount) {
                return ListTile(title: Text(data.data[i]));
              }
              return _Footer(data: data, onRetry: _controller.retry);
            },
          );
        },
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.data, required this.onRetry});

  final PagingData<String> data;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (data.isAppending) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (data.appendError != null) {
      return TextButton(
        onPressed: onRetry,
        child: const Text('Loading more failed — tap to retry'),
      );
    }
    if (data.endOfPaginationReached) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text("You've reached the end")),
      );
    }
    return const SizedBox(height: 48);
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

// ─── Chat: start in the middle, prepend older pages ──────────────────────────

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _pageSize = 15;
  static const _totalPages = 10;

  /// The page holding the "last read" message — the chat opens here.
  static const _startPage = 5;

  late final _controller = PagerController<int, String>(
    pagingConfig: PagingConfig(pageSize: _pageSize, initialPageSize: _pageSize),
    source: PagingSource<int, String>(
      localSource: (params) async* {
        // The initial load has no key: start in the middle of the history.
        final page = params.key ?? _startPage;
        await Future<void>.delayed(const Duration(milliseconds: 500));
        final first = page * _pageSize;
        yield Page(
          [for (var i = 0; i < _pageSize; i++) 'Message ${first + i + 1}'],
          page > 0 ? page - 1 : null, // prevKey drives prepend
          page < _totalPages - 1 ? page + 1 : null, // nextKey drives append
        );
      },
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          // Manual trigger, for when scroll detection isn't enough.
          IconButton(
            tooltip: 'Load older',
            icon: const Icon(Icons.history),
            onPressed: _controller.triggerPrepend,
          ),
        ],
      ),
      body: Pager<int, String>.withController(
        controller: _controller,
        builder: (context, data) {
          if (data.isLoading && data.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          final prepend = data.loadStates?.prepend;
          return Column(
            children: [
              if (prepend is Loading) const LinearProgressIndicator(),
              if (prepend != null && prepend.endOfPaginationReached)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Start of conversation'),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: data.itemCount,
                  itemBuilder: (_, i) => ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(data.data[i]),
                  ),
                ),
              ),
              if (data.isAppending) const LinearProgressIndicator(),
            ],
          );
        },
      ),
    );
  }
}
