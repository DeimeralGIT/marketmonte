import '../models/binance_models.dart';
import '../models/exchange_models.dart';

/// Abstract interface that all exchange services must implement.
/// Uses [BinancePair] and [KlineData] as common data types since they are
/// generic enough (symbol + baseAsset + quoteAsset, OHLCV candles).
abstract class ExchangeService {
  /// The exchange this service represents.
  Exchange get exchange;

  /// Fetch all USDT-quoted trading pairs.
  Future<List<BinancePair>> fetchUSDTTradingPairs();

  /// Fetch the top USDT pairs by 24h quote volume.
  Future<List<String>> fetchTopUSDTByVolume({int limit = 10});

  /// Fetch historical kline (candlestick) data for a symbol.
  Future<List<KlineData>> fetchHistoricalKlines(
    String symbol, {
    int limit = 100,
  });

  /// Fetch 24h ticker data for a symbol.
  /// Returns a map with at least: lastPrice, highPrice, lowPrice, volume,
  /// priceChangePercent.
  Future<Map<String, dynamic>?> fetch24hTicker(String symbol);

  /// Generate a deep-link URL for trading a pair on the exchange.
  String getTradeUrl(
    String symbol, {
    double? investmentAmount,
    double? entryPrice,
    double? exitPrice,
  });
}
