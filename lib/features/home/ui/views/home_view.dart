import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/network_config.dart';
import '../../../../core/services/rust_bridge_service.dart';
import '../../../../core/services/price_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../receive/ui/views/receive_view.dart';
import '../../../send/ui/views/send_flow_view.dart';
import '../../../settings/ui/views/settings_view.dart';
import '../../../history/ui/views/asset_detail_view.dart';
import '../../../../core/utils/error_mapper.dart';

class AssetData {
  final EvmNetwork network;
  final TokenConfig? token;
  final WalletBalance? balance;
  final double? livePriceUsd;

  AssetData({
    required this.network,
    this.token,
    this.balance,
    this.livePriceUsd,
  });

  String get name => token?.name ?? network.name;
  String get symbol => token?.symbol ?? network.currencySymbol;
  String get balanceFormatted => balance?.formatWithDecimals(token?.decimals ?? 18) ?? '---';

  double? get fiatBalance {
    if (balance == null || livePriceUsd == null) return null;
    final value = double.tryParse(balanceFormatted);
    if (value == null) return null;
    return value * livePriceUsd!;
  }
}

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final _rustBridgeService = RustBridgeService();
  final _priceService = PriceService();

  String _getNetworkIconUrl(int chainId) {
    switch (chainId) {
      case 1:
      case 11155111:
        return 'https://cryptologos.cc/logos/ethereum-eth-logo.png';
      case 137:
        return 'https://cryptologos.cc/logos/polygon-matic-logo.png';
      case 56:
        return 'https://cryptologos.cc/logos/bnb-bnb-logo.png';
      default:
        return 'https://cryptologos.cc/logos/ethereum-eth-logo.png';
    }
  }

  String _getAssetIconUrl(AssetData asset) {
    if (asset.token != null) {
      if (asset.token!.symbol == 'USDT') return 'https://cryptologos.cc/logos/tether-usdt-logo.png';
      if (asset.token!.symbol == 'USDC') return 'https://cryptologos.cc/logos/usd-coin-usdc-logo.png';
      return asset.token!.iconUrl ?? '';
    }
    return _getNetworkIconUrl(asset.network.chainId);
  }

  String? _address;
  List<AssetData> _assets = [];
  String? _errorMessage;
  bool _loading = true;
  bool _hideBalance = false;
  EvmNetwork _network = NetworkConfig.defaultNetwork;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _onNetworkChanged(EvmNetwork? network) {
    if (network == null || network == _network) return;
    setState(() {
      _network = network;
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final address = await _rustBridgeService.getAddress();
      if (!mounted) return;
      
      final chainIds = NetworkConfig.all.map((n) => n.chainId).toList();
      final prices = await _priceService.fetchPrices(chainIds);

      // 1. Build initial placeholder assets instantly
      final placeholderAssets = <AssetData>[];
      for (final network in NetworkConfig.all) {
        placeholderAssets.add(AssetData(
          network: network,
          token: null,
          balance: null,
          livePriceUsd: prices[network.chainId],
        ));
        for (final token in network.tokens) {
          placeholderAssets.add(AssetData(
            network: network,
            token: token,
            balance: null,
            livePriceUsd: 1.0,
          ));
        }
      }

      setState(() {
        _address = address;
        _assets = placeholderAssets;
        _loading = false;
      });

      // 2. Fetch balances concurrently and update UI progressively
      for (int i = 0; i < placeholderAssets.length; i++) {
        final asset = placeholderAssets[i];
        
        Future(() async {
          try {
            WalletBalance? bal;
            if (asset.token == null) {
              bal = await _rustBridgeService.getBalance(
                rpcUrls: asset.network.rpcUrls,
                chainId: asset.network.chainId,
              );
            } else {
              bal = await _rustBridgeService.getErc20Balance(
                rpcUrls: asset.network.rpcUrls,
                chainId: asset.network.chainId,
                tokenAddress: asset.token!.contractAddress,
              );
            }
            if (mounted) {
              setState(() {
                _assets[i] = AssetData(
                  network: asset.network,
                  token: asset.token,
                  balance: bal,
                  livePriceUsd: asset.livePriceUsd,
                );
              });
            }
          } catch (e) {
            print('Failed to get balance for \${asset.name}: \$e');
          }
        });
      }

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = ErrorMapper.mapErrorToUserFriendlyMessage(e);
        _loading = false;
      });
    }
  }

  double get _totalFiatBalance {
    double total = 0.0;
    for (final asset in _assets) {
      total += asset.fiatBalance ?? 0.0;
    }
    return total;
  }

  void _copyAddress() {
    if (_address != null) {
      Clipboard.setData(ClipboardData(text: _address!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address copied to clipboard'), duration: Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLightBlue,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    children: [
                      // Top Bar: Logo and Network Selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withOpacity(0.05),
                            ),
                            child: const Icon(Icons.wallet, color: AppTheme.textDark),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _hideBalance = !_hideBalance;
                              });
                            },
                            icon: Icon(
                              _hideBalance ? Icons.visibility_off : Icons.visibility,
                              size: 24,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      
                      // Centered Balance Area
                      Text(
                        'Total Balance',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textDark.withOpacity(0.6),
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 8),
                      if (_loading && _assets.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.0),
                          child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      else if (_errorMessage != null && _assets.isEmpty)
                        Text(
                          'Error',
                          style: Theme.of(context).textTheme.displayMedium?.copyWith(color: Colors.red),
                        )
                      else
                        Text(
                          _hideBalance ? '****' : '\$${_totalFiatBalance.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 44,
                              ),
                        ),
                      const SizedBox(height: 8),
                      
                      // Address with Copy Icon
                      GestureDetector(
                        onTap: _copyAddress,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _address == null ? 'Loading...' : _truncateAddress(_address!),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textDark.withOpacity(0.8),
                                    ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.copy, size: 14, color: AppTheme.textDark.withOpacity(0.8)),
                            ],
                          ),
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.red.shade700),
                        ),
                      ],
                      const SizedBox(height: 40),
                      
                      // Quick Actions Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActionIcon(
                            context: context,
                            icon: Icons.arrow_downward,
                            label: 'Receive',
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceiveView()));
                            },
                          ),
                          _buildActionIcon(
                            context: context,
                            icon: Icons.arrow_upward,
                            label: 'Send',
                            onTap: () {
                              _showAssetSelectorForSend(context);
                            },
                          ),
                          _buildActionIcon(
                            context: context,
                            icon: Icons.settings,
                            label: 'Settings',
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsView()));
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              
              // Assets List
              SliverFillRemaining(
                hasScrollBody: false,
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppTheme.surfaceDark, // Dark theme for assets section
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  padding: const EdgeInsets.only(top: 32.0, left: 24.0, right: 24.0, bottom: 40.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tokens',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 24),
                      if (_loading && _assets.isEmpty)
                        const Center(child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ))
                      else
                        ..._assets.map((asset) => _buildAssetRow(asset)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionIcon({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.black, // Dark button on light background
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
        ),
      ],
    );
  }

  Widget _buildAssetRow(AssetData asset) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AssetDetailView(
              asset: asset,
              assetIconUrl: _getAssetIconUrl(asset),
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20.0),
        child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white12, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.network(
                      _getAssetIconUrl(asset),
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Text(
                          asset.symbol[0],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (asset.token != null)
                  Positioned(
                    bottom: 0,
                    right: 4,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.surfaceDark, width: 2),
                      ),
                      child: ClipOval(
                        child: Image.network(
                          _getNetworkIconUrl(asset.network.chainId),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  asset.livePriceUsd != null ? '\$${asset.livePriceUsd!.toStringAsFixed(2)}' : 'Price unavail.', 
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _hideBalance 
                    ? '****' 
                    : '${(double.tryParse(asset.balanceFormatted) ?? 0).toStringAsFixed(2)} ${asset.symbol}', 
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  String _truncateAddress(String address) {
    if (address.length <= 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  void _showAssetSelectorForSend(BuildContext context) {
    if (_assets.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('Select Asset to Send', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _assets.length,
                  itemBuilder: (context, index) {
                    final asset = _assets[index];
                    return ListTile(
                      leading: Image.network(_getAssetIconUrl(asset), width: 32, height: 32, errorBuilder: (_,__,___) => const Icon(Icons.monetization_on, color: Colors.white)),
                      title: Text(asset.name, style: const TextStyle(color: Colors.white)),
                      subtitle: Text(asset.network.name, style: const TextStyle(color: Colors.white54)),
                      trailing: Text(
                        _hideBalance ? '****' : '${(double.tryParse(asset.balanceFormatted) ?? 0).toStringAsFixed(2)} ${asset.symbol}', 
                        style: const TextStyle(color: Colors.white)
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => SendFlowView(asset: asset))).then((_) {
                          if (mounted) {
                            _load();
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
