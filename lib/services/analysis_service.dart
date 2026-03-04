import 'dart:math';
import 'package:easy_localization/easy_localization.dart';
import '../models/analysis_models.dart';
import '../models/binance_models.dart';
import 'exchange_service.dart';
import 'regime_detection_service.dart';

class AnalysisService {
  ExchangeService _exchangeService;

  AnalysisService(this._exchangeService);

  /// Swap the underlying exchange service (e.g. when user changes exchange).
  void updateExchangeService(ExchangeService service) {
    _exchangeService = service;
  }

  static const int _numSim = 10000;

  /// Regime display names (indexed by state: 0=low, 1=med, 2=high).
  static List<String> get _regimeNames => [
    tr('analysis.regimeLowVolShort'),
    tr('analysis.regimeTrendingShort'),
    tr('analysis.regimeHighVolShort'),
  ];

  /// Transaction cost per round-trip (2 × 0.1% taker fee).
  static const double _txCost = 0.002;

  /// Estimated slippage as fraction of price.
  static const double _slippage = 0.0005;

  /// Stop loss multiplier (k × distribution std dev).
  static const double _slMultiplier = 1.5;

  /// Half-Kelly fraction.
  static const double _kellyFraction = 0.5;

  /// Max position size as fraction of capital.
  static const double _maxPositionSize = 0.05;

  /// Minimum TP probability to accept a trade.
  static const double _minTpProb = 0.40;

  // ───────────────────────────────────────────────────────────────────────────
  // Hybrid engine pipeline
  // ───────────────────────────────────────────────────────────────────────────

