import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/annotation.dart';
import '../annotation_colors.dart';

/// Dialog to create or edit a paper text highlight and margin note.
class AddAnnotationDialog extends StatefulWidget {
  const AddAnnotationDialog({
    super.key,
    required this.paperId,
    required this.selectedText,
    this.initialNote = '',
    this.initialColor = AnnotationColor.yellow,
    this.pageNumber = 1,
    this.sectionIndex = 0,
    this.isEditing = false,
  });

  final String paperId;
  final String selectedText;
  final String initialNote;
  final AnnotationColor initialColor;
  final int pageNumber;
  final int sectionIndex;
  final bool isEditing;

  @override
  State<AddAnnotationDialog> createState() => _AddAnnotationDialogState();
}

class _AddAnnotationDialogState extends State<AddAnnotationDialog> {
  late final TextEditingController _noteController;
  late AnnotationColor _selectedColor;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.initialNote);
    _selectedColor = widget.initialColor;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF161922) : Colors.white;
    final borderColor = isDark ? const Color(0xFF262A36) : const Color(0xFFE5E7EB);

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _selectedColor.tint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.format_quote_rounded,
                    size: 18,
                    color: _selectedColor.color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isEditing ? 'EDIT MARGIN NOTE' : 'NEW HIGHLIGHT & NOTE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: isDark ? AppTheme.coral : const Color(0xFF141416),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Page ${widget.pageNumber}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Highlighted quote preview
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _selectedColor.tint,
                borderRadius: BorderRadius.circular(10),
                border: Border(
                  left: BorderSide(color: _selectedColor.color, width: 4),
                ),
              ),
              child: Text(
                widget.selectedText.trim().isEmpty ? '(No text selected)' : widget.selectedText.trim(),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                  color: isDark ? Colors.white70 : const Color(0xFF374151),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Color palette selector
            Text(
              'HIGHLIGHT COLOR',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: AnnotationColor.values.map((color) {
                final isSelected = color == _selectedColor;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: InkWell(
                    onTap: () => setState(() => _selectedColor = color),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color.color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? (isDark ? Colors.white : Colors.black)
                              : Colors.transparent,
                          width: isSelected ? 2.5 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.color.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Note input field
            Text(
              'MARGIN NOTE (OPTIONAL)',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLines: 3,
              style: const TextStyle(fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'Record insights, synthesis, or follow-up questions…',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F1117) : const Color(0xFFF9FAFB),
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _selectedColor.color, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isSaving
                      ? null
                      : () {
                          setState(() => _isSaving = true);
                          Navigator.of(context).pop({
                            'note': _noteController.text.trim(),
                            'color': _selectedColor,
                          });
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: _selectedColor.color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(widget.isEditing ? 'Save Changes' : 'Save Highlight'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
