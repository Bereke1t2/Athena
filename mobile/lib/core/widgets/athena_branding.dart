import 'package:flutter/material.dart';

/// Greek Mythology quotes centered around Athena (Goddess of Wisdom & Knowledge).
const athenaWisdomQuotes = [
  (
    quote: "Wisdom begins in wonder.",
    author: "Socrates",
    title: "Greek Philosophy",
  ),
  (
    quote: "Knowledge is the shield of Athena.",
    author: "Athena Lore",
    title: "Goddess of Wisdom",
  ),
  (
    quote: "The roots of education are bitter, but the fruit is sweet.",
    author: "Aristotle",
    title: "Ancient Scholar",
  ),
  (
    quote: "Reserve your right to think, for even to think wrongly is better than not to think at all.",
    author: "Hypatia of Alexandria",
    title: "Mathematician & Philosopher",
  ),
];

/// Smooth Entrance Animation Wrapper (Fade + SlideUp).
class AnimatedEntrance extends StatelessWidget {
  const AnimatedEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 450),
    this.offsetY = 16.0,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offsetY;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * offsetY),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Pulsing Owl of Athena (Goddess of Wisdom) Crest Icon.
class AthenaOwlCrest extends StatefulWidget {
  const AthenaOwlCrest({super.key, this.size = 48.0});

  final double size;

  @override
  State<AthenaOwlCrest> createState() => _AthenaOwlCrestState();
}

class _AthenaOwlCrestState extends State<AthenaOwlCrest>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF5C6BC0), const Color(0xFF3F51B5)]
                : [const Color(0xFF4C5BD4), const Color(0xFF7582EC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: (isDark ? const Color(0xFF5C6BC0) : const Color(0xFF4C5BD4))
                  .withValues(alpha: 0.35),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Athena Crown Symbol / Shield Aura
            Icon(
              Icons.shield_outlined,
              size: widget.size * 0.7,
              color: Colors.white.withValues(alpha: 0.25),
            ),
            // Athena Owl of Wisdom Icon
            Icon(
              Icons.auto_stories_rounded,
              size: widget.size * 0.5,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

/// Greek Mythology Wisdom Banner Card.
class WisdomBannerCard extends StatelessWidget {
  const WisdomBannerCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Pick deterministic quote based on current day
    final quoteIndex = DateTime.now().day % athenaWisdomQuotes.length;
    final item = athenaWisdomQuotes[quoteIndex];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E265C), const Color(0xFF14193E)]
              : [const Color(0xFF3F51B5), const Color(0xFF212C6E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const AthenaOwlCrest(size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 13,
                      color: Color(0xFFFFB74D),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'ATHENA WISDOM',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFFFFB74D),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '"${item.quote}"',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '— ${item.author} (${item.title})',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Greek Mythology Scholar Avatar Circle Widget.
class MythologyScholarAvatar extends StatelessWidget {
  const MythologyScholarAvatar({
    super.key,
    required this.name,
    required this.role,
    required this.accentColor,
    this.onTap,
  });

  final String name;
  final String role;
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = name.substring(0, 1);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [accentColor, accentColor.withValues(alpha: 0.4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.25),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 21,
                backgroundColor: theme.colorScheme.surface,
                child: Text(
                  initial,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 58,
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
