import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/rust_bridge_service.dart';
import '../../../home/ui/views/home_view.dart';
import '../../../onboarding/ui/views/welcome_view.dart';
import '../viewmodels/unlock_viewmodel.dart';
/// Shown on launch when a wallet already exists on this device — the
/// "log back in" screen `main.dart` was missing entirely before, which
/// meant relaunching the app always dropped a user back at the
/// create/import choice instead of re-entering their existing wallet.
class UnlockView extends StatefulWidget {
  const UnlockView({super.key});

  @override
  State<UnlockView> createState() => _UnlockViewState();
}

class _UnlockViewState extends State<UnlockView> {
  late final UnlockViewModel _viewModel;
  final _passphraseController = TextEditingController();
  Timer? _lockoutTimer;
  int _lockoutSecsRemaining = 0;

  @override
  void initState() {
    super.initState();
    _viewModel = UnlockViewModel(RustBridgeService());
    _viewModel.addListener(_onViewModelUpdate);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelUpdate);
    _viewModel.dispose();
    _passphraseController.dispose();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  void _onViewModelUpdate() {
    setState(() {});
    if (_viewModel.isLockedOut && _lockoutTimer == null) {
      _startLockoutTimer();
    }
  }

  /// Ticks every second while a lockout is active; updates the countdown
  /// label and cancels itself when the lockout expires.
  void _startLockoutTimer() {
    _lockoutSecsRemaining = _viewModel.remainingLockout.inSeconds + 1;
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        _lockoutTimer = null;
        return;
      }
      setState(() {
        _lockoutSecsRemaining = _viewModel.remainingLockout.inSeconds + 1;
      });
      if (!_viewModel.isLockedOut) {
        timer.cancel();
        _lockoutTimer = null;
      }
    });
  }

  Future<void> _submit() async {
    final success = await _viewModel.unlock(_passphraseController.text);
    if (success && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeView()),
        (route) => false,
      );
    }
  }

  Future<void> _showResetDialog(BuildContext context) async {
    // Capture navigator before the async showDialog gap to satisfy the
    // use_build_context_synchronously lint (context may not be mounted
    // after the await returns).
    final navigator = Navigator.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Wallet?'),
        content: const Text(
          'This will remove the wallet from this device. '
          'You will need your recovery shares to restore access. '
          'Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _viewModel.resetWallet();
      if (mounted) {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeView()),
          (route) => false,
        );
      }
    }
  }

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
                'WELCOME BACK',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(letterSpacing: 2.0),
              ),
              const SizedBox(height: 16),
              Text(
                'Enter your passphrase to unlock this wallet.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textLight, height: 1.5),
              ),
              const SizedBox(height: 32),
              if (_viewModel.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                  child: Text(_viewModel.errorMessage!, style: TextStyle(color: Colors.red.shade900), textAlign: TextAlign.center),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _passphraseController,
                obscureText: true,
                autofocus: true,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'Passphrase',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: (_viewModel.isUnlocking || _viewModel.isLockedOut) ? null : _submit,
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
                child: _viewModel.isUnlocking
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : _viewModel.isLockedOut
                        ? Text('LOCKED — ${_lockoutSecsRemaining}s')
                        : const Text('UNLOCK'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _viewModel.isUnlocking ? null : () => _showResetDialog(context),
                child: const Text('Forgot Passphrase?', style: TextStyle(color: AppTheme.textLight)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
