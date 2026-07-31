import 'package:flutter/foundation.dart';

/// FR-24 safety countdown: enabled in debug, skipped in release builds.
int effectiveSafetyTimeoutSec(int configured) => kReleaseMode ? 0 : configured;
