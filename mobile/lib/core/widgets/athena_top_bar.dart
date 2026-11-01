import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';


/// Standardized circular outline action button matching the Resarc editorial design.
class AthenaCircularIconButton extends StatelessWidget {
  const AthenaCircularIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 36,
    this.iconSize = 18,
    this.iconColor,
    this.borderColor,
    this.backgroundColor,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;
  final Color? iconColor;
  final Color? borderColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = borderColor ?? (isDark ? const Color(0xFF282C38) : const Color(0xFFE5E7EB));
    final bg = backgroundColor ?? (isDark ? const Color(0xFF181A20) : Colors.white);
    final fg = iconColor ?? (isDark ? Colors.white : const Color(0xFF111827));

    Widget button = InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(size / 2),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: border, width: 1.0),
          color: bg,
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: iconSize, color: fg),
      ),
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Center(child: button),
    );
  }
}

/// Universal top bar for Athena matching the Resarc editorial design system.
/// Implements [PreferredSizeWidget] so it can be plugged into [Scaffold.appBar]
/// or used directly as a header widget.
class AthenaTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AthenaTopBar({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.onLeadingTap,
    this.showLeading = true,
    this.isCloseButton = false,
    this.actions = const [],
    this.bottom,
    this.centerTitle = false,
  });

  final String? title;
  final Widget? titleWidget;
  final Widget? leading;
  final VoidCallback? onLeadingTap;
  final bool showLeading;
  final bool isCloseButton;
  final List<Widget> actions;
  final PreferredSizeWidget? bottom;
  final bool centerTitle;

  @override
  Size get preferredSize => Size.fromHeight(56 + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget? leadingWidget = leading;
    if (leadingWidget == null && showLeading) {
      final canPop = Navigator.of(context).canPop();
      if (canPop || onLeadingTap != null) {
        leadingWidget = AthenaCircularIconButton(
          icon: isCloseButton ? Icons.close_rounded : Icons.arrow_back_rounded,
          tooltip: isCloseButton ? 'Close' : 'Back',
          onPressed: () {
            if (onLeadingTap != null) {
              onLeadingTap!();
            } else if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        );
      }
    }

    Widget? centerWidget = titleWidget;
    if (centerWidget == null && title != null) {
      centerWidget = Text(
        title!,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: isDark ? Colors.white : const Color(0xFF111827),
        ),
      );
    }

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      centerTitle: centerTitle,
      leading: leadingWidget != null
          ? Padding(
              padding: const EdgeInsets.only(left: 12),
              child: leadingWidget,
            )
          : null,
      leadingWidth: leadingWidget != null ? 52 : 0,
      title: centerWidget,
      actions: actions.isNotEmpty
          ? [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actions,
                ),
              ),
            ]
          : null,
      bottom: bottom,
    );
  }
}
