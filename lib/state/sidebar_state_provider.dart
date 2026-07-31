import 'package:flutter_riverpod/flutter_riverpod.dart';

final sidebarExpandedProvider = NotifierProvider<SidebarExpandedNotifier, bool>(
  SidebarExpandedNotifier.new,
);

class SidebarExpandedNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}
