import 'package:flutter_test/flutter_test.dart';
import 'package:ltc/main.dart';

void main() {
  testWidgets('App loads LTC list screen', (WidgetTester tester) async {
    await tester.pumpWidget(const LtcApp());

    expect(find.text('LTC Spasticity Assessment'), findsOneWidget);
    expect(find.text('Sunrise Manor LTC'), findsOneWidget);
  });
}
