import 'dart:math';
import '../models/analysis_models.dart';
import '../models/binance_models.dart';
import 'binance_service.dart';

class AnalysisService {
  final BinanceService _binanceService;

  AnalysisService(this._binanceService);

  /// Box-Muller transform to generate a standard normal random variable.
  static double _normalRandom(Random rng) {
    final u1 = rng.nextDouble();
    final u2 = rng.nextDouble();
    return sqrt(-2.0 * log(u1)) * cos(2.0 * pi * u2);
  }

  /// Run the MCMC Monte Carlo simulation engine on kline data,
  /// projecting forward over [period] using Geometric Brownian Motion.
  CryptoAnalysisResult _runLocalMCMC(
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

    final meanReturn = logReturns.reduce((a, b) => a + b) / logReturns.length;
    final variance =
        logReturns.map((r) => pow(r - meanReturn, 2)).reduce((a, b) => a + b) /
        logReturns.length;
    final hourlyVol = sqrt(variance);

    // ── 2. Scale drift & volatility to the projection period ──
    final T = period.hours.toDouble();
    // GBM closed-form: S_T = S_0 * exp((mu - 0.5*sigma^2)*T + sigma*sqrt(T)*Z)
    final periodDrift = (meanReturn - 0.5 * hourlyVol * hourlyVol) * T;
    final periodVol = hourlyVol * sqrt(T);

    // ── 3. Monte Carlo simulation (10 000 paths, closed-form GBM) ──
    final rng = Random(42); // fixed seed for reproducibility
    const numSim = 10000;
    final simPrices = List<double>.filled(numSim, 0.0);

    for (int i = 0; i < numSim; i++) {
      final z = _normalRandom(rng);
      simPrices[i] = currentPrice * exp(periodDrift + periodVol * z);
    }
    simPrices.sort();

    // ── 4. Distribution percentiles ──
    double percentile(double p) => simPrices[(numSim * p).floor()];
    final p10 = percentile(0.10);
    final p25 = percentile(0.25);
    final p50 = percentile(0.50);
    final p75 = percentile(0.75);
    final p90 = percentile(0.90);

    // ── 5. Probability of profit ──
    final profitCount = simPrices.where((p) => p > currentPrice).length;
    final profitProb = profitCount / numSim;

    // ── 6. Annualised volatility for display ──
    final annualisedVol = hourlyVol * sqrt(8760.0); // hours in a year
    final volPercent = (annualisedVol * 100).toStringAsFixed(2);

    // ── 7. Build trading positions from simulation results ──
    // Position A – Conservative: slight dip entry, median exit
    final consEntry = currentPrice * 0.998;
    final consExit = p50;
    final consRoi = double.parse(
      (((consExit - consEntry) / consEntry) * 100).toStringAsFixed(2),
    );
    final consConf = (profitProb * 100 * 0.90).clamp(10, 95).floor();

    // Position B – Aggressive: market entry, 75th-percentile exit
    final aggEntry = currentPrice * 1.002;
    final aggExit = p75;
    final aggRoi = double.parse(
      (((aggExit - aggEntry) / aggEntry) * 100).toStringAsFixed(2),
    );
    final aggConf = (profitProb * 100 * 0.65).clamp(10, 85).floor();

    final positions = [
      TradingPosition(
        entryPrice: double.parse(consEntry.toStringAsFixed(4)),
        exitPrice: double.parse(consExit.toStringAsFixed(4)),
        predictedROI: consRoi,
        confidenceScore: consConf,
        strategyDescription:
            'Conservative mean-reversion entry with median (P50) exit over '
            '${period.displayName}. Monte Carlo profit probability: '
            '${(profitProb * 100).toStringAsFixed(1)}%.',
      ),
      TradingPosition(
        entryPrice: double.parse(aggEntry.toStringAsFixed(4)),
        exitPrice: double.parse(aggExit.toStringAsFixed(4)),
        predictedROI: aggRoi,
        confidenceScore: aggConf,
        strategyDescription:
            'Aggressive breakout targeting the 75th-percentile (P75) price '
            'over ${period.displayName}. Upside potential to P90: '
            '\$${p90.toStringAsFixed(2)}.',
      ),
    ];

    // Sort by predictedROI descending
    positions.sort((a, b) => b.predictedROI.compareTo(a.predictedROI));

    final trendLabel = (p50 > currentPrice) ? 'bullish' : 'bearish';
    final supportPrice = p10.toStringAsFixed(2);

    return CryptoAnalysisResult(
      positions: positions,
      analysisSummary:
          'MCMC Engine (${period.displayName} horizon, $numSim simulations): '
          '$symbol shows a $trendLabel outlook with annualised volatility of '
          '$volPercent%. The median projected price is '
          '\$${p50.toStringAsFixed(2)} (P25: \$${p25.toStringAsFixed(2)}, '
          'P75: \$${p75.toStringAsFixed(2)}). Statistical support near '
          '\$$supportPrice.',
    );
  }

  /// Analyze a single pair using MCMC engine over [period].
  Future<CryptoAnalysisResult> analyzePair(
    String symbol, {
    TimePeriod period = TimePeriod.oneDay,
  }) async {
    // Fetch enough hourly candles for reliable statistics
    final limit = period.hours <= 24
        ? 100
        : (period.hours * 1.5).ceil().clamp(100, 500);
    final klines = await _binanceService.fetchHistoricalKlines(
      symbol,
      limit: limit,
    );
    if (klines.isEmpty) {
      throw Exception('No historical data available for $symbol');
    }
    return _runLocalMCMC(symbol, klines, period);
  }

  /// Scan top market leaders and return the best 3 opportunities.
  Future<MarketLeaderboardResult> scanTopMarket({
    TimePeriod period = TimePeriod.oneDay,
  }) async {
    final topSymbols = await _binanceService.fetchTopUSDTByVolume(limit: 10);
    if (topSymbols.isEmpty) {
      throw Exception('Failed to fetch top market symbols');
    }

    final List<_AnalyzedPair> analyzedPairs = [];

    for (final symbol in topSymbols) {
      try {
        final klines = await _binanceService.fetchHistoricalKlines(
          symbol,
          limit: 100,
        );
        if (klines.isEmpty) continue;
        final analysis = _runLocalMCMC(symbol, klines, period);
        analyzedPairs.add(
          _AnalyzedPair(symbol: symbol, topPosition: analysis.positions[0]),
        );
      } catch (_) {
        continue;
      }
    }

    // Sort by ROI descending, take top 3
    analyzedPairs.sort(
      (a, b) =>
          b.topPosition.predictedROI.compareTo(a.topPosition.predictedROI),
    );
    final top3 = analyzedPairs.take(3).toList();

    final topPicks = top3
        .map(
          (p) => LeadPosition(
            symbol: p.symbol,
            entryPrice: p.topPosition.entryPrice,
            exitPrice: p.topPosition.exitPrice,
            predictedROI: p.topPosition.predictedROI,
            confidenceScore: p.topPosition.confidenceScore,
            reasoning:
                'Leading risk-adjusted ROI over ${period.displayName} horizon '
                'using Monte Carlo projection (10 000 simulations).',
          ),
        )
        .toList();

    return MarketLeaderboardResult(
      topPicks: topPicks,
      globalOutlook:
          'Market scan over a ${period.displayName} horizon using MCMC '
          'statistical models. High-volume leaders ranked by simulated '
          'risk-adjusted return potential.',
    );
  }
}

class _AnalyzedPair {
  final String symbol;
  final TradingPosition topPosition;

  _AnalyzedPair({required this.symbol, required this.topPosition});
}
