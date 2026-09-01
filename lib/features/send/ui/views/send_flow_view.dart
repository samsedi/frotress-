import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/rust_bridge_service.dart';
import '../viewmodels/send_viewmodel.dart';

class SendFlowView extends StatefulWidget {
  final AssetData asset;
  const SendFlowView({super.key, required this.asset});

  @override
  State<SendFlowView> createState() => _SendFlowViewState();
}

class _SendFlowViewState extends State<SendFlowView> {
  late SendViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = SendViewModel(RustBridgeService(), asset: widget.asset);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLightBlue,
      appBar: AppBar(
        title: const Text('Send Funds'),
        leading: _viewModel.currentStep != SendStep.recipientAndAmount && _viewModel.currentStep != SendStep.transactionStatus
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _viewModel.previousStep,
              )
            : const BackButton(),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress Indicator
              if (_viewModel.currentStep != SendStep.transactionStatus)
                Row(
                  children: List.generate(3, (index) {
                    bool isActive = index <= _viewModel.currentStep.index;
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 4,
                        decoration: BoxDecoration(
                          color: isActive ? AppTheme.surfaceDark : AppTheme.surfaceDark.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              const SizedBox(height: 32),

              // Dynamic Step Content
              Expanded(
                child: _buildCurrentStep(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_viewModel.currentStep) {
      case SendStep.recipientAndAmount:
        return _RecipientAmountStep(viewModel: _viewModel);
      case SendStep.feeReview:
        return _FeeReviewStep(viewModel: _viewModel);
      case SendStep.confirmSummary:
        return _ConfirmSummaryStep(viewModel: _viewModel);
      case SendStep.transactionStatus:
        return _TransactionStatusStep(viewModel: _viewModel);
    }
  }
}

// ---------------------------------------------------------
// STEP 1: Recipient and Amount
// ---------------------------------------------------------
class _RecipientAmountStep extends StatelessWidget {
  final SendViewModel viewModel;
  const _RecipientAmountStep({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'WHO ARE YOU SENDING TO?',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: viewModel.updateRecipient,
          decoration: InputDecoration(
            hintText: '0x...',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'AMOUNT (${viewModel.asset.symbol})',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: viewModel.updateAmount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: '0.00',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: viewModel.canProceedToFeeReview ? viewModel.nextStep : null,
          child: const Text('CONTINUE TO FEE'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------
// STEP 2: Fee Review
// ---------------------------------------------------------
class _FeeReviewStep extends StatelessWidget {
  final SendViewModel viewModel;
  const _FeeReviewStep({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(
            children: [
              Text('ESTIMATED NETWORK FEE', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 16),
              Text('${viewModel.estimatedFeeEth} ${viewModel.asset.network.currencySymbol}', style: Theme.of(context).textTheme.displayMedium),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade900, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This is a simplified heuristic. The final fee will be calculated by the network upon broadcast.',
                        style: TextStyle(color: Colors.blue.shade900, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: viewModel.nextStep,
          child: const Text('REVIEW SUMMARY'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------
// STEP 3: Confirm Summary
// ---------------------------------------------------------
class _ConfirmSummaryStep extends StatefulWidget {
  final SendViewModel viewModel;
  const _ConfirmSummaryStep({required this.viewModel});

  @override
  State<_ConfirmSummaryStep> createState() => _ConfirmSummaryStepState();
}

class _ConfirmSummaryStepState extends State<_ConfirmSummaryStep> {
  bool _obscurePassphrase = true;

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: AppTheme.surfaceDark, borderRadius: BorderRadius.circular(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('LAST CHANCE TO REVIEW', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textLight)),
              const SizedBox(height: 32),
              _buildSummaryRow('TO', viewModel.recipientAddress),
              const Divider(color: Colors.white24, height: 32),
              _buildSummaryRow('AMOUNT', '${viewModel.amountStr} ${viewModel.asset.symbol}'),
              const Divider(color: Colors.white24, height: 32),
              _buildSummaryRow('FEE', '${viewModel.estimatedFeeEth} ${viewModel.asset.network.currencySymbol}'),
              const Divider(color: Colors.white24, height: 32),
              _buildSummaryRow('NETWORK', viewModel.asset.network.name),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (viewModel.errorMsg != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
            child: Text(viewModel.errorMsg!, style: TextStyle(color: Colors.red.shade900)),
          ),
          const SizedBox(height: 16),
        ],
        Text('WALLET PASSPHRASE', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 12),
        TextField(
          onChanged: viewModel.updatePassphrase,
          obscureText: _obscurePassphrase,
          decoration: InputDecoration(
            hintText: 'Enter your passphrase to sign',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassphrase ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
              onPressed: () => setState(() => _obscurePassphrase = !_obscurePassphrase),
            ),
          ),
        ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: viewModel.canSign ? viewModel.nextStep : null,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
          child: const Text('CONFIRM & SIGN'),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------
// STEP 4: Transaction Status (Vertical Timeline)
// ---------------------------------------------------------
class _TransactionStatusStep extends StatelessWidget {
  final SendViewModel viewModel;
  const _TransactionStatusStep({required this.viewModel});

  Future<void> _openExplorer() async {
    final hash = viewModel.txHash;
    if (hash == null) return;
    final chainId = viewModel.asset.network.chainId;
    String urlStr = '';
    if (chainId == 11155111) {
      urlStr = 'https://sepolia.etherscan.io/tx/$hash';
    } else if (chainId == 1) {
      urlStr = 'https://etherscan.io/tx/$hash';
    } else if (chainId == 137) {
      urlStr = 'https://polygonscan.com/tx/$hash';
    } else if (chainId == 56) {
      urlStr = 'https://bscscan.com/tx/$hash';
    }
    
    if (urlStr.isNotEmpty) {
      final url = Uri.parse(urlStr);
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = viewModel.timelineState;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Transaction Status',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        Expanded(
          child: ListView(
            children: [
              _buildTimelineStep(
                context,
                title: 'Request Submitted',
                subtitle: 'Your transfer request is registered.',
                isActive: state.index >= TimelineState.submitted.index,
                isCurrent: state == TimelineState.submitted,
                isLast: false,
              ),
              _buildTimelineStep(
                context,
                title: 'Processing',
                subtitle: 'Running security checks & cryptographic signing.',
                isActive: state.index >= TimelineState.processing.index,
                isCurrent: state == TimelineState.processing,
                isLast: false,
              ),
              _buildTimelineStep(
                context,
                title: 'Sent',
                subtitle: 'Transaction broadcasted to blockchain network.',
                isActive: state.index >= TimelineState.sent.index,
                isCurrent: state == TimelineState.sent,
                isLast: false,
                extraContent: state.index >= TimelineState.sent.index && viewModel.txHash != null
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                        child: Text(
                          'TXID: ${viewModel.txHash}',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black54),
                        ),
                      )
                    : null,
              ),
              _buildTimelineStep(
                context,
                title: state == TimelineState.failed ? 'Transaction Failed' : 'Transaction Successful',
                subtitle: state == TimelineState.failed
                    ? 'The transaction was rejected by the network or smart contract.'
                    : 'The destination network has confirmed the transfer.',
                isActive: state.index >= TimelineState.confirmed.index,
                isCurrent: state == TimelineState.confirmed || state == TimelineState.failed,
                isLast: true,
                isFailed: state == TimelineState.failed,
              ),
            ],
          ),
        ),
        if (state.index >= TimelineState.sent.index)
          TextButton.icon(
            onPressed: _openExplorer,
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('View on Explorer'),
          ),
        const SizedBox(height: 16),
        if (state == TimelineState.confirmed || state == TimelineState.failed)
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('BACK TO HOME'),
          ),
      ],
    );
  }

  Widget _buildTimelineStep(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool isActive,
    required bool isCurrent,
    required bool isLast,
    bool isFailed = false,
    Widget? extraContent,
  }) {
    Color dotColor = Colors.grey.shade300;
    if (isActive) dotColor = Colors.green;
    if (isFailed && isCurrent) dotColor = Colors.red;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCurrent && !isFailed ? Colors.orange : dotColor,
                  ),
                  child: isCurrent && !isFailed
                      ? const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(
                          isFailed ? Icons.close : Icons.check,
                          size: 16,
                          color: Colors.white,
                        ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isActive && !isCurrent ? Colors.green : Colors.grey.shade300,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.black87 : Colors.black38,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: isActive ? Colors.black54 : Colors.black26,
                    ),
                  ),
                  if (extraContent != null) extraContent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
