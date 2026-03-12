import 'package:flutter/material.dart';

import 'core/app_scope.dart';
import 'core/app_services.dart';
import 'routing/app_router.dart';
import 'theme/app_theme.dart';

class TrackrrApp extends StatelessWidget {
  const TrackrrApp({
    super.key,
    required this.services,
  });

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final router = AppRouter(auth: services.auth).router;

    return AppScope(
      services: services,
      child: MaterialApp.router(
        title: 'Trackrr - Parcel Tracking',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    );
  }
}
