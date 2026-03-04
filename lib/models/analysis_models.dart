import 'package:easy_localization/easy_localization.dart';

/// A string whose translation is deferred to render-time so that
/// locale changes are reflected immediately without re-running analysis.
class TranslatableString {
  final String key;
  final Map<String, String> namedArgs;

  /// Args whose values are themselves translation keys.
  /// At translate-time each value is run through `tr()` before being
  /// merged into [namedArgs].
  final Map<String, String> translatableArgs;

  /// Subset of [translatableArgs] whose translated result should be
  /// lower-cased (e.g. regime labels inside a sentence).
  final Set<String> lowercaseArgs;

  const TranslatableString({
    required this.key,
    this.namedArgs = const {},
    this.translatableArgs = const {},
    this.lowercaseArgs = const {},
  });

  /// Produce the final user-visible string in the **current** locale.
  String translate() {
    final allArgs = Map<String, String>.from(namedArgs);
    for (final entry in translatableArgs.entries) {
      String val = tr(entry.value);
      if (lowercaseArgs.contains(entry.key)) val = val.toLowerCase();
      allArgs[entry.key] = val;
    }
    return tr(key, namedArgs: allArgs);
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'namedArgs': namedArgs,
    'translatableArgs': translatableArgs,
    'lowercaseArgs': lowercaseArgs.toList(),
  };

  factory TranslatableString.fromJson(Map<String, dynamic> json) {
    return TranslatableString(
      key: json['key'] as String,
      namedArgs: Map<String, String>.from(json['namedArgs'] as Map? ?? {}),
      translatableArgs: Map<String, String>.from(
        json['translatableArgs'] as Map? ?? {},
      ),
      lowercaseArgs: Set<String>.from(json['lowercaseArgs'] as List? ?? []),
    );
  }

  @override
  String toString() => translate();
}

/// Investment time horizon for projection.
enum TimePeriod {
  oneHour('1H', 1, '1 Hour'),
  fourHours('4H', 4, '4 Hours'),
  oneDay('1D', 24, '1 Day'),
  oneWeek('1W', 168, '1 Week'),
  oneMonth('1M', 720, '1 Month');

  final String label;
  final int hours;
  final String displayName;

  const TimePeriod(this.label, this.hours, this.displayName);
}

/// Detected volatility regime.
enum VolatilityRegime {
  low('Low Volatility', 'Calm / Mean-Reverting'),
  medium('Medium Volatility', 'Trending / Normal'),
  high('High Volatility', 'Turbulent / Crisis');

  final String label;
  final String description;

  const VolatilityRegime(this.label, this.description);
}

/// Trade direction.
enum TradeDirection {
  long('Long'),
  short('Short');

  final String label;

  const TradeDirection(this.label);
}

/// Regime detection metadata attached to analysis results.
class RegimeInfo {
  /// Current most-likely regime.
  final VolatilityRegime currentRegime;

  /// Probability for each regime [low, medium, high].
  final List<double> regimeProbs;

  /// Per-regime annualised volatility (for display).
  final List<double> regimeAnnualisedVols;

  /// Per-regime hourly drift.
  final List<double> regimeDrifts;

  /// Per-regime degrees of freedom (Student-t ν parameter).
  final List<double> regimeNus;

  /// One-step regime transition probabilities from current regime.
  final List<double> transitionFromCurrent;

  /// Regime stability score: how "sticky" the current regime is (0–100).
  final int stabilityScore;

  /// Regime entropy: −Σ π_k log(π_k). Higher = more uncertain.
  final double regimeEntropy;

  const RegimeInfo({
    required this.currentRegime,
    required this.regimeProbs,
    required this.regimeAnnualisedVols,
    required this.regimeDrifts,
    required this.regimeNus,
    required this.transitionFromCurrent,
    required this.stabilityScore,
    required this.regimeEntropy,
  });

