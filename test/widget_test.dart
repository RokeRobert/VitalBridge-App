import 'package:flutter_test/flutter_test.dart';
import 'package:vital_bridge/main.dart';

void main() {
  testWidgets('Carga de la aplicación VitalBridge', (WidgetTester tester) async {
    await tester.pumpWidget(const VitalBridgeApp());
    expect(find.byType(VitalBridgeApp), findsOneWidget);
  });
}