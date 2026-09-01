# Fortress Wallet

A self-custody EVM wallet for iOS, Android, and macOS, built with a Flutter frontend and a hardened Rust cryptography core. 

There is no backend database, no user accounts, and no central server that ever sees key material. Mnemonic generation, address derivation, transaction construction, and signing all happen purely on the device using a 2-of-3 Shamir's Secret Sharing scheme.

## 🔗 Rust Core Backend
The secure Rust engine that powers this wallet is open source and maintained in a separate repository. 
[**View FortressWallet Rust Core**](https://github.com/samsedi/fortresswallet)

## Contents
- [Features](#features)
- [Architecture](#architecture)
- [Security model](#security-model)
- [Threat model](#threat-model)
- [Local development](#local-development)
- [Environment variables](#environment-variables)
- [Limitations](#limitations)
- [License](#license)

## Features

- **BIP39 wallet creation** — 12-word phrase generation, handled entirely offline.
- **Wallet restore** — Recovers EVM accounts perfectly from a standard 12-word BIP39 phrase.
- **BIP44 native EVM derivation** — Derives standard addresses at `m/44'/60'/0'/0/0`.
- **Threshold Cryptography (Shamir)** — Key material is split into a 2-of-3 Shamir's Secret Sharing scheme for distributed, fail-safe backups. 
- **Direct RPC Communication** — Balances and history are read directly from standard EVM JSON-RPC nodes (e.g. Infura, Publicnode), with no middleman server.
- **Multi-Network Support** — Seamlessly switch between Ethereum Mainnet, Sepolia Testnet, Polygon, and Binance Smart Chain.
- **Four-Step Send Flow** — Compose, review estimated gas fees, authorize (reconstruct shares via passcode), and broadcast.
- **Bitget-Style Transaction Timeline** — A real-time vertical UI stepper tracks the exact lifecycle of a broadcast transaction (Processing → Sent → Confirmed/Failed).
- **Pull-to-refresh** — Pull down natively on the home screen to poll the blockchain for immediate balance updates.

## Architecture

The codebase is strictly layered. The Flutter application handles only presentation and state (MVVM), while the critical rules governing cryptography and transaction building live in a separate, isolated Rust workspace (`fortresswallet`).

### Layers

| Layer | Responsibility | May not |
|---|---|---|
| `wallet-core` (Rust) | Orchestrates Shamir shares, derives keys, builds EIP-1559 transactions | Perform I/O, interact with Flutter |
| `wallet-crypto` (Rust) | Cryptographic primitives (`secp256k1`, `argon2`, `xchacha20poly1305`) | Hold key material beyond a single call |
| `wallet-ffi` (Rust) | C-ABI bridge exposing capabilities via JSON string messaging | Contain validation rules of its own |
| `lib/core/services` (Dart) | Interacting with the Rust bridge and local device storage | Hold anything secret in memory longer than needed |
| `lib/features/` (Dart) | MVVM session state and UI rendering | Contain any cryptographic logic |

### Where the important decisions live

- **Cryptographic Signing** — `fortresswallet/crates/wallet-core`. Keys are reconstructed in Rust memory, used to sign the RLP-encoded transaction, and immediately zeroed.
- **The Untrusted Boundary** — `lib/features/send/ui/viewmodels/send_viewmodel.dart`. Transaction receipts are polled via standard HTTP JSON-RPC calls. The responses strictly control the UI state but cannot influence the signed payload.

## Security model

### What secrets exist
Exactly one: the BIP39 recovery phrase (and its resulting private key). Everything else — addresses, public keys, balances, transaction history — is public by nature.
The private key is not a separate permanent secret. It is re-derived from the Shamir shares whenever it is needed and zeroed immediately after use.

### Where they live
The shares are encrypted with AES-256-GCM / XChaCha20-Poly1305 under a key derived from the user's passcode (Argon2id). The resulting ciphertext is stored via local device storage. If a passcode is wrong, decryption fails cryptographically—preventing offline brute force attacks from bypassing an internal boolean check.

### What is trusted
- The device's hardware keystore and local storage sandbox.
- The audited Rust cryptographic libraries: `k256`, `argon2`, `chacha20poly1305`, `rand`. No low-level cryptographic primitive is implemented natively in this repository.
- The platform CSPRNG.

### What is not trusted
- **The RPC Node (Block Explorer)**. It can lie about balances, nonces, and broadcast results. However, it never sees key material, and every transaction is built and signed locally, so it cannot forge a signature or cause funds to move to an address the user did not enter.
- **Everything the user types**, and everything on the device outside the secure sandbox.

### How transactions are protected
- **Format Validation** — The destination address is validated for valid hex format (`0x...`).
- **Gas Bounding** — Transactions use standard 21,000 gas limits for base transfers. 
- **Point of Signing** — The passcode is required immediately before signing. The Rust FFI takes the encrypted shares, the passcode, and the transaction intent, decrypts, signs, and returns only the finalized raw transaction. 
- **Receipt Polling** — After broadcast, the UI continuously polls the network for the transaction receipt, actively waiting for network consensus.

## Threat model

| Threat | Mitigation | Residual risk |
|---|---|---|
| Malware on the device reading app storage | Ciphertext is useless without the user's passcode / Argon2id derived key | An attacker with a rooted device and the user's passcode can decrypt the vault |
| Offline brute force of an extracted vault | Argon2id key derivation makes brute-forcing computationally expensive | Weak passcodes (e.g. 4-digits) are mathematically vulnerable to brute-force regardless of Argon2id |
| Malicious or compromised RPC Node | Transaction built and signed locally | Can deny service, lie about balances, and censor transactions, but cannot steal funds |
| Float rounding losing value | Amount conversion to Wei (`10^18`) relies on precise string parsing / BigInt logic | None known |
| Secrets in logs | Sensitive shares and passwords are never logged out to the Flutter console | A native memory crash dump is outside the app's control |

## Local development

Requires Flutter SDK (≥ 3.19), a JDK, Xcode (for iOS/macOS), Android SDK, and the Rust toolchain (`cargo`). 

```bash
# Clone the repository
git clone <repository-url>

# Compile the Rust backend (if making modifications to fortresswallet)
cd fortresswallet
cargo build --release

# Run the Flutter App
cd ../fortress
flutter pub get
flutter run -d macos # Or ios, android
```

## Environment variables

There are none. Fortress Wallet requires no configuration to run, and there is no `.env.example` because there is nothing to put in it.

This is deliberate. Public EVM RPC nodes (like Publicnode or generic Infura endpoints) are hardcoded as defaults. There is no secret API key that could be baked into the bundle or extracted from the APK. 

## Limitations

- **Passcode Strength**: A numeric passcode is a weak secret. Argon2id raises the cost of searching that space, but an attacker who extracts the ciphertext from a rooted device can still search it. This is the single biggest weakness in the design.
- **Memory Scrubbing**: Private keys are zeroed after use in Rust, but the user's passphrase passes through immutable Dart strings that cannot be securely wiped until garbage collected by the Dart VM. 
- **Privacy**: No change-address rotation and no HD wallet gap-limit scanning. Every transaction is linkable to the single derived address. 
- **RPC Privacy**: The default RPC nodes see your addresses. No Tor or proxy support natively.
- **No Independent Audit**: Nothing here has been formally reviewed by an external auditing firm. Use at your own risk.

## License

MIT — see [LICENSE](LICENSE).
