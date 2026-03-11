import 'package:flutter/material.dart';
import 'routing/app_router.dart';
import 'theme/app_theme.dart';

class TrackrrApp extends StatelessWidget {
  const TrackrrApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = AppRouter().router;

    return MaterialApp.router(
      title: 'Trackrr - Parcel Tracking',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