  CryptoAnalysisResult _runHybridEngine(
    String symbol,
    List<KlineData> klines,
    TimePeriod period,
  ) {
    final prices = klines.map((k) => k.close).toList();
    final currentPrice = prices.last;
    final n = prices.length;

    // ── 1. Compute hourly log-returns ──
    final logReturns = <double>[];
    for (int i = 1; i < n; i++) {
      logReturns.add(log(prices[i] / prices[i - 1]));
    }

    // ── 2. HMM + Particle Filter regime detection ──
    final regimeResult = RegimeDetectionService.detect(logReturns);
    final currentRegime = regimeResult.currentRegime;
    final regimeProbs = regimeResult.currentRegimeProbs;
    final regimeParams = regimeResult.regimeParams;
    final transMatrix = regimeResult.transitionMatrix;
    final persistenceMatrix = regimeResult.persistenceMatrix;
    final regimeEntropy = regimeResult.regimeEntropy;

    // ── 3. Particle Filter volScale extraction ──
    final pf = ParticleFilter(
      nParticles: 500,
      nStates: 3,
      transitionMatrix: transMatrix,
      regimeMeans: regimeParams.map((r) => r.mean).toList(),
      regimeStds: regimeParams.map((r) => r.std).toList(),
      regimeNus: regimeParams.map((r) => r.nu).toList(),
      seed: 42,
    );
    final pfWindow = logReturns.length > 50
        ? logReturns.sublist(logReturns.length - 50)
        : logReturns;
    for (final obs in pfWindow) {
      pf.update(obs);
    }
    final volScale = pf.getVolScaleMean();

    // ── 4. Regime-Aware State-Space MC (Student-t, path tracking) ──
    final simulator = RegimeAwareSimulator(
      regimeParams: regimeParams,
      transitionMatrix: persistenceMatrix, // use sticky A'
    );

    final pathResults = simulator.simulate(
      startPrice: currentPrice,
      steps: period.hours,
      regimeProbs: regimeProbs,
      volScale: volScale,
      numSimulations: _numSim,
      seed: 42,
    );

    // ── 5. Distribution statistics ──
    final finalPrices = pathResults.map((p) => p.finalPrice).toList();
    // already sorted by finalPrice

    double pctile(double p) =>
        finalPrices[(_numSim * p).floor().clamp(0, _numSim - 1)];
    final p05 = pctile(0.05);
    final p10 = pctile(0.10);
    final p25 = pctile(0.25);
    final p50 = pctile(0.50);
    final p75 = pctile(0.75);
    final p90 = pctile(0.90);
    final p95 = pctile(0.95);

    final meanPrice = finalPrices.reduce((a, b) => a + b) / _numSim;
    final variance =
        finalPrices
            .map((p) => (p - meanPrice) * (p - meanPrice))
            .reduce((a, b) => a + b) /
        _numSim;
    final stdDev = sqrt(variance);

    // Skewness and kurtosis
    double skewness = 0.0;
    double kurtosis = 3.0;
    if (stdDev > 1e-10) {
      double m3 = 0.0, m4 = 0.0;
      for (final p in finalPrices) {
        final z = (p - meanPrice) / stdDev;
        m3 += z * z * z;
        m4 += z * z * z * z;
      }
      skewness = m3 / _numSim;
      kurtosis = m4 / _numSim;
    }

    final distStats = DistributionStats(
      mean: meanPrice,
      stdDev: stdDev,
      skewness: skewness,
      kurtosis: kurtosis,
      p5: p05,
      p10: p10,
      p25: p25,
      p50: p50,
      p75: p75,
      p90: p90,
      p95: p95,
    );

    // ── 6. Regime-specific annualised volatilities ──
    final hoursPerYear = 8760.0;
    final regimeAnnVols = regimeParams
        .map((r) => r.std * sqrt(hoursPerYear) * 100)
        .toList();

    // ── 7. Regime stability score ──
    final selfTransProb = transMatrix[currentRegime][currentRegime];
    final stabilityScore = (selfTransProb * 100).round().clamp(0, 100);

    // ── 8. Build RegimeInfo ──
    final regimeInfo = RegimeInfo(
      currentRegime: VolatilityRegime.values[currentRegime],
      regimeProbs: regimeProbs,
      regimeAnnualisedVols: regimeAnnVols,
      regimeDrifts: regimeParams.map((r) => r.mean).toList(),
      regimeNus: regimeParams.map((r) => r.nu).toList(),
      transitionFromCurrent: transMatrix[currentRegime],
      stabilityScore: stabilityScore,
      regimeEntropy: regimeEntropy,
    );

    // ── 9. Build trading positions (long + short) ──
    final positions = _buildPositions(
      currentPrice: currentPrice,
      currentRegime: currentRegime,
      regimeProbs: regimeProbs,
      pathResults: pathResults,
      distStats: distStats,
      period: period,
      stabilityScore: stabilityScore,
      regimeEntropy: regimeEntropy,
    );

    // Sort by EV descending (best expected value first)
    positions.sort((a, b) => b.expectedValue.compareTo(a.expectedValue));

    // ── 10. Build summary ──
    final trendLabel = (p50 > currentPrice)
        ? tr('analysis.bullish')
        : tr('analysis.bearish');
    final regimeLabel = VolatilityRegime.values[currentRegime].label;
    final regimeProbPct = (regimeProbs[currentRegime] * 100).toStringAsFixed(0);
    final currentAnnVol = regimeAnnVols[currentRegime].toStringAsFixed(1);
    final entropyPct = (regimeEntropy / log(3) * 100).toStringAsFixed(0);

    return CryptoAnalysisResult(
      positions: positions,
      regimeInfo: regimeInfo,
      distributionStats: distStats,
      analysisSummary: tr(
        'analysis.summaryTemplate',
        namedArgs: {
          'horizon': period.displayName,
          'paths': _numSim.toString(),
          'symbol': symbol,
          'regime': regimeLabel,
          'confidence': regimeProbPct,
          'stability': stabilityScore.toString(),
          'entropy': entropyPct,
          'trend': trendLabel,
          'annVol': currentAnnVol,
          'median': p50.toStringAsFixed(2),
          'p25': p25.toStringAsFixed(2),
          'p75': p75.toStringAsFixed(2),
          'skew': skewness.toStringAsFixed(2),
          'kurt': kurtosis.toStringAsFixed(2),
        },
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Position building — long + short, barrier pricing, EV, Kelly
  // ───────────────────────────────────────────────────────────────────────────

  List<TradingPosition> _buildPositions({
    required double currentPrice,
    required int currentRegime,
    required List<double> regimeProbs,
    required List<PathResult> pathResults,
    required DistributionStats distStats,
    required TimePeriod period,
    required int stabilityScore,
    required double regimeEntropy,
  }) {
    final regimeName = _regimeNames[currentRegime];
    final isBullish = distStats.p50 >= currentPrice;
    final periodScale = sqrt(period.hours / 24.0).clamp(0.25, 3.0);

    final positions = <TradingPosition>[];

    // ── Regime base discounts (for 24h) ──
    late final double consBase, aggBase;
    switch (currentRegime) {
      case 0:
        consBase = 0.0015;
        aggBase = 0.004;
      case 1:
        consBase = 0.003;
        aggBase = 0.007;
      case 2:
        consBase = 0.005;
        aggBase = 0.012;
      default:
        consBase = 0.003;
        aggBase = 0.007;
    }

    // ── Try LONG positions ──
    if (distStats.p50 >= currentPrice) {
      final longPositions = _buildDirectionalPositions(
        direction: TradeDirection.long,
        currentPrice: currentPrice,
        currentRegime: currentRegime,
        regimeName: regimeName,
        pathResults: pathResults,
        distStats: distStats,
        consBase: consBase,
        aggBase: aggBase,
        periodScale: periodScale,
        stabilityScore: stabilityScore,
        regimeEntropy: regimeEntropy,
        period: period,
      );
      positions.addAll(longPositions);
    }

    // ── Try SHORT positions ──
    if (distStats.p50 < currentPrice) {
      final shortPositions = _buildDirectionalPositions(
        direction: TradeDirection.short,
        currentPrice: currentPrice,
        currentRegime: currentRegime,
        regimeName: regimeName,
        pathResults: pathResults,
        distStats: distStats,
        consBase: consBase,
        aggBase: aggBase,
        periodScale: periodScale,
        stabilityScore: stabilityScore,
        regimeEntropy: regimeEntropy,
        period: period,
      );
      positions.addAll(shortPositions);
    }

    // If no valid positions found (both directions have negative EV),
    // return the best long attempt as informational
    if (positions.isEmpty) {
      positions.addAll(
        _buildDirectionalPositions(
          direction: isBullish ? TradeDirection.long : TradeDirection.short,
          currentPrice: currentPrice,
          currentRegime: currentRegime,
          regimeName: regimeName,
          pathResults: pathResults,
          distStats: distStats,
          consBase: consBase,
          aggBase: aggBase,
          periodScale: periodScale,
          stabilityScore: stabilityScore,
          regimeEntropy: regimeEntropy,
          period: period,
          forceInclude: true,
        ),
      );
    }

    return positions;
  }

  List<TradingPosition> _buildDirectionalPositions({
    required TradeDirection direction,
    required double currentPrice,
    required int currentRegime,
    required String regimeName,
    required List<PathResult> pathResults,
    required DistributionStats distStats,
    required double consBase,
    required double aggBase,
    required double periodScale,
    required int stabilityScore,
    required double regimeEntropy,
    required TimePeriod period,
    bool forceInclude = false,
  }) {
    final isLong = direction == TradeDirection.long;
    final positions = <TradingPosition>[];

    // ── Entry calculation ──
    double consEntry, aggEntry;
    if (isLong) {
      final consDiscount = (consBase * periodScale).clamp(0.0005, 0.025);
      final aggDiscount = (aggBase * periodScale).clamp(0.001, 0.04);
      consEntry = currentPrice * (1 - consDiscount);
      aggEntry = currentPrice * (1 - aggDiscount);
    } else {
      final consPremium = (consBase * periodScale).clamp(0.0005, 0.025);
      final aggPremium = (aggBase * periodScale).clamp(0.001, 0.04);
      consEntry = currentPrice * (1 + consPremium);
      aggEntry = currentPrice * (1 + aggPremium);
    }

    // ── Exit calculation (conditional expectation) ──
    double consExit, aggExit;
    if (isLong) {
      // E[finalPrice | finalPrice ≥ entry]
      final consAbove = pathResults
          .where((p) => p.finalPrice >= consEntry)
          .toList();
      final aggAbove = pathResults
          .where((p) => p.finalPrice >= aggEntry)
          .toList();

      consExit = consAbove.length >= 10
          ? consAbove.map((p) => p.finalPrice).reduce((a, b) => a + b) /
                consAbove.length
          : consEntry * (1 + consBase * 3);
      aggExit = aggAbove.length >= 10
          ? aggAbove.map((p) => p.finalPrice).reduce((a, b) => a + b) /
                aggAbove.length
          : aggEntry * (1 + aggBase * 3);

      // Floor: exit must exceed entry
      consExit = max(consExit, consEntry * 1.001);
      aggExit = max(aggExit, aggEntry * 1.002);
    } else {
      // E[finalPrice | finalPrice ≤ entry]
      final consBelow = pathResults
          .where((p) => p.finalPrice <= consEntry)
          .toList();
      final aggBelow = pathResults
          .where((p) => p.finalPrice <= aggEntry)
          .toList();

      consExit = consBelow.length >= 10
          ? consBelow.map((p) => p.finalPrice).reduce((a, b) => a + b) /
                consBelow.length
          : consEntry * (1 - consBase * 3);
      aggExit = aggBelow.length >= 10
          ? aggBelow.map((p) => p.finalPrice).reduce((a, b) => a + b) /
                aggBelow.length
          : aggEntry * (1 - aggBase * 3);

      // Floor: exit must be below entry
      consExit = min(consExit, consEntry * 0.999);
      aggExit = min(aggExit, aggEntry * 0.998);
    }

    // ── Stop Loss ──
    final consStop = isLong
        ? consEntry - _slMultiplier * distStats.stdDev
        : consEntry + _slMultiplier * distStats.stdDev;
    final aggStop = isLong
        ? aggEntry - _slMultiplier * distStats.stdDev
        : aggEntry + _slMultiplier * distStats.stdDev;

    // ── Barrier probabilities from full path max/min ──
    // Long: TP hit if maxPrice ≥ exit; SL hit if minPrice ≤ stop
    // Short: TP hit if minPrice ≤ exit; SL hit if maxPrice ≥ stop
    final consTpCount = isLong
        ? pathResults.where((p) => p.maxPrice >= consExit).length
        : pathResults.where((p) => p.minPrice <= consExit).length;
    final consSlCount = isLong
        ? pathResults.where((p) => p.minPrice <= consStop).length
        : pathResults.where((p) => p.maxPrice >= consStop).length;

    final aggTpCount = isLong
        ? pathResults.where((p) => p.maxPrice >= aggExit).length
        : pathResults.where((p) => p.minPrice <= aggExit).length;
    final aggSlCount = isLong
        ? pathResults.where((p) => p.minPrice <= aggStop).length
        : pathResults.where((p) => p.maxPrice >= aggStop).length;

    final consTpProb = consTpCount / _numSim;
    final consSlProb = consSlCount / _numSim;
    final aggTpProb = aggTpCount / _numSim;
    final aggSlProb = aggSlCount / _numSim;

    // ── Expected Value ──
    final consTpGain = (consExit - consEntry).abs();
    final consSlLoss = (consEntry - consStop).abs();
    final consEV = consTpProb * consTpGain - consSlProb * consSlLoss;
    final consCost = currentPrice * (_txCost + _slippage);
    final consEVAdj = consEV - consCost;

    final aggTpGain = (aggExit - aggEntry).abs();
    final aggSlLoss = (aggEntry - aggStop).abs();
    final aggEV = aggTpProb * aggTpGain - aggSlProb * aggSlLoss;
    final aggCost = currentPrice * (_txCost + _slippage);
    final aggEVAdj = aggEV - aggCost;

    // ── Kelly position sizing ──
    double consKelly = 0.0;
    if (consSlLoss > 0) {
      final fStar =
          (consTpProb * consTpGain - consSlProb * consSlLoss) / consSlLoss;
      consKelly = (_kellyFraction * fStar).clamp(0.0, _maxPositionSize);
    }

    double aggKelly = 0.0;
    if (aggSlLoss > 0) {
      final fStar = (aggTpProb * aggTpGain - aggSlProb * aggSlLoss) / aggSlLoss;
      aggKelly = (_kellyFraction * fStar).clamp(0.0, _maxPositionSize);
    }

    // ── ROI ──
    final consRoi = isLong
        ? _roi(consEntry, consExit)
        : _roi(consExit, consEntry); // short: profit when price falls
    final aggRoi = isLong ? _roi(aggEntry, aggExit) : _roi(aggExit, aggEntry);

    // ── Confidence (TP probability as percentage) ──
    final consConf = (consTpProb * 100).round().clamp(5, 95);
    final aggConf = (aggTpProb * 100).round().clamp(5, 95);

    // ── Strategy descriptions ──
    final dirLabel = isLong ? tr('analysis.dirLong') : tr('analysis.dirShort');
    final consDiscPct = ((consEntry - currentPrice).abs() / currentPrice * 100)
        .toStringAsFixed(2);
    final aggDiscPct = ((aggEntry - currentPrice).abs() / currentPrice * 100)
        .toStringAsFixed(2);

    final consDesc = tr(
      'analysis.strategyConservative',
      namedArgs: {
        'regime': regimeName,
        'direction': dirLabel,
        'orderType': isLong
            ? tr('analysis.limitBuy')
            : tr('analysis.limitSell'),
        'discount': consDiscPct,
        'side': isLong ? tr('analysis.below') : tr('analysis.above'),
        'tpProb': (consTpProb * 100).toStringAsFixed(1),
        'slProb': (consSlProb * 100).toStringAsFixed(1),
        'ev': consEVAdj.toStringAsFixed(2),
        'kelly': (consKelly * 100).toStringAsFixed(1),
        'stability': stabilityScore.toString(),
      },
    );

    final aggDesc = tr(
      'analysis.strategyAggressive',
      namedArgs: {
        'regime': regimeName,
        'direction': dirLabel,
        'orderType': isLong
            ? tr('analysis.limitBuy')
            : tr('analysis.limitSell'),
        'discount': aggDiscPct,
        'side': isLong ? tr('analysis.below') : tr('analysis.above'),
        'tpProb': (aggTpProb * 100).toStringAsFixed(1),
        'slProb': (aggSlProb * 100).toStringAsFixed(1),
        'ev': aggEVAdj.toStringAsFixed(2),
        'kelly': (aggKelly * 100).toStringAsFixed(1),
      },
    );

    // ── Trade acceptance filter ──
    // Accept if: EV_adj > 0 AND TP_prob > 0.40 (or forceInclude)
    if (forceInclude || (consEVAdj > 0 && consTpProb >= _minTpProb)) {
      positions.add(
        TradingPosition(
          direction: direction,
          entryPrice: _round4(consEntry),
          exitPrice: _round4(consExit),
          stopLoss: _round4(consStop),
          predictedROI: consRoi,
          confidenceScore: consConf,
          tpProbability: consTpProb,
          slProbability: consSlProb,
          expectedValue: consEVAdj,
          positionSizePct: consKelly * 100,
          strategyDescription: consDesc,
        ),
      );
    }

    if (forceInclude || (aggEVAdj > 0 && aggTpProb >= _minTpProb)) {
      positions.add(
        TradingPosition(
          direction: direction,
          entryPrice: _round4(aggEntry),
          exitPrice: _round4(aggExit),
          stopLoss: _round4(aggStop),
          predictedROI: aggRoi,
          confidenceScore: aggConf,
          tpProbability: aggTpProb,
          slProbability: aggSlProb,
          expectedValue: aggEVAdj,
          positionSizePct: aggKelly * 100,
          strategyDescription: aggDesc,
        ),
      );
    }

    return positions;
  }

  static double _roi(double entry, double exit) {
    return double.parse((((exit - entry) / entry) * 100).toStringAsFixed(2));
  }

  static double _round4(double v) => double.parse(v.toStringAsFixed(4));

  // ───────────────────────────────────────────────────────────────────────────
  // Public API
  // ───────────────────────────────────────────────────────────────────────────

  /// Analyze a single pair using the hybrid engine over [period].
  Future<CryptoAnalysisResult> analyzePair(
    String symbol, {
    TimePeriod period = TimePeriod.oneDay,
  }) async {
    final limit = period.hours <= 24
        ? 168
        : (period.hours * 2).ceil().clamp(168, 720);
    final klines = await _exchangeService.fetchHistoricalKlines(
      symbol,
      limit: limit,
    );
    if (klines.isEmpty) {
      throw Exception(
        tr('errors.noHistoricalData', namedArgs: {'symbol': symbol}),
      );
    }
    return _runHybridEngine(symbol, klines, period);
  }

  /// Scan top market leaders and return the best opportunities.
  /// Max 1 open trade recommendation (highest EV with entropy penalty).
  Future<MarketLeaderboardResult> scanTopMarket({
    TimePeriod period = TimePeriod.oneDay,
  }) async {
    final topSymbols = await _exchangeService.fetchTopUSDTByVolume(limit: 10);
    if (topSymbols.isEmpty) {
      throw Exception(tr('errors.failedFetchSymbols'));
    }

    final List<_AnalyzedPair> analyzedPairs = [];

    for (final symbol in topSymbols) {
      try {
        final klines = await _exchangeService.fetchHistoricalKlines(
          symbol,
          limit: 168,
        );
        if (klines.isEmpty) continue;
        final analysis = _runHybridEngine(symbol, klines, period);
        if (analysis.positions.isNotEmpty) {
          analyzedPairs.add(
            _AnalyzedPair(
              symbol: symbol,
              topPosition: analysis.positions[0],
              regimeInfo: analysis.regimeInfo,
            ),
          );
        }
      } catch (_) {
        continue;
      }
    }

    // Sort by entropy-penalized EV: EV × (1 − normalizedEntropy)
    final maxEntropy = log(3);
    analyzedPairs.sort((a, b) {
      final entropyA = a.regimeInfo?.regimeEntropy ?? 0.0;
      final entropyB = b.regimeInfo?.regimeEntropy ?? 0.0;
      final penaltyA = 1.0 - (entropyA / maxEntropy).clamp(0.0, 1.0);
      final penaltyB = 1.0 - (entropyB / maxEntropy).clamp(0.0, 1.0);
      final scoreA = a.topPosition.expectedValue * penaltyA;
      final scoreB = b.topPosition.expectedValue * penaltyB;
      return scoreB.compareTo(scoreA);
    });

    // Take top 3 (spec says max 1, but showing top 3 for information)
    final top3 = analyzedPairs.take(3).toList();

    final topPicks = top3.map((p) {
      final regLabel = p.regimeInfo?.currentRegime.label ?? 'Unknown';
      final stability = p.regimeInfo?.stabilityScore ?? 0;
      final entropyPct = p.regimeInfo != null
          ? (p.regimeInfo!.regimeEntropy / maxEntropy * 100).toStringAsFixed(0)
          : '?';
      return LeadPosition(
        symbol: p.symbol,
        direction: p.topPosition.direction,
        entryPrice: p.topPosition.entryPrice,
        exitPrice: p.topPosition.exitPrice,
        stopLoss: p.topPosition.stopLoss,
        predictedROI: p.topPosition.predictedROI,
        confidenceScore: p.topPosition.confidenceScore,
        expectedValue: p.topPosition.expectedValue,
        reasoning: tr(
          'leaderboard.reasoningTemplate',
          namedArgs: {
            'regime': regLabel,
            'stability': stability.toString(),
            'entropy': entropyPct,
            'direction': p.topPosition.direction.label,
            'paths': _numSim.toString(),
            'horizon': period.displayName,
            'ev': p.topPosition.expectedValue.toStringAsFixed(2),
          },
        ),
      );
    }).toList();

    // Count regime distribution
    int lowCount = 0, medCount = 0, highCount = 0;
    for (final p in analyzedPairs) {
      if (p.regimeInfo != null) {
        switch (p.regimeInfo!.currentRegime) {
          case VolatilityRegime.low:
            lowCount++;
          case VolatilityRegime.medium:
            medCount++;
          case VolatilityRegime.high:
            highCount++;
        }
      }
    }

    return MarketLeaderboardResult(
      topPicks: topPicks,
      globalOutlook: tr(
        'leaderboard.globalOutlookTemplate',
        namedArgs: {
          'horizon': period.displayName,
          'pairsCount': analyzedPairs.length.toString(),
          'lowCount': lowCount.toString(),
          'lowVolLabel': tr('analysis.regimeLowVolShort').toLowerCase(),
          'medCount': medCount.toString(),
          'trendingLabel': tr('analysis.regimeTrendingShort').toLowerCase(),
          'highCount': highCount.toString(),
          'highVolLabel': tr('analysis.regimeHighVolShort').toLowerCase(),
        },
      ),
    );
  }
}

class _AnalyzedPair {
  final String symbol;
  final TradingPosition topPosition;
  final RegimeInfo? regimeInfo;

  _AnalyzedPair({
    required this.symbol,
    required this.topPosition,
    this.regimeInfo,
  });
}
