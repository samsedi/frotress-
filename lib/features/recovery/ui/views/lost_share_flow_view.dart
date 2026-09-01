import 'package:flutter/material.dart';
import '../viewmodels/recovery_viewmodel.dart';

class LostShareFlowView extends StatefulWidget {
  const LostShareFlowView({super.key});

  @override
  State<LostShareFlowView> createState() => _LostShareFlowViewState();
}

class _LostShareFlowViewState extends State<LostShareFlowView> {
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
        title: const Text('Lost Share Recovery', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
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
              color: isActive ? Colors.blueAccent : Colors.white24,
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
        const Text('STEP 1: SURVIVING SHARES', style: TextStyle(color: Colors.white54, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        const Text('Enter your surviving seed phrases to reconstruct the master key. You need at least 2.', style: TextStyle(color: Colors.white)),
        const SizedBox(height: 24),
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
        const SizedBox(height: 16),
        TextField(
          maxLines: 2,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Share 2 Seed Phrase...',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: _viewModel.nextStep,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
          child: const Text('RECONSTRUCT KEY'),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(color: Colors.blueAccent),
        const SizedBox(height: 32),
        const Text('GENERATING FRESH SHARES...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        const Text('Your master key was successfully reconstructed. We are now generating a new set of Shamir shares to replace the old set.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
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
        const Text('SUCCESSFUL ROTATION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 16),
        const Text('Your shares have been rotated successfully. Your public address remains the same, but the old lost share is now cryptographically useless.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
        const Spacer(),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
          child: const Text('RETURN TO SETTINGS'),
        ),
      ],
    );
  }
}
