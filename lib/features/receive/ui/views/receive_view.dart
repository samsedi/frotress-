import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/rust_bridge_service.dart';
import '../viewmodels/receive_viewmodel.dart';

class ReceiveView extends StatefulWidget {
  const ReceiveView({super.key});

  @override
  State<ReceiveView> createState() => _ReceiveViewState();
}

class _ReceiveViewState extends State<ReceiveView> {
  // We instantiate it here for simplicity, but in a real app use Provider/GetIt
  final ReceiveViewModel _viewModel = ReceiveViewModel(RustBridgeService());

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onViewModelUpdate);
    _viewModel.load();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLightBlue,
      appBar: AppBar(
        title: const Text('Receive Funds'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Warning card for Network
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0), // Light orange warning
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This address works on any EVM-compatible network (Ethereum, Polygon, BNB Smart Chain, and their tokens) — but this app only shows balances on the networks listed on the home screen. Never send funds on a non-EVM network (e.g. Bitcoin, Solana) to this address; that would result in permanent loss.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // QR Code and Address Card
              Container(
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceWhite,
                  borderRadius: BorderRadius.all(Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    if (_viewModel.isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48.0),
                        child: CircularProgressIndicator(),
                      )
                    else if (_viewModel.errorMessage != null || _viewModel.publicAddress == null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24.0),
                        child: Text(
                          _viewModel.errorMessage ?? 'Failed to load address',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      )
                    else ...[
                      Text(
                        'SCAN TO PAY',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.textLight,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.grey.shade100, width: 2),
                        ),
                        child: QrImageView(
                          data: _viewModel.publicAddress!,
                          version: QrVersions.auto,
                          size: 200.0,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: AppTheme.surfaceDark,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: AppTheme.surfaceDark,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'YOUR PUBLIC ADDRESS',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.textLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _viewModel.publicAddress!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace', // Monospace for crypto addresses
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _viewModel.copyToClipboard,
                        icon: Icon(_viewModel.isCopied ? Icons.check : Icons.copy, size: 18),
                        label: Text(_viewModel.isCopied ? 'COPIED!' : 'COPY ADDRESS'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _viewModel.isCopied ? Colors.green : AppTheme.surfaceDark,
                          minimumSize: const Size(double.infinity, 56), // Full width
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
