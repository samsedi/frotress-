import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  try {
    final response = await http.get(Uri.parse('https://api.coingecko.com/api/v3/simple/price?ids=ethereum,matic-network,binancecoin&vs_currencies=usd'));
    print('CoinGecko: \${response.statusCode} - \${response.body}');
  } catch (e) {
    print('CoinGecko Error: \$e');
  }
}
