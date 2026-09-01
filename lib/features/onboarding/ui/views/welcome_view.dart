import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/rust_bridge_service.dart';
import 'wallet_creation_flow_view.dart';
import 'import_wallet_flow_view.dart';

class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLightBlue,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Brand Logo
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/app_icon.jpg',
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'FORTRESS',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'A highly secure, non-custodial cryptographic engine for your digital assets.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textLight,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletCreationFlowView()));
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: const Text('CREATE NEW WALLET'),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ImportWalletFlowView()));
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.surfaceDark,
                  side: const BorderSide(color: AppTheme.surfaceDark, width: 2),
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                ),
                child: const Text('IMPORT WALLET', style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              ),
              const SizedBox(height: 16),
              // TEST FFI BUTTON
              TextButton(
                onPressed: () async {
                  try {
                    final bridge = RustBridgeService();
                    final msg = await bridge.ping();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('FFI Success: $msg'), backgroundColor: Colors.green),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('FFI Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                },
                child: const Text('TEST RUST BRIDGE'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
