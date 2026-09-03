import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/rust_bridge_service.dart';
import '../../../home/ui/views/home_view.dart';
import '../../../../core/utils/error_dialog.dart';
import '../../../../core/utils/error_mapper.dart';
import '../viewmodels/import_wallet_viewmodel.dart';

class ImportWalletFlowView extends StatefulWidget {
  const ImportWalletFlowView({super.key});

  @override
  State<ImportWalletFlowView> createState() => _ImportWalletFlowViewState();
}

class _ImportWalletFlowViewState extends State<ImportWalletFlowView> {
  late ImportWalletViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ImportWalletViewModel(RustBridgeService());
    _viewModel.addListener(_onViewModelUpdate);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelUpdate);
    _viewModel.dispose();
    super.dispose();
  }

  void _onViewModelUpdate() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLightBlue,
      appBar: AppBar(
        title: const Text('Import Wallet'),
        leading: _viewModel.step == ImportWalletStep.importing
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _viewModel.step == ImportWalletStep.passphrase
                    ? _viewModel.backToShares
                    : () => Navigator.pop(context),
              ),
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
      case ImportWalletStep.inputShares:
        return _InputSharesStep(viewModel: _viewModel);
      case ImportWalletStep.passphrase:
        return _PassphraseStep(viewModel: _viewModel);
      case ImportWalletStep.importing:
        return const _ImportingStep();
      case ImportWalletStep.verifyAddress:
        return _VerifyAddressStep(viewModel: _viewModel);
    }
  }
}

// ---------------------------------------------------------
// STEP 1: Input Shares
// ---------------------------------------------------------
class _InputSharesStep extends StatefulWidget {
  final ImportWalletViewModel viewModel;
  const _InputSharesStep({required this.viewModel});

  @override
  State<_InputSharesStep> createState() => _InputSharesStepState();
}

class _InputSharesStepState extends State<_InputSharesStep> {
  final _shareController = TextEditingController();

  void _addShare() {
    widget.viewModel.addShare(_shareController.text);
    _shareController.clear();
  }

  void _confirmShares() {
    widget.viewModel.confirmShares();
    if (widget.viewModel.errorMessage != null) {
      final userMessage = ErrorMapper.mapErrorToUserFriendlyMessage(widget.viewModel.errorMessage!);
      showAppErrorDialog(context, 'Invalid Shares', userMessage);
    }
  }

