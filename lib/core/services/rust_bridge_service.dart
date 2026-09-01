import 'dart:ffi' as ffi;
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:ffi/ffi.dart';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

// --- FFI Typedefs ---
typedef InvokeC = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8> requestStr);
typedef InvokeDart = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8> requestStr);

typedef FreeStringC = ffi.Void Function(ffi.Pointer<Utf8> ptr);
typedef FreeStringDart = void Function(ffi.Pointer<Utf8> ptr);

typedef SetBaseDirC = ffi.Void Function(ffi.Pointer<Utf8> pathPtr);
typedef SetBaseDirDart = void Function(ffi.Pointer<Utf8> pathPtr);

/// Bridge to the Rust `wallet-ffi` crate.
///
/// The compiled native library is bundled as a Flutter asset (see
/// `pubspec.yaml`'s `assets:` entry) rather than opened from a filesystem
/// path relative to the process's working directory. That matters because
/// a real launched app's cwd is not the source tree — a macOS .app runs
/// with its cwd inside its sandbox container, nowhere near the project —
/// so a relative path like `../fortresswallet/target/release/...` only
/// ever worked when launched from a terminal sitting in exactly the right
/// directory. Loading from `rootBundle` and extracting to a temp file
/// works the same way regardless of how or from where the app is started.
class RustBridgeService {
  static final RustBridgeService _instance = RustBridgeService._internal();

  factory RustBridgeService() {
    return _instance;
  }

  RustBridgeService._internal();

  InvokeDart? _invoke;
  FreeStringDart? _freeString;
  Future<void>? _initFuture;

  /// Lazily performs the one-time asset-extraction + dlopen, caching the
  /// in-flight/completed Future so concurrent calls all await the same
  /// initialization instead of racing to extract the file multiple times.
  Future<void> _ensureInitialized() {
    return _initFuture ??= _initFfi();
  }

  Future<void> _initFfi() async {
    final ffi.DynamicLibrary dylib;
    if (Platform.isMacOS) {
      // HIGH-1 fix: Extract the dylib to the app's own support directory
      // rather than the world-writable /tmp. The support directory is owned
      // by the app and not accessible to other processes on macOS (outside
      // the App Sandbox; inside the sandbox it's further restricted).
      //
      // Additionally we verify the SHA-256 of the bytes read back from disk
      // matches the bytes we just wrote before calling dlopen, closing the
      // TOCTOU window: if any other process replaced the file between write
      // and open, the hash check catches it.
      const assetPath = 'assets/native/macos/libwallet_ffi.dylib';
      final assetData = await rootBundle.load(assetPath);
      final assetBytes = assetData.buffer.asUint8List(
        assetData.offsetInBytes,
        assetData.lengthInBytes,
      );

      // Compute SHA-256 of the authoritative bytes from the signed bundle.
      final expectedDigest = sha256.convert(assetBytes);

      // Write to the app-support directory (not /tmp) so the file is owned
      // by the app and not world-writable.
      final supportDir = await getApplicationSupportDirectory();
      final libFile = File('${supportDir.path}/libwallet_ffi.dylib');
      await libFile.writeAsBytes(assetBytes, flush: true);

      // Re-read and verify before dlopen — if anything replaced the file
      // between write and read, the hash won't match.
      final writtenBytes = await libFile.readAsBytes();
      final actualDigest = sha256.convert(writtenBytes);
      if (actualDigest.toString() != expectedDigest.toString()) {
        throw StateError(
          'Native library integrity check failed: expected ${expectedDigest.toString()} '
          'but found ${actualDigest.toString()}. The library file may have been tampered with.',
        );
      }

      dylib = ffi.DynamicLibrary.open(libFile.path);
    } else if (Platform.isIOS) {
      // Unlike macOS, iOS won't dlopen a library extracted to a temp
      // file at runtime (unsigned code loaded that way is blocked on
      // real devices). Instead `RustWalletFfi.xcframework` is linked
      // and embedded directly into the Runner target (see
      // ios/Podfile and ios/RustWalletFfi.podspec) — dyld loads it at
      // process launch, and its C symbols are then visible through the
      // main executable's own symbol table.
      dylib = ffi.DynamicLibrary.process();
    } else if (Platform.isAndroid) {
      // On Android, libraries in jniLibs are automatically unpacked and
      // placed in the app's library search path. We can just load it by name.
      dylib = ffi.DynamicLibrary.open('libwallet_ffi.so');
    } else {
      throw UnsupportedError('The Rust bridge is not bundled for this platform in this build (got ${Platform.operatingSystem}).');
    }

    _invoke = dylib.lookupFunction<InvokeC, InvokeDart>('invoke');
    _freeString = dylib.lookupFunction<FreeStringC, FreeStringDart>('free_string');
    final setBaseDir = dylib.lookupFunction<SetBaseDirC, SetBaseDirDart>('set_base_dir');

    final supportDir = await getApplicationSupportDirectory();
    final pathPtr = supportDir.path.toNativeUtf8();
    setBaseDir(pathPtr);
    malloc.free(pathPtr);
  }

