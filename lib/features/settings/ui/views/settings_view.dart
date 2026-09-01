import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../viewmodels/settings_viewmodel.dart';
import '../../../recovery/ui/views/recovery_home_view.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final SettingsViewModel _viewModel = SettingsViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onViewModelUpdate);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelUpdate);
    _viewModel.dispose();
    super.dispose();
  }

  void _onViewModelUpdate() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLightBlue,
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Wallet Directory Info
              Text('LOCAL STORAGE', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Wallet Directory Path:', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textLight)),
                    const SizedBox(height: 8),
                    Text(_viewModel.walletDirectory, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // Recovery Entry Point
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.security, color: Colors.white),
                        const SizedBox(width: 12),
                        Text('WALLET RECOVERY', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Lost a share? Or suspect your device is compromised? Access the emergency recovery tools here.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const RecoveryHomeView()));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: const Text('ENTER RECOVERY MODE'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
