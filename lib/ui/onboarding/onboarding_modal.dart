import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tunnel_chain/app/theme/app_colors.dart';
import 'package:tunnel_chain/app/theme/app_theme.dart';
import 'package:tunnel_chain/app/theme/app_typography.dart';
import 'package:tunnel_chain/state/onboarding_provider.dart';
import 'package:tunnel_chain/ui/onboarding/onboarding_data.dart';
import 'package:tunnel_chain/ui/onboarding/onboarding_previews.dart';
import 'package:tunnel_chain/ui/widgets/action_cursor.dart';

class OnboardingModal extends ConsumerStatefulWidget {
  const OnboardingModal({super.key});

  @override
  ConsumerState<OnboardingModal> createState() => _OnboardingModalState();
}

class _OnboardingModalState extends ConsumerState<OnboardingModal> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final notifier = ref.read(onboardingProvider.notifier);
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      notifier.next();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      notifier.back();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);
    final step = onboardingSteps[state.step];
    final border = Theme.of(context).dividerColor;
    final secondary = AppThemeTokens.of(context).textSecondary;
    final primary = Theme.of(context).colorScheme.primary;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 660),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: border),
            ),
            clipBehavior: Clip.none,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _OnboardingHeader(
                  stepIndex: state.step,
                  onSkip: notifier.skip,
                  border: border,
                  secondary: secondary,
                ),
                Container(
                  height: 268,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    border: Border(bottom: BorderSide(color: border)),
                  ),
                  padding: const EdgeInsets.fromLTRB(28, 10, 28, 14),
                  clipBehavior: Clip.none,
                  child: OnboardingPreviewViewport(
                    step: state.step,
                    child: OnboardingStepPreview(step: state.step),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 22, 26, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.kicker,
                        style: AppTypography.sectionHeader.copyWith(
                          color: primary,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        step.title,
                        style: AppTypography.screenTitle.copyWith(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 9),
                      SizedBox(
                        height: 13.5 * 1.55 * 3,
                        child: Text(
                          step.body,
                          style: AppTypography.body135.copyWith(
                            color: secondary,
                            height: 1.55,
                          ),
                          maxLines: 3,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 16, 26, 22),
                  child: Row(
                    children: [
                      if (state.step > 0)
                        _OnboardingBackButton(onPressed: notifier.back),
                      const Spacer(),
                      _OnboardingPrimaryButton(
                        label: step.nextLabel,
                        onPressed: notifier.next,
                      ),
                    ],
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

class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({
    required this.stepIndex,
    required this.onSkip,
    required this.border,
    required this.secondary,
  });

  final int stepIndex;
  final VoidCallback onSkip;
  final Color border;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          Text(
            'STEP ${stepIndex + 1} OF ${OnboardingState.stepCount}',
            style: AppTypography.sectionHeader.copyWith(
              color: secondary,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Row(
              children: [
                for (var i = 0; i < OnboardingState.stepCount; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      height: 3,
                      decoration: BoxDecoration(
                        color: i <= stepIndex
                            ? AppColors.accent
                            : Theme.of(context).dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),
          ActionInkWell(
            onTap: onSkip,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                'Skip tour',
                style: AppTypography.body125.copyWith(color: secondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingBackButton extends StatelessWidget {
  const _OnboardingBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).dividerColor;
    final tokens = AppThemeTokens.of(context);

    return ActionInkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: tokens.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Text(
          'Back',
          style: AppTypography.button.copyWith(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _OnboardingPrimaryButton extends StatelessWidget {
  const _OnboardingPrimaryButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ActionInkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: AppTypography.button.copyWith(
            fontSize: 13,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
