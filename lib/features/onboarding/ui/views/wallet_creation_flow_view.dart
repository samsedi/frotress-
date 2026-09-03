import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/rust_bridge_service.dart';
import '../../../../core/utils/error_dialog.dart';
import '../../../../core/utils/error_mapper.dart';
import '../../../home/ui/views/home_view.dart';
import '../viewmodels/wallet_creation_viewmodel.dart';

class WalletCreationFlowView extends StatefulWidget {
  const WalletCreationFlowView({super.key});

  @override
  State<WalletCreationFlowView> createState() => _WalletCreationFlowViewState();
}

class _WalletCreationFlowViewState extends State<WalletCreationFlowView> {
  late WalletCreationViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = WalletCreationViewModel(RustBridgeService());
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
    if (_viewModel.errorMessage != null && mounted) {
      final userMessage = ErrorMapper.mapErrorToUserFriendlyMessage(_viewModel.errorMessage!);
      // Avoid infinite loop
      _viewModel.clearError();
      showAppErrorDialog(context, 'Creation Failed', userMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLightBlue,
      appBar: AppBar(
        title: const Text('Create Wallet'),
        leading: _viewModel.step == WalletCreationStep.thresholdSetup || _viewModel.step == WalletCreationStep.sharesBackup
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _viewModel.step == WalletCreationStep.passphrase ? _viewModel.backToThresholdSetup : null,
              ),
        automaticallyImplyLeading: _viewModel.step == WalletCreationStep.thresholdSetup,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: _buildCurrentStep(),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_viewModel.step) {
      case WalletCreationStep.thresholdSetup:
        return _ThresholdSetupStep(viewModel: _viewModel);
      case WalletCreationStep.passphrase:
        return _PassphraseStep(viewModel: _viewModel);
      case WalletCreationStep.creating:
        return const _CreatingStep();
      case WalletCreationStep.sharesBackup:
        return _SharesBackupStep(result: _viewModel.result!);
    }
  }
}

// ---------------------------------------------------------
// STEP 1: Threshold setup
// ---------------------------------------------------------
class _ThresholdSetupStep extends StatelessWidget {
  final WalletCreationViewModel viewModel;
  const _ThresholdSetupStep({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('CHOOSE YOUR THRESHOLD', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 12),
        Text(
          'Your wallet key is split into ${viewModel.n} cryptographic shares. Any ${viewModel.threshold} of them can sign a transaction — no single share, and no single device, is ever enough on its own.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textLight, height: 1.5),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(
            children: [
              _buildStepperRow(
                context,
                label: 'TOTAL SHARES (N)',
                value: viewModel.n,
                min: 2,
                max: 5,
                onChanged: viewModel.setN,
              ),
              const Divider(height: 32),
              _buildStepperRow(
                context,
                label: 'REQUIRED TO SIGN (M)',
                value: viewModel.threshold,
                min: 2,
                max: viewModel.n,
                onChanged: viewModel.setThreshold,
              ),
            ],
          ),
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: viewModel.confirmThreshold,
          child: Text('CONTINUE (${viewModel.threshold}-OF-${viewModel.n})'),
        ),
      ],
    );
  }

  Widget _buildStepperRow(BuildContext context, {required String label, required int value, required int min, required int max, required ValueChanged<int> onChanged}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        Row(
          children: [
            IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: value > min ? () => onChanged(value - 1) : null),
            Text('$value', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: value < max ? () => onChanged(value + 1) : null),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------
// STEP 2: Passphrase
// ---------------------------------------------------------
class _PassphraseStep extends StatefulWidget {
  final WalletCreationViewModel viewModel;
  const _PassphraseStep({required this.viewModel});

  @override
  State<_PassphraseStep> createState() => _PassphraseStepState();
}

class _PassphraseStepState extends State<_PassphraseStep> {
  final _passphraseController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscureText = true;

  @override
  void dispose() {
    _passphraseController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _onContinue() {
    final pass = _passphraseController.text;
    final confirm = _confirmController.text;
    if (pass.length < 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passphrase must be at least 12 characters')),
      );
      return;
    }
    if (pass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passphrases do not match')),
      );
      return;
    }

    widget.viewModel.createWallet(pass);
    _passphraseController.clear();
    _confirmController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('ENCRYPT YOUR SHARES', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 16),
        Text(
          'This passphrase encrypts every share of your ${widget.viewModel.threshold}-of-${widget.viewModel.n} wallet on disk. '
          'There is no seed phrase to fall back on — if you forget this passphrase, your shares cannot be decrypted.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textLight, height: 1.5),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _passphraseController,
          obscureText: _obscureText,
          decoration: InputDecoration(
            labelText: 'Passphrase (min. 12 characters)',
            filled: true,
            fillColor: Colors.white,
            suffixIcon: IconButton(
              icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
              onPressed: () => setState(() => _obscureText = !_obscureText),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmController,
          obscureText: _obscureText,
          decoration: InputDecoration(
            labelText: 'Confirm Passphrase',
            filled: true,
            fillColor: Colors.white,
            suffixIcon: IconButton(
              icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
              onPressed: () => setState(() => _obscureText = !_obscureText),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: _onContinue,
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
          child: const Text('CREATE WALLET'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------
// STEP 3: Creating
// ---------------------------------------------------------
class _CreatingStep extends StatelessWidget {
  const _CreatingStep();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(color: AppTheme.surfaceDark),
        const SizedBox(height: 32),
        Text('RUNNING DKG CEREMONY', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 16),
        const Text(
          'Generating your key and splitting it into Shamir shares. This never leaves your device.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------
// STEP 4: Shares backup
// ---------------------------------------------------------
class _SharesBackupStep extends StatelessWidget {
  final WalletCreationResult result;
  const _SharesBackupStep({required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'These are cryptographic files, not words to memorize. Save each one somewhere different — a second device, a trusted person, a safe. One share alone cannot move your funds.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.orange.shade900),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('ADDRESS', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 8),
        SelectableText(result.address, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600)),
        const SizedBox(height: 24),
        Expanded(
          child: ListView.separated(
            itemCount: result.externalShares.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              // Share index 1 stays local (see wallet-core's module docs);
              // external shares start at index 2.
              final shareLabel = 'SHARE ${index + 2}';
              final encoded = base64Encode(result.externalShares[index]);
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shareLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 8),
                    Text(
                      encoded,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: encoded));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$shareLabel copied')));
                        }
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('COPY'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomeView()),
              (route) => false,
            );
          },
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
          child: const Text("I'VE SAVED MY SHARES"),
        ),
      ],
    );
  }
}
