import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/crypto_names.dart';
import 'crypto_icon.dart';

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
                CryptoIcon(symbol: symbol, size: 40),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            baseAsset,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.foreground,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              cryptoName(symbol),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.mutedForeground,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '\$${formatPrice(lastPrice)}',
                          style: TextStyle(
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
                  label: tr('pairStats.high24h'),
                  value: '\$${formatPrice(highPrice)}',
                ),
                const SizedBox(width: 8),
                _StatChip(
                  icon: LucideIcons.arrowDown,
                  iconColor: const Color(0xFFF87171),
                  label: tr('pairStats.low24h'),
                  value: '\$${formatPrice(lowPrice)}',
                ),
                const SizedBox(width: 8),
                _StatChip(
                  icon: LucideIcons.barChart3,
                  iconColor: AppColors.accent,
                  label: tr('pairStats.volume'),
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
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: TextStyle(
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

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton loader – shown while new ticker data is being fetched
// ─────────────────────────────────────────────────────────────────────────────

class PairStatsSkeleton extends StatefulWidget {
  const PairStatsSkeleton({super.key});

  @override
  State<PairStatsSkeleton> createState() => _PairStatsSkeletonState();
}

class _PairStatsSkeletonState extends State<PairStatsSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.3,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _bone({double width = 80, double height = 14, double radius = 6}) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          color: AppColors.mutedForeground.withValues(
            alpha: _animation.value * 0.25,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Main hero skeleton ──
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
                // Icon placeholder (circle)
                _bone(width: 40, height: 40, radius: 20),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name line
                      _bone(width: 100, height: 14, radius: 6),
                      const SizedBox(height: 8),
                      // Price line
                      _bone(width: 160, height: 24, radius: 6),
                    ],
                  ),
                ),
                // Percent badge placeholder
                _bone(width: 72, height: 28, radius: 8),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Stat chips skeleton ──
          SizedBox(
            height: 56,
            child: Row(
              children: [
                Expanded(child: _chipBone()),
                const SizedBox(width: 8),
                Expanded(child: _chipBone()),
                const SizedBox(width: 8),
                Expanded(child: _chipBone()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipBone() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          _bone(width: 14, height: 14, radius: 7),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bone(width: 40, height: 8, radius: 4),
                const SizedBox(height: 4),
                _bone(width: 60, height: 12, radius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
