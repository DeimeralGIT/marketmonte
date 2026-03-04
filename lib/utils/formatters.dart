import 'package:intl/intl.dart';

/// Format a price with commas and appropriate decimal places.
String formatPrice(double price) {
  if (price >= 1) {
    return NumberFormat('#,##0.00', 'en_US').format(price);
  } else if (price >= 0.01) {
    return NumberFormat('#,##0.0000', 'en_US').format(price);
  } else {
    return NumberFormat('#,##0.00000000', 'en_US').format(price);
  }
}

/// Format volume with commas.
String formatVolume(double volume) {
  return NumberFormat('#,##0.00', 'en_US').format(volume);
}

/// Format ROI as "+X.XX%" or "-X.XX%".
String formatROI(double roi) {
  final sign = roi >= 0 ? '+' : '';
  return '$sign${roi.toStringAsFixed(2)}%';
}
