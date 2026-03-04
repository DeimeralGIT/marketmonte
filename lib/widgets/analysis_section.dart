import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../models/analysis_models.dart';
import 'position_card.dart';

class AnalysisSection extends StatelessWidget {
  final CryptoAnalysisResult analysis;
  final String symbol;
  final double investmentAmount;
  final TimePeriod timePeriod;

  const AnalysisSection({
    super.key,
    required this.analysis,
    required this.symbol,
    required this.investmentAmount,
    required this.timePeriod,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Outlook card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                right: 0,
                child: Icon(
                  LucideIcons.brainCircuit,
                  size: 80,
                  color: AppColors.foreground.withValues(alpha: 0.1),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.info,
                        size: 18,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Outlook: $symbol',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    analysis.analysisSummary,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.mutedForeground,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Header
        Row(
          children: [
            const Icon(
              LucideIcons.layoutGrid,
              size: 18,
              color: AppColors.accent,
            ),
            const SizedBox(width: 8),
            const Text(
              'Recommended Positions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Position cards
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 600) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: analysis.positions.asMap().entries.map((entry) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: entry.key > 0 ? 12 : 0),
                      child: PositionCard(
                        rank: entry.key + 1,
                        symbol: symbol,
                        investmentAmount: investmentAmount,
                        timePeriod: timePeriod,
                        entryPrice: entry.value.entryPrice,
                        exitPrice: entry.value.exitPrice,
                        predictedROI: entry.value.predictedROI,
                        confidenceScore: entry.value.confidenceScore,
                        strategyDescription: entry.value.strategyDescription,
                      ),
                    ),
                  );
                }).toList(),
              );
            }
            return Column(
              children: analysis.positions.asMap().entries.map((entry) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: entry.key < analysis.positions.length - 1 ? 16 : 0,
                  ),
                  child: PositionCard(
                    rank: entry.key + 1,
                    symbol: symbol,
                    investmentAmount: investmentAmount,
                    timePeriod: timePeriod,
                    entryPrice: entry.value.entryPrice,
                    exitPrice: entry.value.exitPrice,
                    predictedROI: entry.value.predictedROI,
                    confidenceScore: entry.value.confidenceScore,
                    strategyDescription: entry.value.strategyDescription,
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
