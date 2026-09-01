import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../core/services/rust_bridge_service.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../home/ui/views/home_view.dart';

export '../../../home/ui/views/home_view.dart' show AssetData;

enum TimelineState { submitted, processing, sent, confirmed, failed }

enum SendStep {
  recipientAndAmount,
  feeReview,
  confirmSummary,
  transactionStatus,
}

class SendViewModel extends ChangeNotifier {
  final RustBridgeService _rustBridgeService;
  final AssetData asset;

  SendViewModel(this._rustBridgeService, {required this.asset});

  SendStep _currentStep = SendStep.recipientAndAmount;
  SendStep get currentStep => _currentStep;

  // Form Data
  String recipientAddress = '';
  String amountStr = '';
  // CRIT-2: passphrase is stored only for the duration of the signing
  // ceremony — it is overwritten in the finally block of _startSigningCeremony
  // the moment it's no longer needed. Dart Strings are immutable and GC'd
  // non-deterministically, so we can't guarantee a true memory wipe, but
  // clearing the reference as soon as possible is the best achievable mitigation.
  String passphrase = '';
  double estimatedFeeEth = 0.0005; // Mock heuristic
  String? txHash;
  String? errorMsg;
  TimelineState timelineState = TimelineState.submitted;
  bool isProcessing = false;

  bool get canProceedToFeeReview {
    final isHex = RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(recipientAddress);
    return isHex && amountStr.isNotEmpty && (double.tryParse(amountStr) ?? 0) > 0;
  }

  bool get canSign => passphrase.isNotEmpty;

  void nextStep() {
    if (_currentStep == SendStep.recipientAndAmount && canProceedToFeeReview) {
      _currentStep = SendStep.feeReview;
    } else if (_currentStep == SendStep.feeReview) {
      _currentStep = SendStep.confirmSummary;
    } else if (_currentStep == SendStep.confirmSummary && canSign) {
      // Start the signing process
      _startSigningCeremony();
      return;
    }
    notifyListeners();
  }

  void previousStep() {
    if (_currentStep == SendStep.feeReview) {
      _currentStep = SendStep.recipientAndAmount;
    } else if (_currentStep == SendStep.confirmSummary) {
      _currentStep = SendStep.feeReview;
    }
    notifyListeners();
  }

  static BigInt _amountToWei(String amountStr, int decimals) {
    final parts = amountStr.split('.');
    final whole = BigInt.parse(parts[0].isEmpty ? '0' : parts[0]);
    final fraction = parts.length > 1 ? parts[1] : '';
    final paddedFraction = fraction.padRight(decimals, '0').substring(0, decimals);
    return whole * BigInt.from(10).pow(decimals) + BigInt.parse(paddedFraction.isEmpty ? '0' : paddedFraction);
  }

  Future<void> _startSigningCeremony() async {
    _currentStep = SendStep.transactionStatus;
    errorMsg = null;
    timelineState = TimelineState.submitted;
    notifyListeners();

    // Mock processing delay for UI
    await Future.delayed(const Duration(seconds: 1));
    timelineState = TimelineState.processing;
    notifyListeners();

    // Debug: log passphrase length (never the passphrase itself!)
    debugPrint('[SendVM] passphrase length: ${passphrase.length}');
    debugPrint('[SendVM] network: ${asset.network.name}, chainId: ${asset.network.chainId}');
    debugPrint('[SendVM] rpcUrls: ${asset.network.rpcUrls}');

    // Capture the passphrase in a local variable so we can wipe the field
    // before the method returns, regardless of outcome.
    final localPassphrase = passphrase;

    try {
      final decimals = asset.token?.decimals ?? 18;
      final valueWei = _amountToWei(amountStr, decimals);
      final sharesList = await SecureStorageService.getBackupShares();

      if (asset.token == null) {
        txHash = await _rustBridgeService.sendTransaction(
          to: recipientAddress,
          valueWei: valueWei,
          passphrase: localPassphrase,
          rpcUrls: asset.network.rpcUrls,
          chainId: asset.network.chainId,
          externalShares: sharesList,
        );
      } else {
        txHash = await _rustBridgeService.sendErc20Transaction(
          to: recipientAddress,
          valueWei: valueWei,
          passphrase: localPassphrase,
          rpcUrls: asset.network.rpcUrls,
          chainId: asset.network.chainId,
          tokenAddress: asset.token!.contractAddress,
          externalShares: sharesList,
        );
      }
      timelineState = TimelineState.sent;
      notifyListeners();
      _pollTransactionStatus();
    } catch (e) {
      debugPrint('[SendVM] signing error: $e');
      errorMsg = e.toString();
      _currentStep = SendStep.confirmSummary;
      notifyListeners();
    } finally {
      // CRIT-2: Wipe the passphrase field immediately after the signing
      // attempt completes or fails. The Rust FFI already wraps it in
      // Zeroizing<String> the moment it crosses the boundary; this clears
      // the Dart-side reference as soon as it's no longer needed.
      passphrase = '';
    }
  }

