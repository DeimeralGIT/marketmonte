import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/binance_models.dart';
import '../models/analysis_models.dart';
import '../models/exchange_models.dart';
import '../services/exchange_service.dart';
import '../services/analysis_service.dart';
import '../services/exchanges/binance_exchange_service.dart';
import '../services/exchanges/coinbase_exchange_service.dart';
import '../services/exchanges/mexc_exchange_service.dart';
import 'exchange_provider.dart';

// --- Service Providers ---

/// Returns the correct ExchangeService for the currently selected exchange.
ExchangeService exchangeServiceFor(Exchange exchange) {
  switch (exchange) {
    case Exchange.binance:
      return BinanceExchangeService();
    case Exchange.coinbase:
      return CoinbaseExchangeService();
    case Exchange.mexc:
      return MexcExchangeService();
  }
}

final exchangeServiceProvider = Provider<ExchangeService>((ref) {
  final exchange = ref.watch(exchangeProvider);
  return exchangeServiceFor(exchange);
});

final analysisServiceProvider = Provider<AnalysisService>((ref) {
  final exchangeService = ref.watch(exchangeServiceProvider);
  return AnalysisService(exchangeService);
});

// --- Pairs Provider ---

final pairsProvider = FutureProvider<List<BinancePair>>((ref) async {
  final exchangeService = ref.watch(exchangeServiceProvider);
  return exchangeService.fetchUSDTTradingPairs();
});

// --- Active Tab Enum ---

enum ActiveTab { single, market }

// --- Market State ---

class MarketState {
  final String selectedPair;
  final String searchQuery;
  final double investmentAmount;
  final TimePeriod timePeriod;
  final bool loading;
  final String? error;
  final CryptoAnalysisResult? analysis;
  final MarketLeaderboardResult? leaderboard;
  final Map<String, dynamic>? ticker;
  final bool tickerLoading;
  final ActiveTab activeTab;

  const MarketState({
    this.selectedPair = 'BTCUSDT',
    this.searchQuery = '',
    this.investmentAmount = 100.0,
    this.timePeriod = TimePeriod.oneDay,
    this.loading = false,
    this.error,
    this.analysis,
    this.leaderboard,
    this.ticker,
    this.tickerLoading = false,
    this.activeTab = ActiveTab.single,
  });

  MarketState copyWith({
    String? selectedPair,
    String? searchQuery,
    double? investmentAmount,
    TimePeriod? timePeriod,
    bool? loading,
    String? error,
    CryptoAnalysisResult? analysis,
    MarketLeaderboardResult? leaderboard,
    Map<String, dynamic>? ticker,
    bool? tickerLoading,
    ActiveTab? activeTab,
    bool clearError = false,
    bool clearAnalysis = false,
    bool clearLeaderboard = false,
    bool clearTicker = false,
  }) {
    return MarketState(
      selectedPair: selectedPair ?? this.selectedPair,
      searchQuery: searchQuery ?? this.searchQuery,
      investmentAmount: investmentAmount ?? this.investmentAmount,
      timePeriod: timePeriod ?? this.timePeriod,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      analysis: clearAnalysis ? null : (analysis ?? this.analysis),
      leaderboard: clearLeaderboard ? null : (leaderboard ?? this.leaderboard),
      ticker: clearTicker ? null : (ticker ?? this.ticker),
      tickerLoading: tickerLoading ?? this.tickerLoading,
      activeTab: activeTab ?? this.activeTab,
    );
  }
}

// --- Market State Notifier ---

class MarketStateNotifier extends StateNotifier<MarketState> {
  final ExchangeService _exchangeService;
  final AnalysisService _analysisService;

  MarketStateNotifier(this._exchangeService, this._analysisService)
    : super(const MarketState());

  void setSelectedPair(String pair) {
    state = state.copyWith(selectedPair: pair, tickerLoading: true);
    _fetchTicker(pair);
  }

