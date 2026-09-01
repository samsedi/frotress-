import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/network_config.dart';

class TransactionRecord {
  final String hash;
  final String from;
  final String to;
  final String value;
  final String timeStamp;
  final bool isError;
  final String contractAddress;
  final String tokenSymbol;
  final String tokenDecimal;

  TransactionRecord({
    required this.hash,
    required this.from,
    required this.to,
    required this.value,
    required this.timeStamp,
    required this.isError,
    required this.contractAddress,
    required this.tokenSymbol,
    required this.tokenDecimal,
  });

  factory TransactionRecord.fromJson(Map<String, dynamic> json) {
    return TransactionRecord(
      hash: json['hash'] ?? '',
      from: json['from'] ?? '',
      to: json['to'] ?? '',
      value: json['value'] ?? '0',
      timeStamp: json['timeStamp'] ?? '0',
      isError: json['isError'] == '1',
      contractAddress: json['contractAddress'] ?? '',
      tokenSymbol: json['tokenSymbol'] ?? '',
      tokenDecimal: json['tokenDecimal'] ?? '18',
    );
  }
}

class ExplorerService {
  Future<List<TransactionRecord>> getTransactions({
    required String address,
    required EvmNetwork network,
    TokenConfig? token,
  }) async {
    if (network.explorerApiUrl == null) return [];

    final baseUrl = network.explorerApiUrl!;
    
    // Blockscout API format (compatible with Etherscan V1)
    String action = token == null ? 'txlist' : 'tokentx';
    String url = '$baseUrl?module=account&action=$action&address=$address&page=1&offset=50&sort=desc';
    
    if (token != null) {
      url += '&contractaddress=${token.contractAddress}';
    }

    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == '1' && data['result'] is List) {
          final List results = data['result'];
          return results.map((e) => TransactionRecord.fromJson(e)).toList();
        } else if (data['message'] == 'No transactions found' || (data['status'] == '0' && data['result'] is List && data['result'].isEmpty)) {
          return [];
        } else {
          // Rate limit or other error
          final errorDetails = data['message'] ?? 'Unknown API error';
          final resultDetails = data['result'] is String ? data['result'] : '';
          throw Exception('$errorDetails $resultDetails'.trim());
        }
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch transactions: $e');
    }
  }
}
