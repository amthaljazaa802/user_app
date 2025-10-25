import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/main_map/main_map_screen.dart'; // استيراد الشاشة الرئيسية الجديدة
import 'repositories/transport_repository.dart';
import 'services/tracking_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TrackingService>(
          create: (_) => TrackingService(),
          dispose: (_, service) => service.dispose(),
        ),
        Provider<TransportRepository>(
          create: (ctx) =>
              TrackingTransportRepository(ctx.read<TrackingService>()),
          dispose: (_, repo) => repo.dispose(),
        ),
      ],
      child: MaterialApp(
        title: 'Bus Tracking App',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const MainMapScreen(), // تعيين MainMapScreen كشاشة رئيسية
      ),
    );
  }
}
