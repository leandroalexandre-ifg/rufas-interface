import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'screens/farm_list_screen.dart';

void main() {
  runApp(const RufasApp());
}

class RufasApp extends StatelessWidget {
  const RufasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RuFaS',
      theme: AppTheme.light,
      home: const FarmListScreen(),
    );
  }
}
