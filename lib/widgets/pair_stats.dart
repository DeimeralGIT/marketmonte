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
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.secondary.withValues(alpha: 0.5),
              AppColors.secondary.withValues(alpha: 0.15),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            // ── Hero price section ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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

            // ── Divider ──
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: AppColors.border.withValues(alpha: 0.3),
            ),

            // ── 24h stats grid ──
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _StatCell(
                        icon: LucideIcons.arrowUp,
                        iconColor: const Color(0xFF4ADE80),
                        label: tr('pairStats.high24h'),
                        value: '\$${formatPrice(highPrice)}',
                      ),
                    ),
                    Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      color: AppColors.border.withValues(alpha: 0.3),
                    ),
                    Expanded(
                      child: _StatCell(
                        icon: LucideIcons.arrowDown,
                        iconColor: const Color(0xFFF87171),
                        label: tr('pairStats.low24h'),
                        value: '\$${formatPrice(lowPrice)}',
                      ),
                    ),
                    Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      color: AppColors.border.withValues(alpha: 0.3),
                    ),
                    Expanded(
                      child: _StatCell(
                        icon: LucideIcons.barChart3,
                        iconColor: AppColors.accent,
                        label: tr('pairStats.volume'),
                        value: '${formatVolume(volume)}',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single stat cell inside the 3-column stats row.
class _StatCell extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatCell({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 11, color: iconColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: AppColors.mutedForeground,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                color: AppColors.foreground,
              ),
            ),
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
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.secondary.withValues(alpha: 0.5),
              AppColors.secondary.withValues(alpha: 0.15),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            // ── Hero skeleton ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  _bone(width: 40, height: 40, radius: 20),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _bone(width: 100, height: 14, radius: 6),
                        const SizedBox(height: 8),
                        _bone(width: 160, height: 24, radius: 6),
                      ],
                    ),
                  ),
                  _bone(width: 72, height: 28, radius: 8),
                ],
              ),
            ),

            // ── Divider ──
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: AppColors.border.withValues(alpha: 0.3),
            ),

            // ── Stats skeleton ──
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(child: _statCellBone()),
                    Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      color: AppColors.border.withValues(alpha: 0.3),
                    ),
                    Expanded(child: _statCellBone()),
                    Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      color: AppColors.border.withValues(alpha: 0.3),
                    ),
                    Expanded(child: _statCellBone()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCellBone() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _bone(width: 50, height: 9, radius: 4),
          const SizedBox(height: 6),
          _bone(width: 70, height: 14, radius: 4),
        ],
      ),
    );
  }
}
