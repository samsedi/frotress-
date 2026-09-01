import 'dart:io';

void main() async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse('https://api.coingecko.com/api/v3/simple/price?ids=ethereum,matic-network,binancecoin&vs_currencies=usd'));
    // request.headers.set('User-Agent', 'Mozilla/5.0');
    final response = await request.close();
    final body = await response.transform(SystemEncoding().decoder).join();
    print('CoinGecko: \${response.statusCode} - \$body');
  } catch (e) {
    print('CoinGecko Error: \$e');
  }
}
