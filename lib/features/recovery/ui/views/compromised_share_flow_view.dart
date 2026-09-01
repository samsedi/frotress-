import 'package:flutter/material.dart';
import '../viewmodels/recovery_viewmodel.dart';

class CompromisedShareFlowView extends StatefulWidget {
  const CompromisedShareFlowView({super.key});

  @override
  State<CompromisedShareFlowView> createState() => _CompromisedShareFlowViewState();
}

class _CompromisedShareFlowViewState extends State<CompromisedShareFlowView> {
  final RecoveryViewModel _viewModel = RecoveryViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: const Text('Emergency Rotation', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProgressBar(),
              const SizedBox(height: 32),
              Expanded(child: _buildCurrentStep()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Row(
      children: List.generate(3, (index) {
        bool isActive = index <= _viewModel.currentStep;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 4,
            decoration: BoxDecoration(
              color: isActive ? Colors.redAccent : Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCurrentStep() {
    switch (_viewModel.currentStep) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      default:
        return const SizedBox();
    }
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('CRITICAL WARNING', style: TextStyle(color: Colors.redAccent, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        const Text('Because a share is compromised, you must migrate to a completely NEW master key and NEW public address. Your old address is no longer safe.', style: TextStyle(color: Colors.white)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
          child: const Text('To begin, enter 2 surviving shares to sweep the remaining funds.', style: TextStyle(color: Colors.white)),
        ),
        const SizedBox(height: 16),
        TextField(
          maxLines: 2,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Share 1 Seed Phrase...',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: _viewModel.nextStep,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
          child: const Text('GENERATE NEW WALLET & SWEEP'),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(color: Colors.redAccent),
        const SizedBox(height: 32),
        const Text('SWEEPING FUNDS...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        const Text('Generating new master key and broadcasting a transaction to sweep all assets from the compromised address to the new safe address.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
        const Spacer(),
        ElevatedButton(
          onPressed: _viewModel.nextStep, // Mocking completion
          child: const Text('MOCK CONTINUE'),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 80),
        const SizedBox(height: 32),
        const Text('MIGRATION COMPLETE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 16),
        const Text('A new wallet has been created. The sweep transaction was broadcasted successfully. You MUST backup your new shares immediately.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
        const Spacer(),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text('BACKUP NEW SHARES'),
        ),
      ],
    );
  }
}
