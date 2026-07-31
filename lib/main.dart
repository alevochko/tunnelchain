import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tunnel_chain/app/app.dart';
import 'package:tunnel_chain/services/status_bar_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isMacOS) {
    await StatusBarService.ensureReady();
  }
  runApp(const ProviderScope(child: TunnelChainApp()));
}
