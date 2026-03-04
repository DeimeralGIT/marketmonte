import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:easy_localization/easy_localization.dart';
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

  // Regime colour mapping
  static Color _regimeColor(VolatilityRegime regime) {
    switch (regime) {
      case VolatilityRegime.low:
        return const Color(0xFF4ADE80); // green
      case VolatilityRegime.medium:
        return const Color(0xFFFACC15); // yellow
      case VolatilityRegime.high:
        return const Color(0xFFF87171); // red
    }
  }

  static IconData _regimeIcon(VolatilityRegime regime) {
    switch (regime) {
      case VolatilityRegime.low:
        return LucideIcons.shieldCheck;
      case VolatilityRegime.medium:
        return LucideIcons.trendingUp;
      case VolatilityRegime.high:
        return LucideIcons.alertTriangle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final regime = analysis.regimeInfo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Regime Detection Card ──
        if (regime != null) ...[
          _buildRegimeCard(regime),
          const SizedBox(height: 16),
        ],

        // ── Outlook card ──
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
                      Icon(LucideIcons.info, size: 18, color: AppColors.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tr('analysis.outlook', namedArgs: {'symbol': symbol}),
                          style: TextStyle(
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
            Icon(LucideIcons.layoutGrid, size: 18, color: AppColors.accent),
            const SizedBox(width: 8),
            Text(
              tr('analysis.recommendedPositions'),
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
                        direction: entry.value.direction,
                        entryPrice: entry.value.entryPrice,
                        exitPrice: entry.value.exitPrice,
                        stopLoss: entry.value.stopLoss,
                        predictedROI: entry.value.predictedROI,
                        confidenceScore: entry.value.confidenceScore,
                        tpProbability: entry.value.tpProbability,
                        slProbability: entry.value.slProbability,
                        expectedValue: entry.value.expectedValue,
                        positionSizePct: entry.value.positionSizePct,
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
                    direction: entry.value.direction,
                    entryPrice: entry.value.entryPrice,
                    exitPrice: entry.value.exitPrice,
                    stopLoss: entry.value.stopLoss,
                    predictedROI: entry.value.predictedROI,
                    confidenceScore: entry.value.confidenceScore,
                    tpProbability: entry.value.tpProbability,
                    slProbability: entry.value.slProbability,
                    expectedValue: entry.value.expectedValue,
                    positionSizePct: entry.value.positionSizePct,
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

  /// Builds the regime detection visualization card.
  Widget _buildRegimeCard(RegimeInfo regime) {
    final color = _regimeColor(regime.currentRegime);
    final icon = _regimeIcon(regime.currentRegime);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr(
                    'analysis.regimeDetection',
                    namedArgs: {'regime': _regimeLabel(regime.currentRegime)},
                  ),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              // Stability badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: color.withValues(alpha: 0.12),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  tr(
                    'analysis.stability',
                    namedArgs: {'score': regime.stabilityScore.toString()},
                  ),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _regimeDescription(regime.currentRegime),
            style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
          ),

          const SizedBox(height: 16),

          // Regime probability bars
          _buildRegimeProbBar(
            tr('analysis.lowVol'),
            regime.regimeProbs[0],
            const Color(0xFF4ADE80),
            regime.currentRegime == VolatilityRegime.low,
          ),
          const SizedBox(height: 8),
          _buildRegimeProbBar(
            tr('analysis.trending'),
            regime.regimeProbs[1],
            const Color(0xFFFACC15),
            regime.currentRegime == VolatilityRegime.medium,
          ),
          const SizedBox(height: 8),
          _buildRegimeProbBar(
            tr('analysis.highVol'),
            regime.regimeProbs[2],
            const Color(0xFFF87171),
            regime.currentRegime == VolatilityRegime.high,
          ),

          const SizedBox(height: 16),

          // Annualised volatility per regime
          Row(
            children: [
              _buildVolChip(
                tr('analysis.lowLabel'),
                regime.regimeAnnualisedVols[0],
                const Color(0xFF4ADE80),
              ),
              const SizedBox(width: 8),
              _buildVolChip(
                tr('analysis.medLabel'),
                regime.regimeAnnualisedVols[1],
                const Color(0xFFFACC15),
              ),
              const SizedBox(width: 8),
              _buildVolChip(
                tr('analysis.highLabel'),
                regime.regimeAnnualisedVols[2],
                const Color(0xFFF87171),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Engine label
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  LucideIcons.cpu,
                  size: 12,
                  color: AppColors.mutedForeground.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  tr('analysis.engineLabel'),
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.mutedForeground.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegimeProbBar(
    String label,
    double prob,
    Color color,
    bool isActive,
  ) {
    final pct = (prob * 100).toStringAsFixed(1);
    return Row(
      children: [
        SizedBox(
          width: 62,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? color : AppColors.mutedForeground,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 14,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              color: AppColors.secondary.withValues(alpha: 0.4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: prob.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  color: color.withValues(alpha: isActive ? 0.8 : 0.35),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 42,
          child: Text(
            '$pct%',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? color : AppColors.mutedForeground,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVolChip(String label, double annVol, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 10, color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 2),
            Text(
              '${annVol.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              tr('analysis.annVol'),
              style: TextStyle(
                fontSize: 9,
                color: AppColors.mutedForeground.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _regimeLabel(VolatilityRegime r) {
    switch (r) {
      case VolatilityRegime.low:
        return tr('regime.lowVolatility');
      case VolatilityRegime.medium:
        return tr('regime.mediumVolatility');
      case VolatilityRegime.high:
        return tr('regime.highVolatility');
    }
  }

  String _regimeDescription(VolatilityRegime r) {
    switch (r) {
      case VolatilityRegime.low:
        return tr('regime.lowDescription');
      case VolatilityRegime.medium:
        return tr('regime.mediumDescription');
      case VolatilityRegime.high:
        return tr('regime.highDescription');
    }
  }
}
