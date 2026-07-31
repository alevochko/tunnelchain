import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum NavIconKind {
  status,
  profiles,
  proxies,
  routing,
  dns,
  diagnostics,
  logs,
}

/// Sidebar navigation icons — Lucide (lucide.dev).
class NavIcon extends StatelessWidget {
  const NavIcon(this.kind, {super.key, this.size = 16, this.color});

  final NavIconKind kind;
  final double size;
  final Color? color;

  static IconData iconData(NavIconKind kind) => switch (kind) {
        NavIconKind.status => LucideIcons.circleDot,
        NavIconKind.routing => LucideIcons.user,
        NavIconKind.proxies => LucideIcons.waypoints,
        NavIconKind.profiles => LucideIcons.server,
        NavIconKind.diagnostics => LucideIcons.stethoscope,
        NavIconKind.logs => LucideIcons.scrollText,
        NavIconKind.dns => LucideIcons.globe,
      };

  @override
  Widget build(BuildContext context) {
    return Icon(
      iconData(kind),
      size: size,
      color: color ?? IconTheme.of(context).color,
    );
  }
}
