import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/paper.dart';

void showPaperExportModal(BuildContext context, PaperDetail paper) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF161922)
        : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _PaperExportSheet(paper: paper),
  );
}

class _PaperExportSheet extends ConsumerStatefulWidget {
  const _PaperExportSheet({required this.paper});

  final PaperDetail paper;

  @override
  ConsumerState<_PaperExportSheet> createState() => _PaperExportSheetState();
}

class _PaperExportSheetState extends ConsumerState<_PaperExportSheet> {
  String _selectedFormat = 'bibtex';
  String? _content;
  bool _isLoading = false;
  String? _error;

  static const _formats = [
    ('bibtex', 'BibTeX'),
    ('apa', 'APA 7th'),
    ('mla', 'MLA 9th'),
    ('chicago', 'Chicago'),
    ('ris', 'RIS'),
    ('markdown', 'Markdown'),
  ];

  @override
  void initState() {
    super.initState();
    _fetchCitation(_selectedFormat);
  }

  Future<void> _fetchCitation(String format) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _selectedFormat = format;
    });

    try {
      final repo = ref.read(paperRepositoryProvider);
      final text = await repo.exportCitation(widget.paper.summary.id, format);
      if (mounted) {
        setState(() {
          _content = text;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to generate citation';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.canaryYellow.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.format_quote_rounded, size: 20, color: AppTheme.canaryYellow),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Cite & Export Paper',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Format Selector Chips
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final f in _formats) ...[
                    ChoiceChip(
                      label: Text(f.$2),
                      selected: _selectedFormat == f.$1,
                      onSelected: (_) => _fetchCitation(f.$1),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Content preview container
            Container(
              constraints: const BoxConstraints(maxHeight: 220, minHeight: 100),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF101216) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF262B38) : const Color(0xFFE5E7EB),
                ),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : (_error != null
                      ? Center(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Color(0xFFFF7675), fontSize: 13),
                          ),
                        )
                      : SingleChildScrollView(
                          child: SelectableText(
                            _content ?? '',
                            style: TextStyle(
                              fontFamily: _selectedFormat == 'bibtex' || _selectedFormat == 'ris'
                                  ? 'monospace'
                                  : null,
                              fontSize: 12.5,
                              height: 1.45,
                              color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
                            ),
                          ),
                        )),
            ),
            const SizedBox(height: 18),

            // Copy & Share buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.canaryYellow,
                      foregroundColor: const Color(0xFF141416),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: _content != null && _content!.isNotEmpty
                        ? () {
                            Clipboard.setData(ClipboardData(text: _content!));
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Copied ${_selectedFormat.toUpperCase()} to clipboard'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        : null,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text(
                      'Copy Citation',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
