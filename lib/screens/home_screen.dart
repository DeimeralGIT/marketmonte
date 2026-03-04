import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../providers/market_providers.dart';
import '../widgets/app_header.dart';
import '../widgets/controls_card.dart';
import '../widgets/pair_stats.dart';
import '../widgets/analysis_section.dart';
import '../widgets/leaderboard_section.dart';
import '../widgets/empty_state.dart';
import '../widgets/footer.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize with default ticker data after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(marketStateProvider.notifier).init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final marketState = ref.watch(marketStateProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Sticky header
          const AppHeader(),
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
                      const ControlsCard(),

                      const SizedBox(height: 24),

                      // Error banner
                      if (marketState.error != null) ...[
                        _buildErrorBanner(marketState.error!),
                        const SizedBox(height: 24),
                      ],

                      // Pair stats (single analysis tab)
                      if (marketState.ticker != null &&
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
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
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
                        const EmptyState(),

                      // Footer
                      const AppFooter(),
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
          const Icon(LucideIcons.info, size: 18, color: AppColors.destructive),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Analysis Error',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.destructive,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  error,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.foreground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
