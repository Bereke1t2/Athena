import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/prefs/saved_papers.dart';

/// The reading list: papers the user saved locally.
class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final saved = ref.watch(savedPapersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Saved')),
      body: saved.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bookmark_border,
                        size: 48, color: theme.colorScheme.outline),
                    const SizedBox(height: 12),
                    Text('Nothing saved yet',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Tap the bookmark on any paper to keep it here for offline reading.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: saved.length,
              itemBuilder: (context, i) {
                final p = saved[i];
                return Card(
                  child: ListTile(
                    title: Text(p.title,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      [
                        if (p.venue.isNotEmpty) p.venue,
                        if (p.year > 0) '${p.year}',
                        '${p.citedByCount} citations',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.bookmark),
                      tooltip: 'Remove',
                      onPressed: () =>
                          ref.read(savedPapersProvider.notifier).remove(p.id),
                    ),
                    onTap: () => context.push('/papers/${p.id}'),
                  ),
                );
              },
            ),
    );
  }
}
