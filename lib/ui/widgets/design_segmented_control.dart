import 'package:flutter/material.dart';
import 'package:tunnel_chain/app/theme/app_spacing.dart';
import 'package:tunnel_chain/app/theme/app_theme.dart';
import 'package:tunnel_chain/app/theme/app_typography.dart';
import 'package:tunnel_chain/ui/widgets/action_cursor.dart';

class DesignSegmentOption<T> {
  const DesignSegmentOption({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;
  final IconData? icon;
}

/// Segmented control matching sidebar theme toggle (design-system).
class DesignSegmentedControl<T> extends StatelessWidget {
  const DesignSegmentedControl({
    required this.segments,
    required this.selected,
    super.key,
    this.onChanged,
    this.height = AppSpacing.segmentedControlHeight,
  });

  final List<DesignSegmentOption<T>> segments;
  final T selected;
  final ValueChanged<T>? onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    assert(segments.isNotEmpty, 'segments must not be empty');

    return Row(
      children: [
        for (var i = 0; i < segments.length; i++)
          Expanded(
            child: Transform.translate(
              offset: Offset(i == 0 ? 0 : -1, 0),
              child: _DesignSegment<T>(
                option: segments[i],
                selected: segments[i].value == selected,
                enabled: onChanged != null,
                height: height,
                borderRadius: _borderRadius(i, segments.length),
                onTap: onChanged == null
                    ? null
                    : () => onChanged!(segments[i].value),
              ),
            ),
          ),
      ],
    );
  }

  static BorderRadius _borderRadius(int index, int count) {
    if (count == 1) return BorderRadius.circular(AppRadii.sm);
    if (index == 0) {
      return const BorderRadius.horizontal(left: Radius.circular(AppRadii.sm));
    }
    if (index == count - 1) {
      return const BorderRadius.horizontal(right: Radius.circular(AppRadii.sm));
    }
    return BorderRadius.zero;
  }
}

class _DesignSegment<T> extends StatelessWidget {
  const _DesignSegment({
    required this.option,
    required this.selected,
    required this.enabled,
    required this.height,
    required this.borderRadius,
    this.onTap,
  });

  final DesignSegmentOption<T> option;
  final bool selected;
  final bool enabled;
  final double height;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).dividerColor;
    final tokens = AppThemeTokens.of(context);
    final fg = selected
        ? Theme.of(context).colorScheme.onSurface
        : tokens.textSecondary;
    final bg = selected ? tokens.accentBg : Colors.transparent;

    return Material(
      color: bg,
      borderRadius: borderRadius,
      child: ActionCursor(
        enabled: enabled,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: borderRadius,
          mouseCursor: enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: Container(
            height: height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: border),
              borderRadius: borderRadius,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (option.icon != null) ...[
                  Icon(option.icon, size: 15, color: fg),
                  const SizedBox(width: 7),
                ],
                Flexible(
                  child: Text(
                    option.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body125.copyWith(
                      color: fg,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
