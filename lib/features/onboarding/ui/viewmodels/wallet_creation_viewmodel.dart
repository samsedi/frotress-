import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../../core/services/rust_bridge_service.dart';
import '../../../../core/services/secure_storage_service.dart';

enum WalletCreationStep {
  thresholdSetup,
  passphrase,
  creating,
  sharesBackup,
}

/// Drives the wallet-creation flow: pick an M-of-N threshold, set a
/// passphrase, run the real DKG ceremony over the Rust bridge, then show
/// the resulting address and the Shamir shares the user must back up.
/// Mirrors the step-enum + single-owner-StatefulWidget pattern already
/// used by `SendViewModel`/`RecoveryViewModel` elsewhere in this app.
class WalletCreationViewModel extends ChangeNotifier {
  final RustBridgeService _rustBridgeService;

  WalletCreationViewModel(this._rustBridgeService);

  WalletCreationStep _step = WalletCreationStep.thresholdSetup;
  WalletCreationStep get step => _step;

  int n = 3;
  int threshold = 2;

  String? errorMessage;
  WalletCreationResult? result;

  void setN(int value) {
    n = value;
    if (threshold > n) threshold = n;
    notifyListeners();
  }

  void setThreshold(int value) {
    threshold = value;
    notifyListeners();
  }

  void confirmThreshold() {
    _step = WalletCreationStep.passphrase;
    notifyListeners();
  }

  void backToThresholdSetup() {
    _step = WalletCreationStep.thresholdSetup;
    notifyListeners();
  }

  /// Runs the real DKG ceremony. On success, moves to the shares-backup
  /// step; on failure, returns to the passphrase step with `errorMessage`
  /// set rather than silently retrying or falling back to a mock result.
  Future<void> createWallet(String passphrase) async {
    _step = WalletCreationStep.creating;
    errorMessage = null;
    notifyListeners();

    try {
      result = await _rustBridgeService.createWallet(passphrase: passphrase, threshold: threshold, n: n);
      final encodedShares = result!.externalShares.map((s) => base64Encode(s)).toList();
      await SecureStorageService.saveBackupShares(encodedShares);
      _step = WalletCreationStep.sharesBackup;
    } catch (e) {
      errorMessage = e.toString();
      _step = WalletCreationStep.passphrase;
    }
    notifyListeners();
  }
}
