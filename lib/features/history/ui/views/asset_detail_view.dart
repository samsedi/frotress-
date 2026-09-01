import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/explorer_service.dart';
import '../../../home/ui/views/home_view.dart';
import '../viewmodels/history_viewmodel.dart';
import 'dart:math' as math;

class AssetDetailView extends StatefulWidget {
  final AssetData asset;
  final String assetIconUrl;

  const AssetDetailView({
    super.key,
    required this.asset,
    required this.assetIconUrl,
  });

  @override
  State<AssetDetailView> createState() => _AssetDetailViewState();
}

class _AssetDetailViewState extends State<AssetDetailView> {
  late HistoryViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = HistoryViewModel(
      network: widget.asset.network,
      token: widget.asset.token,
    );
    _viewModel.addListener(_onViewModelUpdate);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelUpdate);
    _viewModel.dispose();
    super.dispose();
  }

  void _onViewModelUpdate() {
    setState(() {});
  }

  String _formatAmount(String value, String decimals) {
    try {
      final v = double.parse(value);
      final d = int.parse(decimals);
      final num amount = v / math.pow(10, d);
      // Format to max 6 decimal places cleanly
      String formatted = amount.toStringAsFixed(6);
      formatted = formatted.replaceAll(RegExp(r'0*$'), '');
      formatted = formatted.replaceAll(RegExp(r'\.$'), '');
      return formatted;
    } catch (e) {
      return value;
    }
  }

  void _openExplorer(String hash) async {
    String? baseUrl;
    // Derive block explorer base url from api url
    if (widget.asset.network.explorerApiUrl != null) {
      final apiUrl = widget.asset.network.explorerApiUrl!;
      if (apiUrl.contains('etherscan.io')) {
        baseUrl = 'https://etherscan.io';
      } else if (apiUrl.contains('polygonscan.com')) {
        baseUrl = 'https://polygonscan.com';
      } else if (apiUrl.contains('bscscan.com')) {
        baseUrl = 'https://bscscan.com';
      } else if (apiUrl.contains('api-sepolia.etherscan.io')) {
        baseUrl = 'https://sepolia.etherscan.io';
      }
    }
    
    if (baseUrl != null) {
      final uri = Uri.parse('$baseUrl/tx/$hash');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isToken = widget.asset.token != null;
    final title = isToken 
        ? '${widget.asset.name} (${widget.asset.network.name})' 
        : widget.asset.name;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLightBlue,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textDark),
        title: Text(title, style: const TextStyle(color: AppTheme.textDark)),
      ),
      body: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white,
                  backgroundImage: widget.assetIconUrl.isNotEmpty
                      ? NetworkImage(widget.assetIconUrl)
                      : null,
                  child: widget.assetIconUrl.isEmpty
                      ? Text(widget.asset.symbol[0], style: const TextStyle(color: Colors.black, fontSize: 24))
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  '${(double.tryParse(widget.asset.balanceFormatted) ?? 0).toStringAsFixed(2)} ${widget.asset.symbol}',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
          ),
          
          // Transactions List
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                child: _buildTransactionsContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _truncateAddress(String addr) {
    if (addr.length <= 10) return addr;
    return '${addr.substring(0, 4)}...${addr.substring(addr.length - 4)}';
  }

  Widget _buildTransactionsContent() {
    if (_viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                'Failed to load history',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _viewModel.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _viewModel.loadTransactions,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_viewModel.transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No transactions found', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _viewModel.transactions.length,
      itemBuilder: (context, index) {
        final tx = _viewModel.transactions[index];
        
        final formattedAmount = _formatAmount(tx.value, tx.tokenDecimal);
        final displaySymbol = tx.tokenSymbol.isNotEmpty ? tx.tokenSymbol : widget.asset.symbol;
        
        final isSent = _viewModel.walletAddress != null && tx.from.toLowerCase() == _viewModel.walletAddress!.toLowerCase();
        
        String title;
        String subtitle;
        Color amountColor;
        String amountPrefix;
        IconData badgeIcon;
        Color badgeColor;

        if (tx.isError) {
          title = 'Failed transaction';
          subtitle = 'Unknown';
          amountColor = Colors.grey;
          amountPrefix = '';
          badgeIcon = Icons.close;
          badgeColor = Colors.redAccent;
        } else if (isSent) {
          title = 'Sent';
          subtitle = 'To ${_truncateAddress(tx.to)}';
          amountColor = Colors.black;
          amountPrefix = '-';
          badgeIcon = Icons.arrow_upward;
          badgeColor = Colors.blue;
        } else {
          title = 'Received';
          subtitle = 'From ${_truncateAddress(tx.from)}';
          amountColor = Colors.green;
          amountPrefix = '+';
          badgeIcon = Icons.arrow_downward;
          badgeColor = Colors.purpleAccent;
        }
        
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          color: Colors.grey.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            onTap: () => _openExplorer(tx.hash),
            leading: SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: widget.assetIconUrl.isNotEmpty
                        ? NetworkImage(widget.assetIconUrl)
                        : null,
                    child: widget.assetIconUrl.isEmpty
                        ? Text(widget.asset.symbol[0], style: const TextStyle(color: Colors.black, fontSize: 16))
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade50, width: 2),
                      ),
                      child: Icon(badgeIcon, color: Colors.white, size: 10),
                    ),
                  ),
                ],
              ),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
            ),
            subtitle: Text(
              subtitle,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$amountPrefix$formattedAmount $displaySymbol',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: amountColor,
                  ),
                ),
                if (widget.asset.livePriceUsd != null)
                  Text(
                    '$amountPrefix\$${((double.tryParse(formattedAmount) ?? 0) * widget.asset.livePriceUsd!).toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
