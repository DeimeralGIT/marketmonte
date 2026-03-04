import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/crypto_names.dart';
import '../models/analysis_models.dart';
import '../providers/market_providers.dart';
import 'crypto_icon.dart';

class PositionCard extends ConsumerWidget {
  final double entryPrice;
  final double exitPrice;
  final double stopLoss;
  final double predictedROI;
  final int confidenceScore;
  final double tpProbability;
  final double slProbability;
  final double expectedValue;
  final double positionSizePct;
  final TradeDirection direction;
  final TranslatableString strategyDescription;
  final int rank;
  final String symbol;
  final double investmentAmount;
  final TimePeriod timePeriod;
  final bool isLudomania;

  const PositionCard({
    super.key,
    required this.entryPrice,
    required this.exitPrice,
    this.stopLoss = 0.0,
    required this.predictedROI,
    required this.confidenceScore,
    this.tpProbability = 0.0,
    this.slProbability = 0.0,
    this.expectedValue = 0.0,
    this.positionSizePct = 0.0,
    this.direction = TradeDirection.long,
    required this.strategyDescription,
    required this.rank,
    required this.symbol,
    required this.investmentAmount,
    required this.timePeriod,
    this.isLudomania = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPositive = predictedROI > 0;
    final isLong = direction == TradeDirection.long;
    // Ludomania orange accent
    const ludomaniaOrange = Color(0xFFFFA726);
    // Scale EV from per-unit to per-investment
    final scaledEV = entryPrice > 0
        ? expectedValue * (investmentAmount / entryPrice)
        : expectedValue;
    final exchangeService = ref.watch(exchangeServiceProvider);
    final tradeUrl = exchangeService.getTradeUrl(
      symbol,
      investmentAmount: investmentAmount,
      entryPrice: entryPrice,
      exitPrice: exitPrice,
    );
    final exchangeName = exchangeService.exchange.displayName;
    final quantity = investmentAmount > 0
        ? (investmentAmount / entryPrice)
        : 0.0;
    final baseAsset = symbol.replaceAll('USDT', '');

    return Container(
      decoration: BoxDecoration(
        gradient: isLudomania ? null : AppTheme.cardGradient,
        color: isLudomania ? null : null,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(
          color: isLudomania
              ? ludomaniaOrange.withValues(alpha: 0.6)
              : AppColors.border.withValues(alpha: 0.4),
          width: isLudomania ? 2 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        child: Container(
          decoration: BoxDecoration(
            gradient: isLudomania
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      ludomaniaOrange.withValues(alpha: 0.08),
                      AppColors.card.withValues(alpha: 0.95),
                    ],
                  )
                : AppTheme.cardGradient,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // Direction badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  color:
                                      (isLong
                                              ? const Color(0xFF4ADE80)
                                              : const Color(0xFFF87171))
                                          .withValues(alpha: 0.12),
                                  border: Border.all(
                                    color:
                                        (isLong
                                                ? const Color(0xFF4ADE80)
                                                : const Color(0xFFF87171))
                                            .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  isLong
                                      ? tr('position.long')
                                      : tr('position.short'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isLong
                                        ? const Color(0xFF4ADE80)
                                        : const Color(0xFFF87171),
                                  ),
                                ),
                              ),
                              // Rank badge (or Ludomania badge)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isLudomania
                                        ? ludomaniaOrange.withValues(alpha: 0.5)
                                        : AppColors.accent.withValues(
                                            alpha: 0.3,
                                          ),
                                  ),
                                  color: isLudomania
                                      ? ludomaniaOrange.withValues(alpha: 0.12)
                                      : AppColors.accent.withValues(
                                          alpha: 0.05,
                                        ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isLudomania) ...[
                                      Icon(
                                        LucideIcons.flame,
                                        size: 10,
                                        color: ludomaniaOrange,
                                      ),
                                      const SizedBox(width: 3),
                                    ],
                                    Text(
                                      isLudomania
                                          ? tr('position.ludomania')
                                          : tr(
                                              'position.rank',
                                              namedArgs: {
                                                'rank': rank.toString(),
                                              },
                                            ),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isLudomania
                                            ? ludomaniaOrange
                                            : AppColors.accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Confidence
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.shieldCheck,
                                    size: 12,
                                    color: AppColors.accent,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '$confidenceScore%',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.mutedForeground,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    children: [
                                      Text(
                                        tr('position.roiTarget'),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.foreground,
                                        ),
                                      ),
                                      Text(
                                        formatROI(predictedROI),
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: isPositive
                                              ? const Color(0xFF4ADE80)
                                              : const Color(0xFFF87171),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      children: [
                        CryptoIcon(symbol: symbol, size: 36),
                        const SizedBox(height: 4),
                        Text(
                          baseAsset,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.foreground,
                          ),
                        ),
                        Text(
                          cryptoName(symbol),
                          style: TextStyle(
                            fontSize: 8,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Body
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Entry / Exit row
                    Row(
                      children: [
                        Expanded(
                          child: _PriceBox(
                            label: tr('position.entryPrice'),
                            value: '\$${formatPrice(entryPrice)}',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _PriceBox(
                            label: tr('position.exitTarget'),
                            value: '\$${formatPrice(exitPrice)}',
                            valueColor: AppColors.accent,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Stop Loss / Expected Value row
                    Row(
                      children: [
                        Expanded(
                          child: _PriceBox(
                            label: tr('position.stopLoss'),
                            value: '\$${formatPrice(stopLoss)}',
                            valueColor: const Color(0xFFF87171),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _PriceBox(
                            label: tr('position.expectedValue'),
                            value: '\$${scaledEV.toStringAsFixed(2)}',
                            valueColor: scaledEV > 0
                                ? const Color(0xFF4ADE80)
                                : const Color(0xFFF87171),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // SL Prob / TP Prob row
                    Row(
                      children: [
                        Expanded(
                          child: _PriceBox(
                            label: tr('position.slProbability'),
                            value:
                                '${(slProbability * 100).toStringAsFixed(1)}%',
                            valueColor: const Color(0xFFF87171),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _PriceBox(
                            label: tr('position.tpProbability'),
                            value:
                                '${(tpProbability * 100).toStringAsFixed(1)}%',
                            valueColor: const Color(0xFF4ADE80),
                          ),
                        ),
                      ],
                    ),

                    // Size calculation
                    if (investmentAmount > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(
                            AppTheme.borderRadius,
                          ),
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  LucideIcons.calculator,
                                  size: 12,
                                  color: AppColors.accent,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  tr('position.size'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  tr(
                                    'position.quantityLabel',
                                    namedArgs: {
                                      'quantity': quantity.toStringAsFixed(6),
                                      'asset': baseAsset,
                                    },
                                  ),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                    color: AppColors.foreground,
                                  ),
                                ),
                                Text(
                                  tr(
                                    'position.forUsdt',
                                    namedArgs: {
                                      'amount': investmentAmount
                                          .toStringAsFixed(0),
                                    },
                                  ),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Strategy
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          LucideIcons.target,
                          size: 12,
                          color: AppColors.mutedForeground,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          tr('position.strategyOutlook'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mutedForeground,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '"${strategyDescription.translate()}"',
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: AppColors.foreground.withValues(alpha: 0.8),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Footer
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _onTradePressed(context, tradeUrl),
                    icon: const Icon(LucideIcons.externalLink, size: 16),
                    label: Text(
                      tr(
                        'position.tradeOn',
                        namedArgs: {'exchange': exchangeName},
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.foreground,
                      backgroundColor: AppColors.secondary,
                      side: BorderSide(
                        color: AppColors.border.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show calendar reminder dialog, then open Binance.
  Future<void> _onTradePressed(BuildContext context, String tradeUrl) async {
    final closeTime = DateTime.now().add(Duration(hours: timePeriod.hours));
    final formattedClose = DateFormat('MMM d, y – h:mm a').format(closeTime);
    final baseAsset = symbol.replaceAll('USDT', '');

    final addReminder = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.calendarClock,
                    size: 22,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('reminder.setExitReminder'),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tr(
                          'reminder.basedOnHorizon',
                          namedArgs: {
                            'horizon': _timePeriodDisplayName(timePeriod),
                          },
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Event preview card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.bell, size: 14, color: AppColors.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tr(
                            'reminder.closePosition',
                            namedArgs: {
                              'asset': baseAsset,
                              'price': formatPrice(exitPrice),
                            },
                          ),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _calendarDetailRow(
                    LucideIcons.clock,
                    tr('reminder.closeBy'),
                    formattedClose,
                  ),
                  const SizedBox(height: 6),
                  _calendarDetailRow(
                    LucideIcons.target,
                    tr('reminder.exitTarget'),
                    '\$${formatPrice(exitPrice)}',
                  ),
                  const SizedBox(height: 6),
                  _calendarDetailRow(
                    LucideIcons.trendingUp,
                    tr('reminder.roiTarget'),
                    formatROI(predictedROI),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.mutedForeground,
                      side: BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(tr('reminder.skip')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(ctx, true),
                    icon: const Icon(LucideIcons.calendarPlus, size: 16),
                    label: Text(tr('reminder.addReminder')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.background,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (addReminder == true) {
      await _openCalendarEvent(closeTime);
    }

    // Always open Binance trade link afterwards
    await _openUrl(tradeUrl);
  }

  Widget _calendarDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 12, color: AppColors.mutedForeground),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
            color: AppColors.foreground,
          ),
        ),
      ],
    );
  }

  /// Open a Google Calendar event creation URL with pre-filled details.
  Future<void> _openCalendarEvent(DateTime closeTime) async {
    final baseAsset = symbol.replaceAll('USDT', '');
    final title = Uri.encodeComponent(
      tr(
        'reminder.calendarTitle',
        namedArgs: {'asset': baseAsset, 'price': formatPrice(exitPrice)},
      ),
    );
    final details = Uri.encodeComponent(
      tr(
        'reminder.calendarDetails',
        namedArgs: {
          'symbol': symbol,
          'entry': formatPrice(entryPrice),
          'exit': formatPrice(exitPrice),
          'roi': formatROI(predictedROI),
          'confidence': confidenceScore.toString(),
          'strategy': strategyDescription.translate(),
        },
      ),
    );

    // Google Calendar expects dates in UTC as yyyyMMddTHHmmssZ
    String gcalDate(DateTime dt) {
      final utc = dt.toUtc();
      return '${utc.year}'
          '${utc.month.toString().padLeft(2, '0')}'
          '${utc.day.toString().padLeft(2, '0')}'
          'T${utc.hour.toString().padLeft(2, '0')}'
          '${utc.minute.toString().padLeft(2, '0')}'
          '${utc.second.toString().padLeft(2, '0')}Z';
    }

    // Reminder event starts 15 min before close & ends at close time
    final start = closeTime.subtract(const Duration(minutes: 15));
    final dates = '${gcalDate(start)}/${gcalDate(closeTime)}';

    final calUrl =
        'https://calendar.google.com/calendar/render'
        '?action=TEMPLATE'
        '&text=$title'
        '&dates=$dates'
        '&details=$details';

    await _openUrl(calUrl);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    // Try non-browser app first (e.g. Binance app if installed)
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
      if (launched) return;
    } catch (_) {
      // No non-browser app available for this URL
    }
    // Fall back to platform default (shows app chooser on Android)
    try {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        // Silently fail
      }
    }
  }

  String _timePeriodDisplayName(TimePeriod period) {
    switch (period) {
      case TimePeriod.oneHour:
        return tr('timePeriod.1H');
      case TimePeriod.fourHours:
        return tr('timePeriod.4H');
      case TimePeriod.oneDay:
        return tr('timePeriod.1D');
      case TimePeriod.oneWeek:
        return tr('timePeriod.1W');
      case TimePeriod.oneMonth:
        return tr('timePeriod.1M');
    }
  }
}

class _PriceBox extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _PriceBox({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                color: valueColor ?? AppColors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
