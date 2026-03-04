/// Investment time horizon for MCMC projection.
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

class TradingPosition {
  final double entryPrice;
  final double exitPrice;
  final double predictedROI;
  final int confidenceScore;
  final String strategyDescription;

  TradingPosition({
    required this.entryPrice,
    required this.exitPrice,
    required this.predictedROI,
    required this.confidenceScore,
    required this.strategyDescription,
  });

  factory TradingPosition.fromJson(Map<String, dynamic> json) {
    return TradingPosition(
      entryPrice: (json['entryPrice'] as num).toDouble(),
      exitPrice: (json['exitPrice'] as num).toDouble(),
      predictedROI: (json['predictedROI'] as num).toDouble(),
      confidenceScore: json['confidenceScore'] as int,
      strategyDescription: json['strategyDescription'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'entryPrice': entryPrice,
    'exitPrice': exitPrice,
    'predictedROI': predictedROI,
    'confidenceScore': confidenceScore,
    'strategyDescription': strategyDescription,
  };
}

class CryptoAnalysisResult {
  final List<TradingPosition> positions;
  final String analysisSummary;

  CryptoAnalysisResult({
    required this.positions,
    required this.analysisSummary,
  });

  factory CryptoAnalysisResult.fromJson(Map<String, dynamic> json) {
    return CryptoAnalysisResult(
      positions: (json['positions'] as List)
          .map((p) => TradingPosition.fromJson(p as Map<String, dynamic>))
          .toList(),
      analysisSummary: json['analysisSummary'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'positions': positions.map((p) => p.toJson()).toList(),
    'analysisSummary': analysisSummary,
  };
}

class LeadPosition {
  final String symbol;
  final double entryPrice;
  final double exitPrice;
  final double predictedROI;
  final int confidenceScore;
  final String reasoning;

  LeadPosition({
    required this.symbol,
    required this.entryPrice,
    required this.exitPrice,
    required this.predictedROI,
    required this.confidenceScore,
    required this.reasoning,
  });

  factory LeadPosition.fromJson(Map<String, dynamic> json) {
    return LeadPosition(
      symbol: json['symbol'] as String,
      entryPrice: (json['entryPrice'] as num).toDouble(),
      exitPrice: (json['exitPrice'] as num).toDouble(),
      predictedROI: (json['predictedROI'] as num).toDouble(),
      confidenceScore: json['confidenceScore'] as int,
      reasoning: json['reasoning'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'entryPrice': entryPrice,
    'exitPrice': exitPrice,
    'predictedROI': predictedROI,
    'confidenceScore': confidenceScore,
    'reasoning': reasoning,
  };
}

class MarketLeaderboardResult {
  final List<LeadPosition> topPicks;
  final String globalOutlook;

  MarketLeaderboardResult({
    required this.topPicks,
    required this.globalOutlook,
  });

  factory MarketLeaderboardResult.fromJson(Map<String, dynamic> json) {
    return MarketLeaderboardResult(
      topPicks: (json['topPicks'] as List)
          .map((p) => LeadPosition.fromJson(p as Map<String, dynamic>))
          .toList(),
      globalOutlook: json['globalOutlook'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'topPicks': topPicks.map((p) => p.toJson()).toList(),
    'globalOutlook': globalOutlook,
  };
}