  @override
  void dispose() {
    _shareController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('ENTER YOUR SHARES', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 12),
        Text(
          'Paste at least 2 of your cryptographic shares below to reconstruct your wallet.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textLight, height: 1.5),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _shareController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Paste Share Here',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _addShare,
              icon: const Icon(Icons.add_circle, color: AppTheme.surfaceDark, size: 40),
            )
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: widget.viewModel.shares.length,
            itemBuilder: (context, index) {
              return Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: Text('Share ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  subtitle: Text(
                    widget.viewModel.shares[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.grey),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => widget.viewModel.removeShare(index),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: widget.viewModel.shares.length >= 2 ? _confirmShares : null,
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
          child: Text('CONTINUE (${widget.viewModel.shares.length} ADDED)'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------
// STEP 2: Passphrase
// ---------------------------------------------------------
class _PassphraseStep extends StatefulWidget {
  final ImportWalletViewModel viewModel;
  const _PassphraseStep({required this.viewModel});

  @override
  State<_PassphraseStep> createState() => _PassphraseStepState();
}

class _PassphraseStepState extends State<_PassphraseStep> {
  final _passphraseController = TextEditingController();

  @override
  void dispose() {
    _passphraseController.dispose();
    super.dispose();
  }

  Future<void> _onImport() async {
    final pass = _passphraseController.text;
    if (pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passphrase is required')),
      );
      return;
    }

    // Navigation is deferred to _VerifyAddressStep after the user confirms
    // the recovered address. importWallet() only moves to verifyAddress.
    final success = await widget.viewModel.importWallet(pass);
    if (!success && mounted && widget.viewModel.errorMessage != null) {
      final userMessage = ErrorMapper.mapErrorToUserFriendlyMessage(widget.viewModel.errorMessage!);
      showAppErrorDialog(context, 'Import Failed', userMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('DECRYPT YOUR SHARES', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 16),
        Text(
          'Enter the passphrase you used when creating these shares. Without it, the shares cannot be decrypted.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textLight, height: 1.5),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _passphraseController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Passphrase',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: _onImport,
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
          child: const Text('IMPORT WALLET'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------
// STEP 3: Importing
// ---------------------------------------------------------
class _ImportingStep extends StatelessWidget {
  const _ImportingStep();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(color: AppTheme.surfaceDark),
        const SizedBox(height: 32),
        Text('RECONSTRUCTING WALLET', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 16),
        const Text(
          'Decrypting your shares and running the DKG reconstruction ceremony locally.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------
// STEP 4: Verify Address (MED-4)
// ---------------------------------------------------------
/// Shows the address recovered from the shares and requires the user to
/// explicitly confirm it matches the wallet they intended to restore.
/// This is the final safety net against accidentally mixing shares from
/// two different wallets — plain Shamir reconstruction will silently
/// "succeed" but produce a different key; only the user recognising the
/// wrong address catches it.
class _VerifyAddressStep extends StatefulWidget {
  final ImportWalletViewModel viewModel;
  const _VerifyAddressStep({required this.viewModel});

  @override
  State<_VerifyAddressStep> createState() => _VerifyAddressStepState();
}

class _VerifyAddressStepState extends State<_VerifyAddressStep> {
  bool _isSaving = false;

  Future<void> _onConfirm() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    // Capture the navigator BEFORE the first await so it remains valid even
    // if the widget tree rebuilds mid-await (e.g. ViewModel notifyListeners).
    final navigator = Navigator.of(context);

    try {
      await widget.viewModel.confirmAndSave();
    } catch (e) {
      // The Rust side already wrote the wallet pubkey to disk — the wallet
      // IS accessible. A Keychain write failure (e.g. first-run permission
      // quirks on iOS simulator) must not block the user from their wallet.
      // Show a warning but navigate anyway; shares can be re-exported later.
      debugPrint('[ImportVM] Keychain save failed (non-fatal): $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Note: shares could not be saved to secure storage. '
              'Your wallet is accessible — please back up your shares again from Settings.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }
    }

    // Navigate to Home regardless — the wallet key is already on disk from Rust.
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeView()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final address = widget.viewModel.recoveredAddress ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('VERIFY RECOVERED ADDRESS', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 16),
        Text(
          'Your shares have been successfully decrypted and the wallet key reconstructed. '
          'Before saving, please confirm the address below matches the wallet you intended to restore.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textLight,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        // Address display — large, monospace, easy to compare character-by-character.
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.surfaceDark.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              const Icon(Icons.account_balance_wallet_outlined,
                  size: 40, color: AppTheme.surfaceDark),
              const SizedBox(height: 12),
              Text(
                'Recovered Address',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: AppTheme.textLight),
              ),
              const SizedBox(height: 8),
              SelectableText(
                address,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Compare every character of the address above against your records before confirming.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.orange.shade800,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
        const Spacer(),
        // Confirm — save shares to keychain then navigate to Home.
        ElevatedButton(
          onPressed: _isSaving ? null : _onConfirm,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            backgroundColor: Colors.green.shade700,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('YES, THIS IS MY WALLET'),
        ),
        const SizedBox(height: 12),
        // Reject — discard and restart from share entry.
        OutlinedButton(
          onPressed: _isSaving ? null : widget.viewModel.rejectAddress,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            foregroundColor: Colors.red.shade700,
            side: BorderSide(color: Colors.red.shade700),
          ),
          child: const Text('NO, WRONG ADDRESS — TRY AGAIN'),
        ),
      ],
    );
  }
}