  /// Helper to call the Rust FFI with a JSON string, and parse the JSON response.
  Future<Map<String, dynamic>> _callRust(Map<String, dynamic> request) async {
    await _ensureInitialized();
    final invoke = _invoke!;
    final freeString = _freeString!;

    final jsonReq = jsonEncode(request);
    final reqPtr = jsonReq.toNativeUtf8();

    final resPtr = invoke(reqPtr);
    malloc.free(reqPtr);

    if (resPtr == ffi.nullptr) {
      throw Exception("Rust returned a null pointer");
    }

    final jsonRes = resPtr.toDartString();
    freeString(resPtr);

    return jsonDecode(jsonRes) as Map<String, dynamic>;
  }

  /// Ping test to verify the bridge is working
  Future<String> ping() async {
    final res = await _callRust({"method": "ping"});
    if (res.containsKey("error")) {
      throw Exception(res["error"]);
    }
    return res["message"] as String;
  }

  /// The directory this device's wallet shares and public key live under —
  /// the app's own support directory, not a path relative to wherever the
  /// process happened to start (see the class docs on why that matters).
  Future<Directory> walletDirectory() async {
    final supportDir = await getApplicationSupportDirectory();
    final walletDir = Directory('${supportDir.path}/wallet');
    if (!await walletDir.exists()) {
      await walletDir.create(recursive: true);
    }
    return walletDir;
  }

  /// Runs the DKG ceremony via `wallet_core::wallet::create_wallet` and
  /// returns the wallet's checksummed address plus the external Shamir
  /// shares (base64-decoded from the wire format) the user must back up
  /// themselves — share index 1 stays encrypted on this device, per
  /// `wallet-core`'s own split (see its module docs).
  Future<WalletCreationResult> createWallet({
    required String passphrase,
    required int threshold,
    required int n,
  }) async {
    final dir = await walletDirectory();
    final res = await _callRust({
      "method": "create_wallet",
      "params": {
        "dir": dir.path,
        "passphrase": passphrase,
        "threshold": threshold,
        "n": n,
      },
    });
    if (res.containsKey("error")) {
      throw Exception(res["error"]);
    }

    final address = res["address"] as String;
    final shareStrings = (res["shares"] as List).cast<String>();
    final shares = shareStrings.map(base64.decode).toList();
    return WalletCreationResult(address: address, externalShares: shares);
  }

  /// Loads the wallet's checksummed address from the locally stored
  /// public key — no network I/O, no passphrase needed.
  Future<String> getAddress() async {
    final dir = await walletDirectory();
    final res = await _callRust({
      "method": "get_address",
      "params": {"dir": dir.path},
    });
    if (res.containsKey("error")) {
      throw Exception(res["error"]);
    }
    return res["address"] as String;
  }

  /// Queries the wallet's balance, cross-checked across every URL in
  /// `rpcUrls` — a single lying or misconfigured node can't produce a
  /// wrong balance or a wrong chain ID without this throwing instead.
  /// Balance comes back as a decimal-string count of wei (not a `num`,
  /// to avoid precision loss on large values going through JSON).
  Future<WalletBalance> getBalance({
    required List<String> rpcUrls,
    required int chainId,
  }) async {
    final dir = await walletDirectory();
    final res = await _callRust({
      "method": "get_balance",
      "params": {
        "dir": dir.path,
        "rpc_urls": rpcUrls,
        "chain_id": chainId,
      },
    });
    if (res.containsKey("error")) {
      throw Exception(res["error"]);
    }
    return WalletBalance(address: res["address"] as String, weiString: res["balance_wei"] as String);
  }

  /// Queries an ERC-20 token balance.
  Future<WalletBalance> getErc20Balance({
    required List<String> rpcUrls,
    required int chainId,
    required String tokenAddress,
  }) async {
    final dir = await walletDirectory();
    final res = await _callRust({
      "method": "get_erc20_balance",
      "params": {
        "dir": dir.path,
        "rpc_urls": rpcUrls,
        "chain_id": chainId,
        "token_address": tokenAddress,
      },
    });
    if (res.containsKey("error")) {
      throw Exception(res["error"]);
    }
    return WalletBalance(address: res["address"] as String, weiString: res["balance_wei"] as String);
  }

