import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tunnel_chain/app/theme/app_theme.dart';
import 'package:tunnel_chain/app/theme/app_typography.dart';
import 'package:tunnel_chain/state/onboarding_provider.dart';
import 'package:tunnel_chain/ui/onboarding/onboarding_modal.dart';
import 'package:tunnel_chain/ui/widgets/action_cursor.dart';

/// Full-screen onboarding overlay with blurred app backdrop (HTML reference).
class OnboardingHost extends ConsumerWidget {
  const OnboardingHost({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    if (state.loading) return child;

    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.topLeft,
      children: [
        child,
        if (state.visible) ...[
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: ColoredBox(
                  color: const Color(0xFF06090D).withValues(alpha: 0.72),
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                child: OnboardingModal(),
              ),
            ),
          ),
        ],
        if (state.showRestartChip && !state.visible)
          Positioned(
            right: 28,
            bottom: 28,
            child: _RestartTourChip(onTap: notifier.restart),
          ),
      ],
    );
  }
}

class _RestartTourChip extends StatelessWidget {
  const _RestartTourChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).dividerColor;
    final tokens = AppThemeTokens.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: ActionInkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: tokens.surface2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
          ),
          child: Text(
            'Restart tour',
            style: AppTypography.body125.copyWith(
              fontWeight: FontWeight.w600,
              color: onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
