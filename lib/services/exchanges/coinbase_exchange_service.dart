import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/binance_models.dart';
import '../../models/exchange_models.dart';
import '../exchange_service.dart';

/// Coinbase Exchange (Advanced Trade) service implementation.
///
/// API docs: https://docs.cdp.coinbase.com/exchange/docs/welcome
/// Public endpoints — no auth required for market data.
class CoinbaseExchangeService implements ExchangeService {
  static const String _baseUrl = 'https://api.exchange.coinbase.com';

  @override
  Exchange get exchange => Exchange.coinbase;

  @override
  Future<List<BinancePair>> fetchUSDTTradingPairs() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/products'),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch Coinbase products');
      }
      final data = json.decode(response.body) as List;

      // Coinbase uses "USDT" as quote_currency for USDT pairs.
      // Also include USD pairs since Coinbase has more USD markets.
      return data
          .where(
            (p) =>
                p['status'] == 'online' &&
                (p['quote_currency'] == 'USDT' || p['quote_currency'] == 'USD'),
          )
          .map((p) {
            final base = p['base_currency'] as String;
            // Normalize to USDT symbol format for compatibility
            return BinancePair(
              symbol: '${base}USDT',
              baseAsset: base,
              quoteAsset: 'USDT',
            );
          })
          .toList();
    } catch (error) {
      print('Error fetching Coinbase pairs: $error');
      return [];
    }
  }

  @override
  Future<List<String>> fetchTopUSDTByVolume({int limit = 10}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/products/volume'),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode != 200) {
        // Fallback: get all products and sort by 24h stats
        return _fallbackTopByVolume(limit);
      }
      final data = json.decode(response.body) as List;

      // Filter for USD/USDT pairs and sort by volume
      final usdPairs = data.where((p) {
        final id = p['product_id']?.toString() ?? '';
        return id.endsWith('-USD') || id.endsWith('-USDT');
      }).toList();

      usdPairs.sort((a, b) {
        final volA = double.tryParse(b['volume']?.toString() ?? '0') ?? 0;
        final volB = double.tryParse(a['volume']?.toString() ?? '0') ?? 0;
        return volA.compareTo(volB);
      });

      return usdPairs.take(limit).map((p) {
        final id = p['product_id'] as String;
        final base = id.split('-').first;
        return '${base}USDT';
      }).toList();
    } catch (error) {
      print('Error fetching Coinbase top volume: $error');
      return _fallbackTopByVolume(limit);
    }
  }

  Future<List<String>> _fallbackTopByVolume(int limit) async {
    // Use well-known top pairs
    return [
      'BTCUSDT',
      'ETHUSDT',
      'SOLUSDT',
      'XRPUSDT',
      'DOGEUSDT',
      'ADAUSDT',
      'AVAXUSDT',
      'LINKUSDT',
      'DOTUSDT',
      'MATICUSDT',
    ].take(limit).toList();
  }

  /// Coinbase product ID format: "BTC-USD" or "BTC-USDT"
  String _toCoinbaseProductId(String symbol) {
    final base = symbol.replaceAll('USDT', '');
    // Try USDT first, fall back to USD
    return '$base-USD';
  }

  @override
  Future<List<KlineData>> fetchHistoricalKlines(
    String symbol, {
    int limit = 100,
  }) async {
    final productId = _toCoinbaseProductId(symbol);
    try {
      // Coinbase candles: granularity=3600 (1 hour)
      // Max 300 candles per request
      final clampedLimit = limit.clamp(1, 300);
      final end = DateTime.now().toUtc();
      final start = end.subtract(Duration(hours: clampedLimit));

      final response = await http.get(
        Uri.parse(
          '$_baseUrl/products/$productId/candles'
          '?granularity=3600'
          '&start=${start.toIso8601String()}'
          '&end=${end.toIso8601String()}',
        ),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch candles for $productId');
      }
      final data = json.decode(response.body) as List;

      // Coinbase candles: [timestamp, low, high, open, close, volume]
      // Returned in reverse chronological order
      final klines = data.map((c) {
        final candle = c as List;
        return KlineData(
          time: ((candle[0] as num).toInt()) * 1000, // seconds → millis
          open: double.parse(candle[3].toString()),
          high: double.parse(candle[2].toString()),
          low: double.parse(candle[1].toString()),
          close: double.parse(candle[4].toString()),
          volume: double.parse(candle[5].toString()),
        );
      }).toList();

      // Sort chronologically (oldest first)
      klines.sort((a, b) => a.time.compareTo(b.time));
      return klines;
    } catch (error) {
      print('Error fetching Coinbase candles for $productId: $error');
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>?> fetch24hTicker(String symbol) async {
    final productId = _toCoinbaseProductId(symbol);
    try {
      // Fetch both ticker and 24h stats
      final results = await Future.wait([
        http.get(
          Uri.parse('$_baseUrl/products/$productId/ticker'),
          headers: {'Accept': 'application/json'},
        ),
        http.get(
          Uri.parse('$_baseUrl/products/$productId/stats'),
          headers: {'Accept': 'application/json'},
        ),
      ]);

      final tickerResp = results[0];
      final statsResp = results[1];

      if (tickerResp.statusCode != 200) {
        throw Exception('Failed to fetch ticker for $productId');
      }

      final ticker = json.decode(tickerResp.body) as Map<String, dynamic>;
      Map<String, dynamic> stats = {};
      if (statsResp.statusCode == 200) {
        stats = json.decode(statsResp.body) as Map<String, dynamic>;
      }

      final lastPrice =
          double.tryParse(ticker['price']?.toString() ?? '0') ?? 0;
      final openPrice = double.tryParse(stats['open']?.toString() ?? '0') ?? 0;
      final changePercent = openPrice > 0
          ? ((lastPrice - openPrice) / openPrice) * 100
          : 0;

      // Normalize to the same format as Binance ticker
      return {
        'lastPrice': ticker['price'] ?? '0',
        'highPrice': stats['high'] ?? '0',
        'lowPrice': stats['low'] ?? '0',
        'volume': stats['volume'] ?? ticker['volume'] ?? '0',
        'priceChangePercent': changePercent.toStringAsFixed(4),
      };
    } catch (error) {
      print('Error fetching Coinbase ticker for $productId: $error');
      return null;
    }
  }

  @override
  String getTradeUrl(
    String symbol, {
    double? investmentAmount,
    double? entryPrice,
    double? exitPrice,
  }) {
    final base = symbol.replaceAll('USDT', '');
    return 'https://www.coinbase.com/advanced-trade/spot/$base-USD';
  }
}
