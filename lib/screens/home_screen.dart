import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_theme.dart';
import '../providers/market_providers.dart';
import '../providers/theme_provider.dart';
import '../providers/ludomania_provider.dart';
import '../widgets/app_header.dart';
import '../widgets/controls_card.dart';
import '../widgets/pair_stats.dart';
import '../widgets/analysis_section.dart';
import '../widgets/leaderboard_section.dart';
import '../widgets/empty_state.dart';
import '../widgets/footer.dart';
import '../widgets/settings_drawer.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final marketState = ref.watch(marketStateProvider);
    // Watch theme so the tree rebuilds when appearance changes
    ref.watch(themeProvider);
    // Register as dependent on locale so the tree rebuilds on language change
    context.locale;

    // React to ludomania toggle: add/remove YOLO position immediately
    ref.listen<bool>(ludomaniaProvider, (previous, next) {
      ref.read(marketStateProvider.notifier).applyLudomaniaMode(next);
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      endDrawer: SettingsDrawer(),
      body: Column(
        children: [
          // Sticky header
          AppHeader(),
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),

                      // Controls card
                      ControlsCard(),

                      const SizedBox(height: 24),

                      // Error banner
                      if (marketState.error != null) ...[
                        _buildErrorBanner(marketState.error!),
                        const SizedBox(height: 24),
                      ],

                      // Pair stats (single analysis tab)
                      if (marketState.tickerLoading &&
                          marketState.activeTab == ActiveTab.single)
                        const PairStatsSkeleton()
                      else if (marketState.ticker != null &&
                          marketState.activeTab == ActiveTab.single)
                        PairStats(
                          ticker: marketState.ticker!,
                          symbol: marketState.selectedPair,
                        ),

                      // Single pair analysis results
                      if (marketState.analysis != null &&
                          marketState.activeTab == ActiveTab.single) ...[
                        AnalysisSection(
                          analysis: marketState.analysis!,
                          symbol: marketState.selectedPair,
                          investmentAmount: marketState.investmentAmount,
                          timePeriod: marketState.timePeriod,
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Market leaderboard results
                      if (marketState.leaderboard != null &&
                          marketState.activeTab == ActiveTab.market) ...[
                        LeaderboardSection(
                          leaderboard: marketState.leaderboard!,
                          investmentAmount: marketState.investmentAmount,
                          timePeriod: marketState.timePeriod,
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Loading indicator
                      if (marketState.loading)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.accent,
                            ),
                          ),
                        ),

                      // Empty state
                      if (!marketState.loading &&
                          marketState.analysis == null &&
                          marketState.leaderboard == null)
                        EmptyState(),

                      // Footer
                      AppFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.destructive.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppColors.destructive.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.info, size: 18, color: AppColors.destructive),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('analysis.analysisError'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.destructive,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  error,
                  style: TextStyle(fontSize: 13, color: AppColors.foreground),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
