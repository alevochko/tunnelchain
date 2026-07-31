import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pointer cursor for interactive controls (design system).
class ActionCursor extends StatelessWidget {
  const ActionCursor({
    required this.child,
    super.key,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: child,
    );
  }
}

/// [InkWell] with pointer cursor — use for custom tappable surfaces.
class ActionInkWell extends StatelessWidget {
  const ActionInkWell({
    required this.child,
    super.key,
    this.onTap,
    this.borderRadius,
    this.customBorder,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final ShapeBorder? customBorder;
  final bool enabled;

  bool get _clickable => enabled && onTap != null;

  @override
  Widget build(BuildContext context) {
    return ActionCursor(
      enabled: _clickable,
      child: InkWell(
        onTap: _clickable ? onTap : null,
        borderRadius: borderRadius,
        customBorder: customBorder,
        mouseCursor: _clickable
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: child,
      ),
    );
  }
}

ButtonStyle actionMouseCursor(ButtonStyle style) {
  return style.copyWith(
    mouseCursor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return SystemMouseCursors.basic;
      }
      return SystemMouseCursors.click;
    }),
  );
}
