import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'lost_share_flow_view.dart';
import 'compromised_share_flow_view.dart';

class RecoveryHomeView extends StatelessWidget {
  const RecoveryHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A), // Stark dark background for serious actions
      appBar: AppBar(
        title: const Text('EMERGENCY RECOVERY', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'WHAT HAPPENED?',
                style: TextStyle(color: Colors.white54, letterSpacing: 2.0, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 32),
              
              _buildChoiceCard(
                context,
                title: 'I lost a device / share',
                description: 'One of my devices broke or was lost. I need to use my surviving shares to rotate the lost one and generate a fresh set.',
                icon: Icons.device_unknown,
                color: Colors.blueAccent,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LostShareFlowView()));
                },
              ),
              const SizedBox(height: 24),
              
              _buildChoiceCard(
                context,
                title: 'A share is compromised!',
                description: 'Someone may have stolen a device or seed phrase. I need a FULL key rotation to a completely new address and must migrate my funds immediately.',
                icon: Icons.warning_amber_rounded,
                color: Colors.redAccent,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CompromisedShareFlowView()));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceCard(BuildContext context, {required String title, required String description, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(width: 16),
                Expanded(child: Text(title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold))),
              ],
            ),
            const SizedBox(height: 16),
            Text(description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
