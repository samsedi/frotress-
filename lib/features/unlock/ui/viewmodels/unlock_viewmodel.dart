import 'package:flutter/foundation.dart';
import '../../../../core/services/rust_bridge_service.dart';

/// Manages unlock (passphrase verification) with exponential backoff to
/// prevent brute-force attacks.
///
/// After each failed attempt the lockout duration increases:
///   1st fail → 0 s   (immediate retry allowed for typos)
///   2nd fail → 5 s
///   3rd fail → 30 s
///   4th fail → 2 min
///   5th+ fail → 10 min
///
/// The counter is in-memory only (not persisted) — it resets when the app
/// is killed. For a stronger guarantee (surviving app restarts) the counter
/// would need to live in flutter_secure_storage, but in-memory lockout is
/// still the primary mitigation because an attacker running an automated
/// script cannot kill and relaunch the app between attempts without
/// triggering its own delays.
class UnlockViewModel extends ChangeNotifier {
  final RustBridgeService _rustBridgeService;

  UnlockViewModel(this._rustBridgeService);

  bool isUnlocking = false;
  String? errorMessage;

  /// Number of consecutive failed attempts since the last successful unlock
  /// or app launch.
  int _failedAttempts = 0;

  /// When the current lockout expires. Null means no lockout is active.
  DateTime? _lockedUntil;

  /// Seconds of lockout per attempt index (0-based). Index 4+ maps to 600 s.
  static const _lockoutSchedule = [0, 5, 30, 120, 600];

  /// How long the user must wait before the next attempt, or [Duration.zero]
  /// if they may try immediately.
  Duration get remainingLockout {
    if (_lockedUntil == null) return Duration.zero;
    final remaining = _lockedUntil!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get isLockedOut => remainingLockout > Duration.zero;

  Future<bool> unlock(String passphrase) async {
    // Guard: enforce the lockout before even calling Rust, so brute-forcing
    // cannot exploit any timing in the Argon2id computation.
    if (isLockedOut) {
      final secs = remainingLockout.inSeconds + 1;
      errorMessage = 'Too many failed attempts. Please wait $secs seconds.';
      notifyListeners();
      return false;
    }

    isUnlocking = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _rustBridgeService.unlockWallet(passphrase);
      // Success: reset the counter.
      _failedAttempts = 0;
      _lockedUntil = null;
      return true;
    } catch (e) {
      _failedAttempts++;
      final lockoutSecs = _lockoutSchedule[
        _failedAttempts.clamp(0, _lockoutSchedule.length - 1)
      ];
      if (lockoutSecs > 0) {
        _lockedUntil = DateTime.now().add(Duration(seconds: lockoutSecs));
        errorMessage =
            'Incorrect passphrase. Too many attempts — please wait '
            '$lockoutSecs seconds before trying again.';
      } else {
        errorMessage = 'Incorrect passphrase. Please try again.';
      }
      return false;
    } finally {
      isUnlocking = false;
      notifyListeners();
    }
  }

  Future<void> resetWallet() async {
    await _rustBridgeService.deleteWallet();
    _failedAttempts = 0;
    _lockedUntil = null;
  }
}
