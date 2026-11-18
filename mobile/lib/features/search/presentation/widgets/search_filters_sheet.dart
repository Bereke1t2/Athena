import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/search.dart';

class SearchFiltersSheet extends StatefulWidget {
  const SearchFiltersSheet({
    super.key,
    required this.currentFilters,
    required this.onApply,
  });

  final SearchFilters currentFilters;
  final ValueChanged<SearchFilters> onApply;

  @override
  State<SearchFiltersSheet> createState() => _SearchFiltersSheetState();
}

class _SearchFiltersSheetState extends State<SearchFiltersSheet> {
  late SearchMode _mode;
  late SearchSort _sort;
  late bool? _openAccess;
  late int? _minCitations;
  late DateTime? _publishedAfter;
  late String? _source;

  @override
  void initState() {
    super.initState();
    _mode = widget.currentFilters.mode;
    _sort = widget.currentFilters.sort;
    _openAccess = widget.currentFilters.openAccess;
    _minCitations = widget.currentFilters.minCitations;
    _publishedAfter = widget.currentFilters.publishedAfter;
    _source = widget.currentFilters.source;
  }

  void _reset() {
    setState(() {
      _mode = SearchMode.hybrid;
      _sort = SearchSort.relevance;
      _openAccess = null;
      _minCitations = null;
      _publishedAfter = null;
      _source = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                child: const Icon(Icons.tune_rounded, color: AppTheme.coral, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Search Filters & Engine',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              TextButton(
                onPressed: _reset,
                child: const Text('Reset', style: TextStyle(fontSize: 12, color: AppTheme.coral)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 16),

          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                // 1. Search Mode Section
                _buildSectionHeader('SEARCH ENGINE / RETRIEVAL MODE', isDark),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: SearchMode.values.map((mode) {
                    final isSelected = _mode == mode;
                    return ChoiceChip(
                      label: Text(mode.label),
                      selected: isSelected,
                      selectedColor: AppTheme.coral,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      ),
                      onSelected: (_) => setState(() => _mode = mode),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // 2. Sort Section
                _buildSectionHeader('SORT ORDER', isDark),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildSortChip('Relevance', SearchSort.relevance, isDark),
                    _buildSortChip('Newest First', SearchSort.newest, isDark),
                    _buildSortChip('Most Cited', SearchSort.citations, isDark),
                  ],
                ),

                const SizedBox(height: 20),

                // 3. Minimum Citations
                _buildSectionHeader('MINIMUM CITATIONS', isDark),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildCitationChip('Any', null, isDark),
                    _buildCitationChip('10+', 10, isDark),
                    _buildCitationChip('50+', 50, isDark),
                    _buildCitationChip('100+', 100, isDark),
                    _buildCitationChip('500+', 500, isDark),
                  ],
                ),

                const SizedBox(height: 20),

                // 4. Publication Date
                _buildSectionHeader('PUBLISHED WITHIN', isDark),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildDateChip('Any time', null, isDark),
                    _buildDateChip('Past year', DateTime.now().subtract(const Duration(days: 365)), isDark),
                    _buildDateChip('Past 3 years', DateTime.now().subtract(const Duration(days: 365 * 3)), isDark),
                    _buildDateChip('Past 5 years', DateTime.now().subtract(const Duration(days: 365 * 5)), isDark),
                  ],
                ),

                const SizedBox(height: 20),

                // 5. Open Access Switch
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161922) : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF262C38) : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_open_rounded, size: 18, color: Color(0xFF10B981)),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Open Access Only',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                      Switch.adaptive(
                        value: _openAccess == true,
                        activeTrackColor: const Color(0xFF10B981),
                        onChanged: (val) {
                          setState(() {
                            _openAccess = val ? true : null;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.coral,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final updated = widget.currentFilters.copyWith(
                  mode: _mode,
                  sort: _sort,
                  openAccess: _openAccess,
                  minCitations: _minCitations,
                  publishedAfter: _publishedAfter,
                  source: _source,
                  clearDates: _publishedAfter == null,
                  clearMinCitations: _minCitations == null,
                );
                widget.onApply(updated);
                Navigator.of(context).pop();
              },
              child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
      ),
    );
  }

  Widget _buildSortChip(String label, SearchSort sort, bool isDark) {
    final isSelected = _sort == sort;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.coral,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
      ),
      onSelected: (_) => setState(() => _sort = sort),
    );
  }

  Widget _buildCitationChip(String label, int? count, bool isDark) {
    final isSelected = _minCitations == count;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.coral,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
      ),
      onSelected: (_) => setState(() => _minCitations = count),
    );
  }

  Widget _buildDateChip(String label, DateTime? date, bool isDark) {
    final isSelected = (_publishedAfter == null && date == null) ||
        (_publishedAfter != null &&
            date != null &&
            _publishedAfter!.year == date.year &&
            _publishedAfter!.month == date.month);

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.coral,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
      ),
      onSelected: (_) => setState(() => _publishedAfter = date),
    );
  }
}
