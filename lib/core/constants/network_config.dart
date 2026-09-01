class TokenConfig {
  final String name;
  final String symbol;
  final String contractAddress;
  final int decimals;
  final String? iconUrl;

  const TokenConfig({
    required this.name,
    required this.symbol,
    required this.contractAddress,
    this.decimals = 18,
    this.iconUrl,
  });
}

/// A selectable EVM-compatible network: chain ID, currency symbol, and at
/// least two independent public RPC endpoints for cross-checking (see
/// `wallet-ffi`'s `handle_get_balance` — a single lying or misconfigured
/// node must not be able to show a wrong balance without at least one
/// other endpoint being able to catch it).
class EvmNetwork {
  final String name;
  final int chainId;
  final String currencySymbol;
  final String? explorerApiUrl;
  final List<String> rpcUrls;
  final List<TokenConfig> tokens;

  const EvmNetwork({
    required this.name,
    required this.chainId,
    required this.currencySymbol,
    this.explorerApiUrl,
    required this.rpcUrls,
    this.tokens = const [],
  });

  // Compares by chain ID rather than object identity — the dropdown that
  // selects a network needs its current value to match an entry in its
  // items list by `==`, and relying on const-canonicalized identity for
  // that broke across a hot reload (the reload's new `EvmNetwork.all`
  // list and the still-live selected value ended up as distinct
  // instances of the same logical network).
  @override
  bool operator ==(Object other) => other is EvmNetwork && other.chainId == chainId;

  @override
  int get hashCode => chainId.hashCode;
}

/// Networks this wallet can query a balance on. The address itself is a
/// plain EVM address and can receive funds on any EVM chain regardless of
/// what's listed here — this list only controls what the app can *show*
/// you without leaving it for a block explorer.
///
/// This wallet's signing/crypto path has never been audited (see the
/// backend's own project history) — that risk applies to every network
/// below equally, mainnet included. Balance *display* is read-only and
/// carries no signing risk; sending funds is a separate, much higher-
/// stakes action.
class NetworkConfig {
  static EvmNetwork ethereumMainnet = const EvmNetwork(
    name: 'Ethereum',
    chainId: 1,
    currencySymbol: 'ETH',
    explorerApiUrl: 'https://eth.blockscout.com/api',
    // Two genuinely independent providers. cloudflare-eth.com was tried
    // first but dropped: it answers eth_chainId fine but throws -32603
    // Internal error on eth_getBalance, which broke every balance query
    // here (cross-check treats any endpoint's failure as untrustworthy).
    // Verified both eth_chainId and eth_getBalance succeed on both
    // endpoints below before hardcoding them.
    rpcUrls: [
      'https://ethereum-rpc.publicnode.com',
      'https://eth.drpc.org',
    ],
    tokens: [
      TokenConfig(
        name: 'Tether USD',
        symbol: 'USDT',
        contractAddress: '0xdac17f958d2ee523a2206206994597c13d831ec7',
        decimals: 6,
      ),
    ],
  );

  static EvmNetwork polygon = const EvmNetwork(
    name: 'Polygon',
    chainId: 137,
    currencySymbol: 'POL',
    explorerApiUrl: 'https://polygon.blockscout.com/api',
    rpcUrls: [
      'https://polygon-bor-rpc.publicnode.com',
      'https://polygon.drpc.org',
    ],
    tokens: [
      TokenConfig(
        name: 'Tether USD',
        symbol: 'USDT',
        contractAddress: '0xc2132D05D31c914a87C6611C10748AEb04B58e8F',
        decimals: 6,
      ),
    ],
  );

  static EvmNetwork bnbSmartChain = const EvmNetwork(
    name: 'BNB Smart Chain',
    chainId: 56,
    currencySymbol: 'BNB',
    explorerApiUrl: null, // Disabled: BscScan removed free tier, no public Blockscout available
    rpcUrls: [
      'https://bsc-rpc.publicnode.com',
      'https://bsc-dataseed.binance.org',
    ],
    tokens: [
      TokenConfig(
        name: 'Tether USD',
        symbol: 'USDT',
        contractAddress: '0x55d398326f99059fF775485246999027B3197955',
        decimals: 18, // BSC USDT uses 18 decimals!
      ),
    ],
  );

  static EvmNetwork sepolia = const EvmNetwork(
    name: 'Sepolia (testnet)',
    chainId: 11155111,
    currencySymbol: 'ETH',
    explorerApiUrl: 'https://eth-sepolia.blockscout.com/api',
    // Verified live (returned the correct 0xaa36a7 chain ID) before being
    // hardcoded here — the previous second entry, rpc.sepolia.org, was
    // dead (404 on every request) and broke every balance query, since
    // cross-check treats any endpoint's failure as untrustworthy rather
    // than silently ignoring it. Two genuinely independent providers, not
    // two subdomains of the same one — cross-checking two endpoints run
    // by the same operator wouldn't catch that operator lying.
    rpcUrls: [
      'https://ethereum-sepolia-rpc.publicnode.com',
      'https://gateway.tenderly.co/public/sepolia',
    ],
    tokens: [
      TokenConfig(
        name: 'USD Coin',
        symbol: 'USDC',
        contractAddress: '0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238',
        decimals: 6,
      ),
    ],
  );

  static List<EvmNetwork> all = [ethereumMainnet, polygon, bnbSmartChain, sepolia];

  static EvmNetwork defaultNetwork = ethereumMainnet;
}
