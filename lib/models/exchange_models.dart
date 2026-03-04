/// Supported stock exchanges.
enum Exchange {
  binance('Binance', 'binance'),
  coinbase('Coinbase', 'coinbase'),
  mexc('MEXC', 'mexc');

  final String displayName;
  final String key;
  const Exchange(this.displayName, this.key);

  /// Resolve from stored string key.
  static Exchange fromKey(String key) {
    return Exchange.values.firstWhere(
      (e) => e.key == key,
      orElse: () => Exchange.binance,
    );
  }
}
