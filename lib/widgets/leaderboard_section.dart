import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_theme.dart';
import '../models/analysis_models.dart';
import 'position_card.dart';

class LeaderboardSection extends StatelessWidget {
  final MarketLeaderboardResult leaderboard;
  final double investmentAmount;
  final TimePeriod timePeriod;

  const LeaderboardSection({
    super.key,
    required this.leaderboard,
    required this.investmentAmount,
    required this.timePeriod,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Global outlook card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    LucideIcons.trendingUp,
                    size: 18,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('leaderboard.globalScan'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                leaderboard.globalOutlook.translate(),
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.mutedForeground,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Header
        Row(
          children: [
            const Icon(LucideIcons.zap, size: 18, color: Color(0xFFFACC15)),
            const SizedBox(width: 8),
            Text(
              tr('leaderboard.topAlpha'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Position cards grid
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 900) {
              // 3 columns
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: leaderboard.topPicks.asMap().entries.map((entry) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: entry.key > 0 ? 12 : 0),
                      child: _buildPickCard(entry.key, entry.value),
                    ),
                  );
                }).toList(),
              );
            }
            // Single column
            return Column(
              children: leaderboard.topPicks.asMap().entries.map((entry) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: entry.key < leaderboard.topPicks.length - 1
                        ? 16
                        : 0,
                  ),
                  child: _buildPickCard(entry.key, entry.value),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPickCard(int index, LeadPosition pick) {
    return PositionCard(
      rank: index + 1,
      symbol: pick.symbol,
      investmentAmount: investmentAmount,
      timePeriod: timePeriod,
      direction: pick.direction,
      entryPrice: pick.entryPrice,
      exitPrice: pick.exitPrice,
      stopLoss: pick.stopLoss,
      predictedROI: pick.predictedROI,
      confidenceScore: pick.confidenceScore,
      expectedValue: pick.expectedValue,
      strategyDescription: pick.reasoning,
    );
  }
}
