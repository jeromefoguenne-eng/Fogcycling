import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/ble_sensor_provider.dart';
import 'providers/career_race_provider.dart';
import 'providers/workout_provider.dart';
import 'screens/cycling_ride_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BleSensorProvider()),
        ChangeNotifierProvider(create: (_) => WorkoutProvider()),
        ChangeNotifierProvider(create: (_) => CareerRaceProvider()),
      ],
      child: const FogcyclingApp(),
    ),
  );
}

class FogcyclingApp extends StatelessWidget {
  const FogcyclingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fogcycling',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B132B),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0284C7),
          brightness: Brightness.dark,
          surface: const Color(0xFF1C2541),
        ),
        useMaterial3: true,
      ),
      home: const CyclingRideScreen(),
    );
  }
}
