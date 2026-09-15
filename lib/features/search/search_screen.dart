import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import 'search_repository.dart';

/// Cross-case search (Phase 4): one field, every case the caller can
/// already read — rooms, discussions, timeline, tasks, evidence
/// filenames (0022; RLS scopes the RPC, redaction masks snippets).
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(searchQueryProvider.notifier).run(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchQueryProvider);
    final error = state.error;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search all cases'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              key: const Key('search-field'),
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Search',
                hintText: 'e.g. shell company ledger',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                        },
                      ),
              ),
              onChanged: _onChanged,
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                error,
                style: text.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          Expanded(
            child: state.query.trim().length < 2
                ? _hint(text)
                : state.hits.isEmpty
                ? Center(
                    child: Text(
                      'No matches in your cases.',
                      style: text.titleMedium,
                    ),
                  )
                : ListView.builder(
                    // Rules.md §9: lazy list — the RPC caps at 50 rows,
                    // this stays bounded for any room count.
                    itemCount: state.hits.length,
                    itemBuilder: (context, index) =>
                        _HitTile(hit: state.hits[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _hint(TextTheme text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.4),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Search across every room you\'re in — messages, case '
              'events, tasks, and evidence names.',
              style: text.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _HitTile extends StatelessWidget {
  const _HitTile({required this.hit});

  final SearchHit hit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: InkWell(
        // Deep-link into the room; panes are one tap away from there.
        onTap: () => context.push('/rooms/${hit.roomId}?type=${hit.caseType}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(switch (hit.objectType) {
                'discussion' => Icons.forum_outlined,
                'timeline' => Icons.timeline,
                'task' => Icons.checklist,
                'evidence' => Icons.description_outlined,
                _ => Icons.folder_outlined, // 'room'
              }, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hit.roomName, style: text.bodyLarge),
                    const SizedBox(height: AppSpacing.xxs),
                    if (hit.snippet.isNotEmpty && hit.snippet != hit.roomName)
                      Text(
                        hit.snippet,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium?.copyWith(
                          color: text.bodyMedium?.color?.withValues(alpha: 0.8),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${hit.objectType} · ${hit.createdAt.toLocal()}'
                          .split('.')
                          .first,
                      style: text.bodyMedium?.copyWith(
                        color: text.bodyMedium?.color?.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