  factory RegimeInfo.fromJson(Map<String, dynamic> json) {
    return RegimeInfo(
      currentRegime: VolatilityRegime.values[json['currentRegime'] as int],
      regimeProbs: (json['regimeProbs'] as List).cast<double>(),
      regimeAnnualisedVols: (json['regimeAnnualisedVols'] as List)
          .cast<double>(),
      regimeDrifts: (json['regimeDrifts'] as List).cast<double>(),
      regimeNus: (json['regimeNus'] as List).cast<double>(),
      transitionFromCurrent: (json['transitionFromCurrent'] as List)
          .cast<double>(),
      stabilityScore: json['stabilityScore'] as int,
      regimeEntropy: (json['regimeEntropy'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'currentRegime': currentRegime.index,
    'regimeProbs': regimeProbs,
    'regimeAnnualisedVols': regimeAnnualisedVols,
    'regimeDrifts': regimeDrifts,
    'regimeNus': regimeNus,
    'transitionFromCurrent': transitionFromCurrent,
    'stabilityScore': stabilityScore,
    'regimeEntropy': regimeEntropy,
  };
}

/// Distribution statistics from the Monte Carlo simulation.
class DistributionStats {
  final double mean;
  final double stdDev;
  final double skewness;
  final double kurtosis;
  final double p5;
  final double p10;
  final double p25;
  final double p50;
  final double p75;
  final double p90;
  final double p95;

  const DistributionStats({
    required this.mean,
    required this.stdDev,
    required this.skewness,
    required this.kurtosis,
    required this.p5,
    required this.p10,
    required this.p25,
    required this.p50,
    required this.p75,
    required this.p90,
    required this.p95,
  });

  Map<String, dynamic> toJson() => {
    'mean': mean,
    'stdDev': stdDev,
    'skewness': skewness,
    'kurtosis': kurtosis,
    'p5': p5,
    'p10': p10,
    'p25': p25,
    'p50': p50,
    'p75': p75,
    'p90': p90,
    'p95': p95,
  };
}

class TradingPosition {
  final TradeDirection direction;
  final double entryPrice;
  final double exitPrice;
  final double stopLoss;
  final double predictedROI;
  final int confidenceScore;
  final double tpProbability;
  final double slProbability;
  final double expectedValue;
  final double positionSizePct;
  final TranslatableString strategyDescription;
  final bool isLudomania;

  TradingPosition({
    required this.direction,
    required this.entryPrice,
    required this.exitPrice,
    required this.stopLoss,
    required this.predictedROI,
    required this.confidenceScore,
    required this.tpProbability,
    required this.slProbability,
    required this.expectedValue,
    required this.positionSizePct,
    required this.strategyDescription,
    this.isLudomania = false,
  });

  factory TradingPosition.fromJson(Map<String, dynamic> json) {
    return TradingPosition(
      direction: TradeDirection.values[json['direction'] as int? ?? 0],
      entryPrice: (json['entryPrice'] as num).toDouble(),
      exitPrice: (json['exitPrice'] as num).toDouble(),
      stopLoss: (json['stopLoss'] as num?)?.toDouble() ?? 0.0,
      predictedROI: (json['predictedROI'] as num).toDouble(),
      confidenceScore: json['confidenceScore'] as int,
      tpProbability: (json['tpProbability'] as num?)?.toDouble() ?? 0.0,
      slProbability: (json['slProbability'] as num?)?.toDouble() ?? 0.0,
      expectedValue: (json['expectedValue'] as num?)?.toDouble() ?? 0.0,
      positionSizePct: (json['positionSizePct'] as num?)?.toDouble() ?? 0.0,
      strategyDescription: TranslatableString.fromJson(
        json['strategyDescription'] as Map<String, dynamic>,
      ),
      isLudomania: json['isLudomania'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'direction': direction.index,
    'entryPrice': entryPrice,
    'exitPrice': exitPrice,
    'stopLoss': stopLoss,
    'predictedROI': predictedROI,
    'confidenceScore': confidenceScore,
    'tpProbability': tpProbability,
    'slProbability': slProbability,
    'expectedValue': expectedValue,
    'positionSizePct': positionSizePct,
    'strategyDescription': strategyDescription.toJson(),
    'isLudomania': isLudomania,
  };
}

class CryptoAnalysisResult {
  final List<TradingPosition> positions;
  final TranslatableString analysisSummary;
  final RegimeInfo? regimeInfo;
  final DistributionStats? distributionStats;

  CryptoAnalysisResult({
    required this.positions,
    required this.analysisSummary,
    this.regimeInfo,
    this.distributionStats,
  });

  factory CryptoAnalysisResult.fromJson(Map<String, dynamic> json) {
    return CryptoAnalysisResult(
      positions: (json['positions'] as List)
          .map((p) => TradingPosition.fromJson(p as Map<String, dynamic>))
          .toList(),
      analysisSummary: TranslatableString.fromJson(
        json['analysisSummary'] as Map<String, dynamic>,
      ),
      regimeInfo: json['regimeInfo'] != null
          ? RegimeInfo.fromJson(json['regimeInfo'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'positions': positions.map((p) => p.toJson()).toList(),
    'analysisSummary': analysisSummary.toJson(),
    if (regimeInfo != null) 'regimeInfo': regimeInfo!.toJson(),
    if (distributionStats != null)
      'distributionStats': distributionStats!.toJson(),
  };
}

class LeadPosition {
  final String symbol;
  final TradeDirection direction;
  final double entryPrice;
  final double exitPrice;
  final double stopLoss;
  final double predictedROI;
  final int confidenceScore;
  final double expectedValue;
  final TranslatableString reasoning;

  LeadPosition({
    required this.symbol,
    required this.direction,
    required this.entryPrice,
    required this.exitPrice,
    required this.stopLoss,
    required this.predictedROI,
    required this.confidenceScore,
    required this.expectedValue,
    required this.reasoning,
  });

  factory LeadPosition.fromJson(Map<String, dynamic> json) {
    return LeadPosition(
      symbol: json['symbol'] as String,
      direction: TradeDirection.values[json['direction'] as int? ?? 0],
      entryPrice: (json['entryPrice'] as num).toDouble(),
      exitPrice: (json['exitPrice'] as num).toDouble(),
      stopLoss: (json['stopLoss'] as num?)?.toDouble() ?? 0.0,
      predictedROI: (json['predictedROI'] as num).toDouble(),
      confidenceScore: json['confidenceScore'] as int,
      expectedValue: (json['expectedValue'] as num?)?.toDouble() ?? 0.0,
      reasoning: TranslatableString.fromJson(
        json['reasoning'] as Map<String, dynamic>,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'direction': direction.index,
    'entryPrice': entryPrice,
    'exitPrice': exitPrice,
    'stopLoss': stopLoss,
    'predictedROI': predictedROI,
    'confidenceScore': confidenceScore,
    'expectedValue': expectedValue,
    'reasoning': reasoning.toJson(),
  };
}

class MarketLeaderboardResult {
  final List<LeadPosition> topPicks;
  final TranslatableString globalOutlook;

  MarketLeaderboardResult({
    required this.topPicks,
    required this.globalOutlook,
  });

  factory MarketLeaderboardResult.fromJson(Map<String, dynamic> json) {
    return MarketLeaderboardResult(
      topPicks: (json['topPicks'] as List)
          .map((p) => LeadPosition.fromJson(p as Map<String, dynamic>))
          .toList(),
      globalOutlook: TranslatableString.fromJson(
        json['globalOutlook'] as Map<String, dynamic>,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'topPicks': topPicks.map((p) => p.toJson()).toList(),
    'globalOutlook': globalOutlook.toJson(),
  };
}