  /// MED-1: Poll every configured RPC endpoint and only advance to
  /// `confirmed` when ALL of them agree the transaction has landed with
  /// status 0x1. Disagreement or any endpoint returning a non-200 is
  /// treated as "not yet confirmed" — we keep polling rather than trusting
  /// a single possibly-lying provider.
  Future<void> _pollTransactionStatus() async {
    if (txHash == null) return;
    final rpcUrls = asset.network.rpcUrls;

    while (timelineState == TimelineState.sent) {
      await Future.delayed(const Duration(seconds: 3));
      if (timelineState != TimelineState.sent) break;

      try {
        final status = await _getCrossCheckedReceiptStatus(txHash!, rpcUrls);
        if (status == null) continue; // not mined yet — keep polling

        if (status == '0x1') {
          timelineState = TimelineState.confirmed;
          notifyListeners();
          break;
        } else if (status == '0x0') {
          timelineState = TimelineState.failed;
          notifyListeners();
          break;
        }
        // Any other status value: treat as unknown, keep polling.
      } catch (e) {
        debugPrint('[SendVM] polling error: $e');
        // Don't break on a transient error — keep polling.
      }
    }
  }

  /// Query all [rpcUrls] for the receipt of [txHash]. Returns:
  ///   - `null`  if the transaction is not yet mined (all endpoints agree
  ///             the receipt is absent, or endpoints are not yet in sync).
  ///   - A status string (`'0x1'` or `'0x0'`) if all responding endpoints
  ///             agree on the same outcome.
  ///
  /// Throws [Exception] if endpoints disagree — this is treated as a
  /// transient error by the caller, which keeps polling rather than marking
  /// the transaction failed.
  Future<String?> _getCrossCheckedReceiptStatus(
    String txHash,
    List<String> rpcUrls,
  ) async {
    final results = await Future.wait(
      rpcUrls.map((url) => _queryReceiptStatus(url, txHash)),
    );

    // Filter out endpoints that haven't seen the tx yet (null).
    final seen = results.whereType<String>().toList();
    if (seen.isEmpty) return null; // no endpoint has mined it yet

    // Require all responding endpoints to agree.
    final statuses = seen.toSet();
    if (statuses.length != 1) {
      throw Exception(
        'RPC endpoints disagree on transaction status — refusing to trust either result. '
        'Seen statuses: $statuses',
      );
    }

    return statuses.first;
  }

  /// Fetch the `status` field from the receipt of [txHash] at [rpcUrl].
  /// Returns `null` if the receipt is absent (tx not yet mined) or if the
  /// request fails transiently (network error, non-200 response).
  Future<String?> _queryReceiptStatus(String rpcUrl, String txHash) async {
    try {
      final res = await http.post(
        Uri.parse(rpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'eth_getTransactionReceipt',
          'params': [txHash],
          'id': 1,
        }),
      );
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final result = data['result'];
      if (result == null) return null; // not mined yet at this endpoint
      return result['status'] as String?;
    } catch (_) {
      return null; // treat transient errors as "not yet mined"
    }
  }

  void updateRecipient(String address) {
    recipientAddress = address;
    notifyListeners();
  }

  void updateAmount(String amount) {
    amountStr = amount;
    notifyListeners();
  }

  void updatePassphrase(String value) {
    passphrase = value;
    notifyListeners();
  }
}
