import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/binance_models.dart';
import '../../models/exchange_models.dart';
import '../exchange_service.dart';

/// MEXC exchange service implementation.
///
/// MEXC Spot V3 API mirrors the Binance API structure closely.
/// Public endpoints — no auth required for market data.
/// Docs: https://www.mexc.com/api-docs/spot-v3
class MexcExchangeService implements ExchangeService {
  static const String _baseUrl = 'https://api.mexc.com/api/v3';

  @override
  Exchange get exchange => Exchange.mexc;

  @override
  Future<List<BinancePair>> fetchUSDTTradingPairs() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/exchangeInfo'));
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch MEXC exchange info');
      }
      final data = json.decode(response.body);
      final symbols = data['symbols'] as List;

      return symbols
          .where(
            (s) =>
                (s['status'] == '1' || s['status'] == 'ENABLED') &&
                s['isSpotTradingAllowed'] == true &&
                s['quoteAsset'] == 'USDT',
          )
          .map(
            (s) => BinancePair(
              symbol: s['symbol'] as String,
              baseAsset: s['baseAsset'] as String,
              quoteAsset: s['quoteAsset'] as String,
            ),
          )
          .toList();
    } catch (error) {
      print('Error fetching MEXC pairs: $error');
      return [];
    }
  }

  @override
  Future<List<String>> fetchTopUSDTByVolume({int limit = 10}) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/ticker/24hr'));
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch MEXC ticker data');
      }
      final data = json.decode(response.body) as List;

      final usdtPairs = data
          .where((t) => (t['symbol'] as String).endsWith('USDT'))
          .toList();

      usdtPairs.sort((a, b) {
        final volA = double.tryParse(b['quoteVolume']?.toString() ?? '0') ?? 0;
        final volB = double.tryParse(a['quoteVolume']?.toString() ?? '0') ?? 0;
        return volA.compareTo(volB);
      });

      return usdtPairs.take(limit).map((t) => t['symbol'] as String).toList();
    } catch (error) {
      print('Error fetching MEXC top volume pairs: $error');
      return [];
    }
  }

  @override
  Future<List<KlineData>> fetchHistoricalKlines(
    String symbol, {
    int limit = 100,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/klines?symbol=$symbol&interval=60m&limit=$limit'),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch MEXC klines for $symbol');
      }
      final data = json.decode(response.body) as List;

      return data.map((k) {
        final candle = k as List;
        return KlineData(
          time: (candle[0] as num).toInt(),
          open: double.parse(candle[1].toString()),
          high: double.parse(candle[2].toString()),
          low: double.parse(candle[3].toString()),
          close: double.parse(candle[4].toString()),
          volume: double.parse(candle[5].toString()),
        );
      }).toList();
    } catch (error) {
      print('Error fetching MEXC klines for $symbol: $error');
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>?> fetch24hTicker(String symbol) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/ticker/24hr?symbol=$symbol'),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch MEXC ticker for $symbol');
      }
      final data = json.decode(response.body);

      // MEXC returns the same field names as Binance
      return data as Map<String, dynamic>;
    } catch (error) {
      print('Error fetching MEXC ticker for $symbol: $error');
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
    return 'https://www.mexc.com/exchange/${base}_USDT';
  }
}
