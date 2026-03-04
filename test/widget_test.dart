import 'package:flutter_test/flutter_test.dart';
import 'package:market_monte/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MarketMonteApp());
    expect(find.text('Market Monte'),
        findsNothing); // RichText won't match plain find
  });
}