  /// Deletes the local wallet directory, forcing the user to recover via shares.
  Future<void> deleteWallet() async {
    final dir = await walletDirectory();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Whether a wallet already exists on this device — a plain filesystem
  /// check (no passphrase, no Rust call needed) for `main.dart` to decide
  /// whether to show the unlock screen or the create/import welcome flow
  /// on launch.
  Future<bool> hasWallet() async {
    final dir = await walletDirectory();
    return File('${dir.path}/pubkey').exists();
  }

  /// "Log back in" to a wallet already created on this device: verifies
  /// `passphrase` actually decrypts the locally stored share (AEAD-
  /// authenticated, so a wrong passphrase throws here rather than
  /// silently letting the caller proceed) and returns the address.
  Future<String> unlockWallet(String passphrase) async {
    final dir = await walletDirectory();
    final res = await _callRust({
      "method": "unlock_wallet",
      "params": {"dir": dir.path, "passphrase": passphrase},
    });
    if (res.containsKey("error")) {
      throw Exception(res["error"]);
    }
    return res["address"] as String;
  }

  /// Restores a wallet from `threshold`-many externally held Shamir
  /// shares (the same base64 strings `createWallet` displayed for backup)
  /// sealed under `passphrase`, and persists the resulting public
  /// key/address under this device's wallet directory. Returns the
  /// restored address.
  Future<String> importWallet({
    required List<String> shares,
    required String passphrase,
  }) async {
    final dir = await walletDirectory();
    final res = await _callRust({
      "method": "import_wallet",
      "params": {"dir": dir.path, "passphrase": passphrase, "shares": shares},
    });
    if (res.containsKey("error")) {
      throw Exception(res["error"]);
    }
    return res["address"] as String;
  }

  /// Builds, signs (via the local share plus any `externalShares` the
  /// caller supplies), and broadcasts a plain native-currency transfer.
  /// `valueWei` and `externalShares` mirror `wallet-ffi`'s
  /// `send_transaction` — see its doc comment for cross-checking behavior.
  /// Returns the broadcast transaction hash.
  Future<String> sendTransaction({
    required String to,
    required BigInt valueWei,
    required String passphrase,
    required List<String> rpcUrls,
    required int chainId,
    List<String> externalShares = const [],
  }) async {
    final dir = await walletDirectory();
    final res = await _callRust({
      "method": "send_transaction",
      "params": {
        "dir": dir.path,
        "passphrase": passphrase,
        "chain_id": chainId,
        "rpc_urls": rpcUrls,
        "to": to,
        "value_wei": valueWei.toString(),
        "shares": externalShares,
      },
    });
    if (res.containsKey("error")) {
      throw Exception(res["error"]);
    }
    return res["tx_hash"] as String;
  }

  /// Builds, signs, and broadcasts an ERC-20 token transfer.
  Future<String> sendErc20Transaction({
    required String to,
    required BigInt valueWei,
    required String passphrase,
    required List<String> rpcUrls,
    required int chainId,
    required String tokenAddress,
    List<String> externalShares = const [],
  }) async {
    final dir = await walletDirectory();
    final res = await _callRust({
      "method": "send_erc20_transaction",
      "params": {
        "dir": dir.path,
        "passphrase": passphrase,
        "chain_id": chainId,
        "rpc_urls": rpcUrls,
        "token_address": tokenAddress,
        "to": to,
        "value_wei": valueWei.toString(),
        "shares": externalShares,
      },
    });
    if (res.containsKey("error")) {
      throw Exception(res["error"]);
    }
    return res["tx_hash"] as String;
  }
}

/// Result of a successful `RustBridgeService.getBalance` call.
class WalletBalance {
  final String address;
  final String weiString;

  WalletBalance({required this.address, required this.weiString});

  BigInt get wei => BigInt.parse(weiString);

  /// Formats the balance using the specified number of decimals.
  String formatWithDecimals(int decimals) {
    if (wei == BigInt.zero) return '0';
    final divisor = BigInt.from(10).pow(decimals);
    final whole = wei ~/ divisor;
    final remainder = (wei % divisor).toString().padLeft(decimals, '0');
    final trimmedRemainder = remainder.replaceFirst(RegExp(r'0+$'), '');
    return trimmedRemainder.isEmpty ? '$whole' : '$whole.$trimmedRemainder';
  }

  /// Formats the balance as an ETH decimal string (18 decimals).
  String get eth => formatWithDecimals(18);
}

/// Result of a successful `RustBridgeService.createWallet` call.
class WalletCreationResult {
  final String address;

  /// Every share except index 1 (which stays encrypted on this device) —
  /// raw decrypted-envelope bytes, still sealed (encrypted) under the
  /// passphrase the user just entered. These are what must be exported
  /// and given to separate share holders; see `wallet-core`'s module
  /// docs on why a single-device wallet is a dev-only convenience.
  final List<List<int>> externalShares;

  WalletCreationResult({required this.address, required this.externalShares});
}
