import 'package:flutter/foundation.dart';
import '../../../../core/constants/network_config.dart';
import '../../../../core/services/explorer_service.dart';
import '../../../../core/services/rust_bridge_service.dart';

class HistoryViewModel extends ChangeNotifier {
  final _explorerService = ExplorerService();
  final _rustBridgeService = RustBridgeService();

  final EvmNetwork network;
  final TokenConfig? token;

  List<TransactionRecord> _transactions = [];
  List<TransactionRecord> get transactions => _transactions;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _walletAddress;
  String? get walletAddress => _walletAddress;

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  HistoryViewModel({required this.network, this.token}) {
    loadTransactions();
  }

  Future<void> loadTransactions() async {
    if (_isLoading || _isDisposed) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final address = await _rustBridgeService.getAddress();
      if (_isDisposed) return;
      
      _walletAddress = address;
      
      _transactions = await _explorerService.getTransactions(
        address: address,
        network: network,
        token: token,
      );
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }
}
