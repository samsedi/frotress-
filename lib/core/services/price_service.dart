import 'dart:convert';
import 'package:http/http.dart' as http;


class PriceService {
  static const String _baseUrl = 'https://api.coingecko.com/api/v3';
  
  // Cache to avoid hitting rate limits too quickly
  final Map<String, double> _priceCache = {};
  DateTime? _lastFetch;

  String _getCoinGeckoId(int chainId) {
    switch (chainId) {
      case 1: // Ethereum
      case 11155111: // Sepolia
        return 'ethereum';
      case 137: // Polygon
        return 'matic-network';
      case 56: // BNB Smart Chain
        return 'binancecoin';
      default:
        return 'ethereum';
    }
  }

  /// Fetches prices for all requested chain IDs.
  /// Returns a map of chainId to its price in USD.
  Future<Map<int, double>> fetchPrices(List<int> chainIds) async {
    // Return cached prices if fetched less than 30 seconds ago to avoid rate limits
    if (_lastFetch != null && DateTime.now().difference(_lastFetch!).inSeconds < 30 && _priceCache.isNotEmpty) {
      return _buildResultMap(chainIds);
    }

    final uniqueCoinIds = chainIds.map(_getCoinGeckoId).toSet().toList();
    
    if (uniqueCoinIds.isEmpty) {
      return {};
    }

    final idsParam = uniqueCoinIds.join(',');
    final url = Uri.parse('$_baseUrl/simple/price?ids=$idsParam&vs_currencies=usd');

    try {
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        
        for (final coinId in uniqueCoinIds) {
          if (data.containsKey(coinId) && data[coinId]['usd'] != null) {
            final price = (data[coinId]['usd'] as num).toDouble();
            _priceCache[coinId] = price;
          }
        }
        _lastFetch = DateTime.now();
      } else {
        // Log error, but fall back to cache if available
        print('Failed to fetch prices: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error fetching prices: $e');
      // Fall back to cache on error
    }

    return _buildResultMap(chainIds);
  }

  Map<int, double> _buildResultMap(List<int> chainIds) {
    final result = <int, double>{};
    for (final chainId in chainIds) {
      final coinId = _getCoinGeckoId(chainId);
      if (_priceCache.containsKey(coinId)) {
        result[chainId] = _priceCache[coinId]!;
      }
    }
    return result;
  }
}
