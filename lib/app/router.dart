import 'package:go_router/go_router.dart';
import 'package:tunnel_chain/ui/screens/diagnostics_screen.dart';
import 'package:tunnel_chain/ui/screens/logs_screen.dart';
import 'package:tunnel_chain/ui/screens/profiles_screen.dart';
import 'package:tunnel_chain/ui/screens/proxies_screen.dart';
import 'package:tunnel_chain/ui/screens/routing_screen.dart';
import 'package:tunnel_chain/ui/screens/status_screen.dart';
import 'package:tunnel_chain/ui/widgets/app_shell.dart';

abstract final class AppRouter {
  static const status = '/';
  static const routing = '/routing';
  static const profiles = '/profiles';
  static const proxies = '/proxies';
  static const diagnostics = '/diagnostics';
  static const logs = '/logs';

  static final GoRouter router = GoRouter(
    initialLocation: status,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: status,
                builder: (context, state) => const StatusScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: routing,
                builder: (context, state) => const RoutingScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: proxies,
                builder: (context, state) => const ProxiesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: profiles,
                builder: (context, state) => const ProfilesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: diagnostics,
                builder: (context, state) => const DiagnosticsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: logs,
                builder: (context, state) => const LogsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
