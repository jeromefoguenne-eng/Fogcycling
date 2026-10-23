import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fogcycling/providers/ble_sensor_provider.dart';
import 'package:fogcycling/screens/hardware_test_screen.dart';

void main() {
  testWidgets('Fogcycling Hardware Test Screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BleSensorProvider()),
        ],
        child: const MaterialApp(
          home: HardwareTestScreen(),
        ),
      ),
    );

    // Verify key UI elements render
    expect(find.text("Fogcycling — Banc d'Essai Phase 1"), findsOneWidget);
    expect(find.text("ARRÊT D'URGENCE (1-TAP)"), findsOneWidget);
    expect(find.text("TRANSMISSION VIRTUELLE — ZWIFT COG"), findsOneWidget);
  });
}
