import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/binance_models.dart';
import '../models/analysis_models.dart';
import '../services/binance_service.dart';
import '../services/analysis_service.dart';

// --- Service Providers ---

final binanceServiceProvider = Provider<BinanceService>((ref) {
  return BinanceService();
});

final analysisServiceProvider = Provider<AnalysisService>((ref) {
  return AnalysisService(ref.read(binanceServiceProvider));
});

// --- Pairs Provider ---

final pairsProvider = FutureProvider<List<BinancePair>>((ref) async {
  final binanceService = ref.read(binanceServiceProvider);
  return binanceService.fetchUSDTTradingPairs();
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
      activeTab: activeTab ?? this.activeTab,
    );
  }
}

// --- Market State Notifier ---

class MarketStateNotifier extends StateNotifier<MarketState> {
  final BinanceService _binanceService;
  final AnalysisService _analysisService;

  MarketStateNotifier(this._binanceService, this._analysisService)
    : super(const MarketState());

  void setSelectedPair(String pair) {
    state = state.copyWith(selectedPair: pair);
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

  /// Analyze the currently selected pair.
  Future<void> analyzePair() async {
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
        ),
        _binanceService.fetch24hTicker(state.selectedPair),
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

  /// Initialize with default ticker data.
  Future<void> init() async {
    final ticker = await _binanceService.fetch24hTicker('BTCUSDT');
    if (ticker != null) {
      state = state.copyWith(ticker: ticker);
    }
  }
}

// --- Market State Provider ---

final marketStateProvider =
    StateNotifierProvider<MarketStateNotifier, MarketState>((ref) {
      final binanceService = ref.read(binanceServiceProvider);
      final analysisService = ref.read(analysisServiceProvider);
      return MarketStateNotifier(binanceService, analysisService);
    });
