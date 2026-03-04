import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/binance_models.dart';
import '../../models/exchange_models.dart';
import '../exchange_service.dart';

/// Binance exchange service implementation.
class BinanceExchangeService implements ExchangeService {
  static const String _baseUrl = 'https://api.binance.com/api/v3';

  @override
  Exchange get exchange => Exchange.binance;

  @override
  Future<List<BinancePair>> fetchUSDTTradingPairs() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/exchangeInfo'));
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch exchange info');
      }
      final data = json.decode(response.body);
      final symbols = data['symbols'] as List;

      return symbols
          .where((s) => s['status'] == 'TRADING' && s['quoteAsset'] == 'USDT')
          .map((s) => BinancePair.fromJson(s as Map<String, dynamic>))
          .toList();
    } catch (error) {
      print('Error fetching Binance pairs: $error');
      return [];
    }
  }

  @override
  Future<List<String>> fetchTopUSDTByVolume({int limit = 10}) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/ticker/24hr'));
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch ticker data');
      }
      final data = json.decode(response.body) as List;

      final usdtPairs = data
          .where((t) => (t['symbol'] as String).endsWith('USDT'))
          .toList();

      usdtPairs.sort((a, b) {
        final volA = double.parse(b['quoteVolume'].toString());
        final volB = double.parse(a['quoteVolume'].toString());
        return volA.compareTo(volB);
      });

      return usdtPairs.take(limit).map((t) => t['symbol'] as String).toList();
    } catch (error) {
      print('Error fetching top volume pairs: $error');
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
        Uri.parse('$_baseUrl/klines?symbol=$symbol&interval=1h&limit=$limit'),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch klines for $symbol');
      }
      final data = json.decode(response.body) as List;

      return data.map((k) => KlineData.fromJson(k as List<dynamic>)).toList();
    } catch (error) {
      print('Error fetching klines for $symbol: $error');
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
        throw Exception('Failed to fetch ticker for $symbol');
      }
      return json.decode(response.body) as Map<String, dynamic>;
    } catch (error) {
      print('Error fetching ticker for $symbol: $error');
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
    final formattedSymbol = symbol.endsWith('USDT')
        ? '${symbol.replaceAll('USDT', '')}_USDT'
        : symbol;

    final params = <String, String>{'type': 'spot'};

    if (entryPrice != null && entryPrice > 0) {
      params['price'] = entryPrice.toString();
    }
    if (investmentAmount != null && investmentAmount > 0) {
      params['quoteOrderQty'] = investmentAmount.toStringAsFixed(2);
    }
    if (exitPrice != null && exitPrice > 0) {
      params['stopPrice'] = exitPrice.toString();
    }

    final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    return 'https://www.binance.com/en/trade/$formattedSymbol?$query';
  }
}
