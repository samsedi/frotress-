import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/rust_bridge_service.dart';

class ReceiveViewModel extends ChangeNotifier {
  final RustBridgeService _rustBridgeService;

  ReceiveViewModel(this._rustBridgeService);

  String? _publicAddress;
  String? get publicAddress => _publicAddress;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isCopied = false;
  bool get isCopied => _isCopied;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _publicAddress = await _rustBridgeService.getAddress();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> copyToClipboard() async {
    final address = _publicAddress;
    if (address == null) return;

    await Clipboard.setData(ClipboardData(text: address));
    _isCopied = true;
    notifyListeners();

    // Reset copy state after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      _isCopied = false;
      notifyListeners();
    });
  }
}