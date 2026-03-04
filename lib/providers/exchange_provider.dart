import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/exchange_models.dart';

const _kExchangePrefKey = 'preferred_exchange';

class ExchangeNotifier extends StateNotifier<Exchange> {
  ExchangeNotifier() : super(Exchange.binance) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kExchangePrefKey);
    if (stored != null) {
      state = Exchange.fromKey(stored);
    }
  }

  Future<void> setExchange(Exchange exchange) async {
    state = exchange;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kExchangePrefKey, exchange.key);
  }
}

final exchangeProvider = StateNotifierProvider<ExchangeNotifier, Exchange>((
  ref,
) {
  return ExchangeNotifier();
});
