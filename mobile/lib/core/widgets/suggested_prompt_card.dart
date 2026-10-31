import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Suggested quick action prompt card matching the Resarc hero section.
class SuggestedPromptCard extends StatelessWidget {
  const SuggestedPromptCard({
    super.key,
    required this.actionLead,
    required this.targetTitle,
    this.onTap,
  });

  final String actionLead;
  final String targetTitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF282C38) : const Color(0xFFE5E7EB);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF181A20) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Coral Document Icon
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.coral.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.description_outlined,
                size: 18,
                color: AppTheme.coral,
              ),
            ),
            const SizedBox(height: 10),

            // Prompt text: Action lead in bold + Target title in quotes
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF111827),
                ),
                children: [
                  TextSpan(
                    text: '$actionLead ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: targetTitle.startsWith('"') ? targetTitle : '"$targetTitle"',
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                    ),
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
