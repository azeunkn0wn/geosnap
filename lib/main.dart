import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const GeoSnapApp());
}

class GeoSnapApp extends StatelessWidget {
  const GeoSnapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoSnap',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const GeoSnapHome(),
    );
  }
}
