import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

/// Pennyfold: a free, fully offline personal finance tracker.
/// No accounts, no network, no ads – every byte stays on the device.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: PennyfoldApp()));
}
