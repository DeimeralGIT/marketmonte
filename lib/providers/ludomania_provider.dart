import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLudomaniaPrefKey = 'ludomania_mode';

class LudomaniaNotifier extends StateNotifier<bool> {
  LudomaniaNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_kLudomaniaPrefKey) ?? false;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLudomaniaPrefKey, state);
  }
}

final ludomaniaProvider = StateNotifierProvider<LudomaniaNotifier, bool>((ref) {
  return LudomaniaNotifier();
});