  Future<void> _fetchTicker(String pair) async {
    try {
      final ticker = await _exchangeService.fetch24hTicker(pair);
      if (!mounted) return;
      // Only apply if the pair is still the selected one
      if (ticker != null && state.selectedPair == pair) {
        state = state.copyWith(ticker: ticker, tickerLoading: false);
      }
    } catch (_) {
      if (!mounted) return;
      // Clear loading even on error
      if (state.selectedPair == pair) {
        state = state.copyWith(tickerLoading: false);
      }
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setInvestmentAmount(double amount) {
    state = state.copyWith(investmentAmount: amount);
  }

  void setTimePeriod(TimePeriod period) {
    state = state.copyWith(timePeriod: period);
  }

  /// React to ludomania toggle — add or remove the YOLO position.
  Future<void> applyLudomaniaMode(bool enabled) async {
    final analysis = state.analysis;
    if (analysis == null) return; // nothing to modify

    if (!enabled) {
      // Remove ludomania positions immediately
      final filtered = analysis.positions.where((p) => !p.isLudomania).toList();
      state = state.copyWith(
        analysis: CryptoAnalysisResult(
          positions: filtered,
          analysisSummary: analysis.analysisSummary,
          regimeInfo: analysis.regimeInfo,
          distributionStats: analysis.distributionStats,
        ),
      );
    } else {
      // Re-run analysis with ludomania enabled
      await analyzePair(ludomaniaMode: true);
    }
  }

  /// Analyze the currently selected pair.
  Future<void> analyzePair({bool ludomaniaMode = false}) async {
    state = state.copyWith(
      loading: true,
      clearError: true,
      clearLeaderboard: true,
      activeTab: ActiveTab.single,
    );

    try {
      final results = await Future.wait([
        _analysisService.analyzePair(
          state.selectedPair,
          period: state.timePeriod,
          ludomaniaMode: ludomaniaMode,
        ),
        _exchangeService.fetch24hTicker(state.selectedPair),
      ]);

      final analysisResult = results[0] as CryptoAnalysisResult;
      final tickerData = results[1] as Map<String, dynamic>?;

      state = state.copyWith(
        loading: false,
        analysis: analysisResult,
        ticker: tickerData,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// Scan top market leaders.
  Future<void> scanMarket() async {
    state = state.copyWith(
      loading: true,
      clearError: true,
      clearAnalysis: true,
      clearTicker: true,
      activeTab: ActiveTab.market,
    );

    try {
      final leaderboard = await _analysisService.scanTopMarket(
        period: state.timePeriod,
      );
      state = state.copyWith(loading: false, leaderboard: leaderboard);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// Refresh current data: re-fetch ticker and, if an analysis/leaderboard
  /// was already computed, re-run it with the same parameters.
  Future<void> refresh({bool ludomaniaMode = false}) async {
    if (state.activeTab == ActiveTab.market && state.leaderboard != null) {
      await scanMarket();
    } else if (state.analysis != null) {
      await analyzePair(ludomaniaMode: ludomaniaMode);
    } else {
      // No analysis yet — just refresh the ticker
      state = state.copyWith(tickerLoading: true);
      await _fetchTicker(state.selectedPair);
    }
  }

  /// Initialize: fetch pairs from the exchange, select the first one,
  /// and load its ticker.
  Future<void> init() async {
    // Immediately clear old data so the UI doesn't show stale info
    state = state.copyWith(
      tickerLoading: true,
      clearTicker: true,
      clearAnalysis: true,
      clearLeaderboard: true,
      clearError: true,
    );
    try {
      final pairs = await _exchangeService.fetchUSDTTradingPairs();
      if (!mounted) return;
      final firstSymbol = pairs.isNotEmpty ? pairs.first.symbol : 'BTCUSDT';
      state = state.copyWith(selectedPair: firstSymbol);
      final ticker = await _exchangeService.fetch24hTicker(firstSymbol);
      if (!mounted) return;
      if (ticker != null && state.selectedPair == firstSymbol) {
        state = state.copyWith(ticker: ticker, tickerLoading: false);
      } else {
        state = state.copyWith(tickerLoading: false);
      }
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(tickerLoading: false);
    }
  }
}

// --- Market State Provider ---

final marketStateProvider =
    StateNotifierProvider<MarketStateNotifier, MarketState>((ref) {
      final exchangeService = ref.watch(exchangeServiceProvider);
      final analysisService = ref.read(analysisServiceProvider);
      final notifier = MarketStateNotifier(exchangeService, analysisService);
      // Auto-initialize whenever the provider is (re-)created
      // (e.g. on exchange change).
      notifier.init();
      return notifier;
    });
