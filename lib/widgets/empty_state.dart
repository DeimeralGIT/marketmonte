import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.brainCircuit,
                size: 48,
                color: AppColors.mutedForeground.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ready for analysis',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 6),
            const SizedBox(
              width: 320,
              child: Text(
                'Select a pair for deep analysis or scan the top 10 market leaders to find high-ROI breakouts.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.mutedForeground,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
