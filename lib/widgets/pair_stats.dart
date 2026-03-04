import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class PairStats extends StatelessWidget {
  final Map<String, dynamic> ticker;
  final String symbol;

  const PairStats({super.key, required this.ticker, required this.symbol});

  @override
  Widget build(BuildContext context) {
    final lastPrice =
        double.tryParse(ticker['lastPrice']?.toString() ?? '0') ?? 0;
    final highPrice =
        double.tryParse(ticker['highPrice']?.toString() ?? '0') ?? 0;
    final lowPrice =
        double.tryParse(ticker['lowPrice']?.toString() ?? '0') ?? 0;
    final volume = double.tryParse(ticker['volume']?.toString() ?? '0') ?? 0;
    final priceChangePercent =
        double.tryParse(ticker['priceChangePercent']?.toString() ?? '0') ?? 0;
    final isUp = priceChangePercent >= 0;
    final baseAsset = symbol.replaceAll('USDT', '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Main price hero ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.secondary.withValues(alpha: 0.5),
                  AppColors.secondary.withValues(alpha: 0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.lineChart,
                    size: 20,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURRENT PRICE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '\$${formatPrice(lastPrice)}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: AppColors.foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (isUp
                                ? const Color(0xFF4ADE80)
                                : const Color(0xFFF87171))
                            .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          (isUp
                                  ? const Color(0xFF4ADE80)
                                  : const Color(0xFFF87171))
                              .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isUp
                            ? LucideIcons.trendingUp
                            : LucideIcons.trendingDown,
                        size: 14,
                        color: isUp
                            ? const Color(0xFF4ADE80)
                            : const Color(0xFFF87171),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${isUp ? '+' : ''}${priceChangePercent.toStringAsFixed(2)}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: isUp
                              ? const Color(0xFF4ADE80)
                              : const Color(0xFFF87171),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── 24h stats row: scrollable chips ──
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _StatChip(
                  icon: LucideIcons.arrowUp,
                  iconColor: const Color(0xFF4ADE80),
                  label: '24h High',
                  value: '\$${formatPrice(highPrice)}',
                ),
                const SizedBox(width: 8),
                _StatChip(
                  icon: LucideIcons.arrowDown,
                  iconColor: const Color(0xFFF87171),
                  label: '24h Low',
                  value: '\$${formatPrice(lowPrice)}',
                ),
                const SizedBox(width: 8),
                _StatChip(
                  icon: LucideIcons.barChart3,
                  iconColor: AppColors.accent,
                  label: 'Volume',
                  value: '${formatVolume(volume)} $baseAsset',
                ),
                // Trailing space so last chip doesn't hug the edge
                const SizedBox(width: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatChip({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
