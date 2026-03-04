import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class PairStats extends StatelessWidget {
  final Map<String, dynamic> ticker;
  final String symbol;

  const PairStats({
    super.key,
    required this.ticker,
    required this.symbol,
  });

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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _StatCard(
              label: 'Price',
              value: '\$${formatPrice(lastPrice)}',
              icon: LucideIcons.lineChart,
              iconColor: AppColors.accent,
              subtitle:
                  '${isUp ? '▲' : '▼'} ${priceChangePercent.toStringAsFixed(2)}% (24h)',
              subtitleColor:
                  isUp ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
            ),
            const SizedBox(width: 12),
            _StatCard(
              label: '24h High',
              value: '\$${formatPrice(highPrice)}',
              icon: LucideIcons.barChart3,
              iconColor: AppColors.mutedForeground,
            ),
            const SizedBox(width: 12),
            _StatCard(
              label: '24h Low',
              value: '\$${formatPrice(lowPrice)}',
              icon: LucideIcons.barChart3,
              iconColor: AppColors.mutedForeground,
            ),
            const SizedBox(width: 12),
            _StatCard(
              label: 'Volume',
              value: '${formatVolume(volume)} $baseAsset',
              icon: LucideIcons.refreshCw,
              iconColor: AppColors.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final String? subtitle;
  final Color? subtitleColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.subtitle,
    this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.mutedForeground,
                ),
              ),
              Icon(icon, size: 16, color: iconColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: AppColors.foreground,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: subtitleColor ?? AppColors.mutedForeground,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
