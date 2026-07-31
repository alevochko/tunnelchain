import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tunnel_chain/app/router.dart';
import 'package:tunnel_chain/app/theme/app_theme.dart';
import 'package:tunnel_chain/state/theme_mode_provider.dart';
import 'package:tunnel_chain/ui/onboarding/onboarding_host.dart';
import 'package:tunnel_chain/ui/widgets/status_bar_host.dart';

class TunnelChainApp extends ConsumerWidget {
  const TunnelChainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'TunnelChain',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      themeAnimationDuration: Duration.zero,
      themeAnimationCurve: Curves.linear,
      routerConfig: AppRouter.router,
      builder: (context, child) {
        final routed = child ?? const SizedBox.shrink();
        final shell = Platform.isMacOS
            ? StatusBarHost(child: routed)
            : routed;
        return OnboardingHost(child: shell);
      },
    );
  }
}
