import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../collections_notifier.dart';

class AddToCollectionSheet extends ConsumerStatefulWidget {
  const AddToCollectionSheet({
    super.key,
    required this.paperId,
    required this.paperTitle,
  });

  final String paperId;
  final String paperTitle;

  @override
  ConsumerState<AddToCollectionSheet> createState() => _AddToCollectionSheetState();
}

class _AddToCollectionSheetState extends ConsumerState<AddToCollectionSheet> {
  Color _parseHex(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF6366F1);
    }
  }

  void _showCreateInline(BuildContext context) {
    final nameController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('New Collection'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Collection Name',
            hintText: 'e.g., Attention & Transformers',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.coral),
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.of(dialogCtx).pop();

              try {
                final created = await ref
                    .read(collectionsProvider.notifier)
                    .createCollection(name: name);
                await ref
                    .read(collectionsProvider.notifier)
                    .addPaper(created.id, widget.paperId);
                ref.invalidate(paperMembershipsProvider(widget.paperId));
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e')),
                  );
                }
              }
            },
            child: const Text('Create & Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final membershipsAsync = ref.watch(paperMembershipsProvider(widget.paperId));

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222D) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.folder_special_outlined, color: AppTheme.coral, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Add to Collection',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.create_new_folder_outlined, size: 22),
                tooltip: 'New Collection',
                onPressed: () => _showCreateInline(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.paperTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 16),
          membershipsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: AppTheme.coral),
              ),
            ),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Failed to load collections: $err'),
              ),
            ),
            data: (memberships) {
              if (memberships.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(Icons.folder_open_rounded, size: 36, color: Colors.grey),
                        const SizedBox(height: 10),
                        const Text(
                          'No collections created yet',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: AppTheme.coral),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Create First Collection'),
                          onPressed: () => _showCreateInline(context),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: memberships.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final mem = memberships[index];
                  final colColor = _parseHex(mem.color);

                  return CheckboxListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    activeColor: AppTheme.coral,
                    value: mem.containsPaper,
                    title: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: colColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            mem.collectionName,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    onChanged: (checked) async {
                      try {
                        if (checked == true) {
                          await ref
                              .read(collectionsProvider.notifier)
                              .addPaper(mem.collectionId, widget.paperId);
                        } else {
                          await ref
                              .read(collectionsProvider.notifier)
                              .removePaper(mem.collectionId, widget.paperId);
                        }
                        ref.invalidate(paperMembershipsProvider(widget.paperId));
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Update failed: $e')),
                          );
                        }
                      }
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
