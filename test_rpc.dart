import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final rpcs = [
    'https://ethereum-rpc.publicnode.com',
    'https://polygon-bor-rpc.publicnode.com',
    'https://bsc-rpc.publicnode.com',
    'https://bsc-dataseed.binance.org',
    'https://ethereum-sepolia-rpc.publicnode.com',
  ];
  final address = '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045'; // vitalik.eth

  for (final rpc in rpcs) {
    try {
      final req = await HttpClient().postUrl(Uri.parse(rpc));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        "jsonrpc": "2.0",
        "method": "eth_getBalance",
        "params": [address, "latest"],
        "id": 1
      }));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      print('$rpc : ${res.statusCode} : $body');
    } catch(e) {
      print('$rpc : ERROR : $e');
    }
  }
}
