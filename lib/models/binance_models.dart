class BinancePair {
  final String symbol;
  final String baseAsset;
  final String quoteAsset;

  BinancePair({
    required this.symbol,
    required this.baseAsset,
    required this.quoteAsset,
  });

  factory BinancePair.fromJson(Map<String, dynamic> json) {
    return BinancePair(
      symbol: json['symbol'] as String,
      baseAsset: json['baseAsset'] as String,
      quoteAsset: json['quoteAsset'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'baseAsset': baseAsset,
        'quoteAsset': quoteAsset,
      };
}

class KlineData {
  final int time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  KlineData({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  /// Binance klines returns arrays:
  /// [openTime, open, high, low, close, volume, ...]
  /// Index 0=time, 1=open, 2=high, 3=low, 4=close, 5=volume (all strings → doubles)
  factory KlineData.fromJson(List<dynamic> json) {
    return KlineData(
      time: json[0] as int,
      open: double.parse(json[1].toString()),
      high: double.parse(json[2].toString()),
      low: double.parse(json[3].toString()),
      close: double.parse(json[4].toString()),
      volume: double.parse(json[5].toString()),
    );
  }

  Map<String, dynamic> toJson() => {
        'time': time,
        'open': open,
        'high': high,
        'low': low,
        'close': close,
        'volume': volume,
      };
}
