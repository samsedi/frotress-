import 'package:flutter/foundation.dart';
import '../../../../core/services/rust_bridge_service.dart';
import '../../../../core/services/secure_storage_service.dart';

enum ImportWalletStep {
  inputShares,
  passphrase,
  importing,
  // MED-4: After reconstruction, show the recovered address and require
  // the user to confirm it matches the wallet they intended to restore.
  // This prevents silently importing the wrong wallet if shares from two
  // different wallets are accidentally mixed (plain Shamir reconstruction
  // will "succeed" but produce the wrong key, with no error from the
  // cryptographic layer — the only check is the user recognising the address).
  verifyAddress,
}

class ImportWalletViewModel extends ChangeNotifier {
  final RustBridgeService _rustBridgeService;

  ImportWalletStep _step = ImportWalletStep.inputShares;
  String? _errorMessage;
  final List<String> _shares = [];

  /// The EVM address reconstructed from the provided shares.
  /// Non-null only while in the [ImportWalletStep.verifyAddress] step.
  String? recoveredAddress;

  /// The shares that were used for the successful reconstruction, saved so
  /// [confirmAndSave] can persist them to the keychain without the user
  /// having to re-enter them.
  List<String>? _pendingShares;

  ImportWalletViewModel(this._rustBridgeService);

  ImportWalletStep get step => _step;
  String? get errorMessage => _errorMessage;
  List<String> get shares => _shares;

  void addShare(String share) {
    if (share.trim().isNotEmpty && !_shares.contains(share.trim())) {
      _shares.add(share.trim());
      _errorMessage = null;
      notifyListeners();
    }
  }

  void removeShare(int index) {
    if (index >= 0 && index < _shares.length) {
      _shares.removeAt(index);
      notifyListeners();
    }
  }

  void confirmShares() {
    if (_shares.length < 2) {
      _errorMessage = 'At least 2 shares are required.';
      notifyListeners();
      return;
    }
    _errorMessage = null;
    _step = ImportWalletStep.passphrase;
    notifyListeners();
  }

  void backToShares() {
    _errorMessage = null;
    _step = ImportWalletStep.inputShares;
    notifyListeners();
  }

  /// Decrypt the shares and reconstruct the wallet key. On success, moves
  /// to [ImportWalletStep.verifyAddress] with [recoveredAddress] populated
  /// for the user to confirm before the shares are saved to the keychain.
  ///
  /// The shares are deliberately NOT saved to secure storage yet — we wait
  /// for [confirmAndSave] so the user has a chance to reject a wrong address.
  Future<bool> importWallet(String passphrase) async {
    _errorMessage = null;
    _step = ImportWalletStep.importing;
    notifyListeners();

    try {
      final address = await _rustBridgeService.importWallet(
        shares: _shares,
        passphrase: passphrase,
      );
      // MED-4: Present the recovered address for verification before saving.
      recoveredAddress = address;
      _pendingShares = List<String>.from(_shares);
      _step = ImportWalletStep.verifyAddress;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _step = ImportWalletStep.passphrase;
      notifyListeners();
      return false;
    }
  }

  /// Called when the user taps "Yes, this is my wallet" on the address
  /// verification screen. Saves the shares to the OS keychain and signals
  /// completion to the caller.
  Future<void> confirmAndSave() async {
    if (_pendingShares != null) {
      await SecureStorageService.saveBackupShares(_pendingShares!);
    }
    // Leave step as verifyAddress; the view navigates on its own after this.
  }

  /// Called when the user taps "No, this is wrong" — discards the
  /// reconstructed key and resets so they can try different shares.
  void rejectAddress() {
    recoveredAddress = null;
    _pendingShares = null;
    _errorMessage = 'The recovered address did not match. '
        'Please check your shares and try again.';
    _step = ImportWalletStep.inputShares;
    notifyListeners();
  }
}
