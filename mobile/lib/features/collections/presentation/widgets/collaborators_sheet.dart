import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/collection.dart';
import '../collections_notifier.dart';

class CollaboratorsSheet extends ConsumerStatefulWidget {
  const CollaboratorsSheet({
    super.key,
    required this.collection,
  });

  final Collection collection;

  @override
  ConsumerState<CollaboratorsSheet> createState() => _CollaboratorsSheetState();
}

class _CollaboratorsSheetState extends ConsumerState<CollaboratorsSheet> {
  final _userIdController = TextEditingController();
  CollectionRole _selectedRole = CollectionRole.editor;
  bool _isInviting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _handleInvite() async {
    final rawInput = _userIdController.text.trim();
    if (rawInput.isEmpty) return;

    setState(() {
      _isInviting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(collectionCollaboratorsProvider(widget.collection.id).notifier)
          .addCollaborator(
            userId: rawInput,
            role: _selectedRole,
          );
      _userIdController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Collaborator invited successfully'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isInviting = false;
        });
      }
    }
  }

  Future<void> _handleRemove(String userId, String email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Collaborator'),
        content: Text('Remove $email from this collection?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref
            .read(collectionCollaboratorsProvider(widget.collection.id).notifier)
            .removeCollaborator(userId);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Color _roleColor(CollectionRole role) {
    switch (role) {
      case CollectionRole.owner:
        return AppTheme.coral;
      case CollectionRole.admin:
        return const Color(0xFFF59E0B);
      case CollectionRole.editor:
        return const Color(0xFF3B82F6);
      case CollectionRole.viewer:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final collaboratorsAsync = ref.watch(collectionCollaboratorsProvider(widget.collection.id));
    final canManage = widget.collection.userRole.canManageMembers;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222D) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.coral.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.group_rounded, color: AppTheme.coral, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reading Group Collaborators',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      widget.collection.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _roleColor(widget.collection.userRole).withAlpha(25),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: _roleColor(widget.collection.userRole).withAlpha(80),
                  ),
                ),
                child: Text(
                  'Your role: ${widget.collection.userRole.label}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _roleColor(widget.collection.userRole),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Collaborator list
          Flexible(
            child: collaboratorsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: AppTheme.coral, strokeWidth: 2),
                ),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Failed to load collaborators: $err',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ),
              data: (members) {
                if (members.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_add_alt_1_outlined,
                          size: 32,
                          color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No collaborators yet',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: isDark ? Colors.white : const Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          canManage
                              ? 'Invite colleagues to read, annotate, and organize papers together.'
                              : 'Only collection managers can invite members.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: members.length,
                  separatorBuilder: (_, __) => const Divider(height: 12),
                  itemBuilder: (context, idx) {
                    final member = members[idx];
                    final initial = member.email.isNotEmpty
                        ? member.email[0].toUpperCase()
                        : 'U';
                    final roleColor = _roleColor(member.role);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: roleColor.withAlpha(40),
                            child: Text(
                              initial,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: roleColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  member.email.isNotEmpty ? member.email : member.userId,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Joined ${_timeAgo(member.createdAt)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? const Color(0xFF9CA3AF)
                                        : const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: roleColor.withAlpha(25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              member.role.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: roleColor,
                              ),
                            ),
                          ),
                          if (canManage) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16),
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                              tooltip: 'Remove',
                              onPressed: () => _handleRemove(member.userId, member.email),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Invite form (Only if manager)
          if (canManage) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Text(
              'Invite Member',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _userIdController,
                    decoration: InputDecoration(
                      hintText: 'User UUID or account email',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<CollectionRole>(
                  value: _selectedRole,
                  underline: const SizedBox(),
                  onChanged: (role) {
                    if (role != null) setState(() => _selectedRole = role);
                  },
                  items: const [
                    DropdownMenuItem(
                      value: CollectionRole.editor,
                      child: Text('Editor', style: TextStyle(fontSize: 12)),
                    ),
                    DropdownMenuItem(
                      value: CollectionRole.admin,
                      child: Text('Admin', style: TextStyle(fontSize: 12)),
                    ),
                    DropdownMenuItem(
                      value: CollectionRole.viewer,
                      child: Text('Viewer', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 11),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.coral,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _isInviting ? null : _handleInvite,
                icon: _isInviting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.person_add_rounded, size: 16),
                label: Text(
                  _isInviting ? 'Inviting...' : 'Add Collaborator',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return 'just now';
  }
}
