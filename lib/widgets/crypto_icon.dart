import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A reusable widget that displays a cryptocurrency icon fetched from CDN,
/// with a styled letter fallback if the image fails to load.
class CryptoIcon extends StatelessWidget {
  final String symbol;
  final double size;

  const CryptoIcon({super.key, required this.symbol, this.size = 28});

  /// Returns the icon URL from the CoinCap CDN for a given base asset symbol.
  static String iconUrl(String baseAsset) {
    return 'https://assets.coincap.io/assets/icons/${baseAsset.toLowerCase()}@2x.png';
  }

  @override
  Widget build(BuildContext context) {
    final baseAsset = symbol.replaceAll('USDT', '');

    return ClipOval(
      child: Image.network(
        iconUrl(baseAsset),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            _Fallback(letter: baseAsset[0], size: size),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  final String letter;
  final double size;
  const _Fallback({required this.letter, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.accent.withValues(alpha: 0.15),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: size * 0.5,
          fontWeight: FontWeight.bold,
          color: AppColors.accent,
        ),
      ),
    );
  }
}
