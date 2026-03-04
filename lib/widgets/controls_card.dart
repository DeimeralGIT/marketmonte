import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../models/binance_models.dart';
import '../models/analysis_models.dart';
import '../providers/market_providers.dart';

class ControlsCard extends ConsumerStatefulWidget {
  const ControlsCard({super.key});

  @override
  ConsumerState<ControlsCard> createState() => _ControlsCardState();
}

class _ControlsCardState extends ConsumerState<ControlsCard> {
  late TextEditingController _searchController;
  late TextEditingController _investmentController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _investmentController = TextEditingController(text: '100');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _investmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final marketState = ref.watch(marketStateProvider);
    final pairsAsync = ref.watch(pairsProvider);
    final notifier = ref.read(marketStateProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: [AppTheme.accentGlow],
      ),
      child: Stack(
        children: [
          // Watermark icon
          Positioned(
            top: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                LucideIcons.sparkles,
                size: 64,
                color: AppColors.accent.withValues(alpha: 0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Search + Investment + Pair selector + Analyze
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 600;
                    if (isWide) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(child: _buildSearchField(notifier)),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 160,
                                child: _buildInvestmentField(notifier),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 200,
                                child: _buildPairDropdown(
                                  pairsAsync,
                                  marketState,
                                  notifier,
                                ),
                              ),
                              const SizedBox(width: 12),
                              _buildAnalyzeButton(marketState, notifier),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTimePeriodSelector(marketState, notifier),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSearchField(notifier),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _buildInvestmentField(notifier)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildPairDropdown(
                                pairsAsync,
                                marketState,
                                notifier,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildTimePeriodSelector(marketState, notifier),
                        const SizedBox(height: 12),
                        _buildAnalyzeButton(marketState, notifier),
                      ],
                    );
                  },
                ),

                // Divider
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Divider(
                    color: AppColors.border.withValues(alpha: 0.5),
                    height: 1,
                  ),
                ),

                // Row 2: Pro tip + Scan button
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 500;
                    if (isWide) {
                      return Row(
                        children: [
                          Expanded(child: _buildProTip()),
                          const SizedBox(width: 16),
                          _buildScanButton(marketState, notifier),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildProTip(),
                        const SizedBox(height: 12),
                        _buildScanButton(marketState, notifier),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(MarketStateNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'SYMBOL SEARCH',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
        TextField(
          controller: _searchController,
          onChanged: (v) => notifier.setSearchQuery(v),
          decoration: InputDecoration(
            hintText: 'Filter pairs (e.g. SOL, ETH...)',
            prefixIcon: const Icon(
              LucideIcons.search,
              size: 16,
              color: AppColors.mutedForeground,
            ),
            filled: true,
            fillColor: AppColors.background.withValues(alpha: 0.5),
          ),
          style: const TextStyle(fontSize: 14, color: AppColors.foreground),
        ),
      ],
    );
  }

  Widget _buildInvestmentField(MarketStateNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'INVESTMENT (USDT)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
        TextField(
          controller: _investmentController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (v) {
            final amount = double.tryParse(v) ?? 0;
            notifier.setInvestmentAmount(amount);
          },
          decoration: InputDecoration(
            hintText: '100',
            prefixIcon: const Icon(
              LucideIcons.dollarSign,
              size: 16,
              color: AppColors.accent,
            ),
            filled: true,
            fillColor: AppColors.background.withValues(alpha: 0.5),
          ),
          style: const TextStyle(
            fontSize: 14,
            fontFamily: 'monospace',
            color: AppColors.foreground,
          ),
        ),
      ],
    );
  }

  Widget _buildPairDropdown(
    AsyncValue<List<BinancePair>> pairsAsync,
    MarketState marketState,
    MarketStateNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'SELECT PAIR',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
        pairsAsync.when(
          data: (pairs) {
            final filtered = pairs
                .where(
                  (p) => p.symbol.toLowerCase().contains(
                    marketState.searchQuery.toLowerCase(),
                  ),
                )
                .take(100)
                .toList();

            // Ensure the selected pair is in the list
            final hasSelected = filtered.any(
              (p) => p.symbol == marketState.selectedPair,
            );

            return Container(
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: hasSelected ? marketState.selectedPair : null,
                  hint: const Text(
                    'Select a pair',
                    style: TextStyle(
                      color: AppColors.mutedForeground,
                      fontSize: 14,
                    ),
                  ),
                  isExpanded: true,
                  dropdownColor: AppColors.card,
                  menuMaxHeight: 300,
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'monospace',
                    color: AppColors.foreground,
                  ),
                  items: filtered.map((p) {
                    return DropdownMenuItem(
                      value: p.symbol,
                      child: Text(p.symbol),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) notifier.setSelectedPair(value);
                  },
                ),
              ),
            );
          },
          loading: () => Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              ),
            ),
          ),
          error: (e, _) => Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              border: Border.all(color: AppColors.destructive),
            ),
            child: const Center(
              child: Text(
                'Failed to load pairs',
                style: TextStyle(color: AppColors.destructive, fontSize: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyzeButton(
    MarketState marketState,
    MarketStateNotifier notifier,
  ) {
    final isLoading =
        marketState.loading && marketState.activeTab == ActiveTab.single;

    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : () => notifier.analyzePair(),
        icon: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryForeground,
                ),
              )
            : const Icon(LucideIcons.brainCircuit, size: 16),
        label: const Text('Analyze'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.primaryForeground,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildTimePeriodSelector(
    MarketState marketState,
    MarketStateNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'TIME HORIZON',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
        Row(
          children: TimePeriod.values.map((period) {
            final isSelected = marketState.timePeriod == period;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: period == TimePeriod.values.first ? 0 : 4,
                ),
                child: GestureDetector(
                  onTap: () => notifier.setTimePeriod(period),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accent.withValues(alpha: 0.15)
                          : AppColors.background.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(
                        AppTheme.borderRadius,
                      ),
                      border: Border.all(
                        color: isSelected ? AppColors.accent : AppColors.border,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          period.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: isSelected
                                ? AppColors.accent
                                : AppColors.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          period.displayName,
                          style: TextStyle(
                            fontSize: 9,
                            color: isSelected
                                ? AppColors.accent.withValues(alpha: 0.8)
                                : AppColors.mutedForeground.withValues(
                                    alpha: 0.7,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildProTip() {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
        children: const [
          TextSpan(
            text: 'Pro Tip: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.accent,
            ),
          ),
          TextSpan(
            text:
                'Your investment amount & time horizon shape the Monte Carlo simulation for position sizing.',
          ),
        ],
      ),
    );
  }

  Widget _buildScanButton(
    MarketState marketState,
    MarketStateNotifier notifier,
  ) {
    final isLoading =
        marketState.loading && marketState.activeTab == ActiveTab.market;

    return OutlinedButton.icon(
      onPressed: isLoading ? null : () => notifier.scanMarket(),
      icon: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            )
          : const Icon(LucideIcons.zap, size: 16),
      label: const Text('Scan Market Leaders'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.accent,
        side: BorderSide(color: AppColors.accent.withValues(alpha: 0.3)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }
}
