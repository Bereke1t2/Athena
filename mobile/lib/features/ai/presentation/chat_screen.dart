import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/ai_models.dart';
import 'chat_notifier.dart';

/// "Chat with this paper": grounded, streaming answers with expandable
/// citation quotes.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.paperId, this.paperTitle});

  final String paperId;
  final String? paperTitle;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    ref.read(chatThreadProvider(widget.paperId).notifier).send(text);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  void _scrollToEnd() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent + 240,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(chatThreadProvider(widget.paperId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Chat · ${widget.paperTitle ?? 'paper'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: state.messages.isEmpty && state.streaming.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.forum_outlined,
                                size: 44, color: theme.colorScheme.outline),
                            const SizedBox(height: 12),
                            Text('Ask anything about this paper',
                                style: theme.textTheme.titleMedium),
                            const SizedBox(height: 6),
                            Text(
                              'Answers come only from the paper itself,\nwith citations to the source text.',
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
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: state.messages.length +
                          (state.streaming.isNotEmpty ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i == state.messages.length) {
                          return _Bubble(
                            message: ChatMessage(
                              id: 'streaming', role: 'assistant', content: state.streaming,
                            ),
                            streaming: true,
                          );
                        }
                        return _Bubble(message: state.messages[i]);
                      },
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      enabled: !state.sending,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Ask about methods, results…',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: state.sending ? null : _send,
                    icon: state.sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.streaming = false});

  final ChatMessage message;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              streaming ? '${message.content}▍' : message.content,
              style: theme.textTheme.bodyMedium,
            ),
            if (message.citations.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (var i = 0; i < message.citations.length; i++)
                    _CitationChip(index: i + 1, citation: message.citations[i]),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CitationChip extends StatelessWidget {
  const _CitationChip({required this.index, required this.citation});

  final int index;
  final ChatCitation citation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ActionChip(
      avatar: CircleAvatar(
        radius: 8,
        backgroundColor: theme.colorScheme.secondaryContainer,
        child: Text('$index',
            style: theme.textTheme.labelSmall
                ?.copyWith(fontSize: 9, fontWeight: FontWeight.w700)),
      ),
      label: Text(
        citation.sectionPath.isNotEmpty ? citation.sectionPath : 'source',
        style: theme.textTheme.labelSmall,
      ),
      tooltip: citation.quote,
      visualDensity: VisualDensity.compact,
      onPressed: () {
        showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Source excerpt',
                      style: Theme.of(context).textTheme.titleMedium),
                  if (citation.sectionPath.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(citation.sectionPath,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            )),
                  ],
                  const SizedBox(height: 12),
                  SelectableText(citation.quote,
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
