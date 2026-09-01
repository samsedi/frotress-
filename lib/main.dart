import 'dart:ui';
import 'package:flutter/material.dart';
import 'core/services/rust_bridge_service.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/ui/views/welcome_view.dart';
import 'features/unlock/ui/views/unlock_view.dart';

void main() {
  runApp(const FortressApp());
}

class FortressApp extends StatelessWidget {
  const FortressApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FortressWallet',
      theme: AppTheme.lightTheme,
      home: const _StartupGate(),
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.unknown,
        },
      ),
    );
  }
}

/// Decides whether this launch shows the unlock screen (a wallet already
/// exists on this device) or the create/import welcome flow (it doesn't).
/// Before this, the app always booted to `WelcomeView` regardless of
/// whether a wallet had already been created — relaunching effectively
/// had no "log back in" path at all.
class _StartupGate extends StatelessWidget {
  const _StartupGate();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: RustBridgeService().hasWallet(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snapshot.data == true ? const UnlockView() : const WelcomeView();
      },
    );
  }
}
