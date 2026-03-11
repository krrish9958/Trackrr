import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/pages/login_page.dart';
import '../features/dashboard/presentation/pages/dashboard_page.dart';
import '../features/parcels/presentation/pages/add_shipment_page.dart';
import '../features/parcels/presentation/pages/edit_shipment_page.dart';
import '../features/parcels/presentation/pages/shipment_list_page.dart';
import '../features/parcels/presentation/pages/shipment_detail_page.dart';
import '../features/alerts/presentation/pages/alerts_page.dart';
import '../features/profile/presentation/pages/profile_page.dart';

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class AppRouter {
  AppRouter();

  GoRouter get router => _router;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  late final GoRouter _router = GoRouter(
    initialLocation: '/login',
    refreshListenable: GoRouterRefreshStream(
      FirebaseAuth.instance.authStateChanges(),
    ),
    redirect: (context, state) {
      final bool isLoggedIn = _auth.currentUser != null;
      final bool isLoggingIn = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoggingIn) {
        return '/login';
      }

      if (isLoggedIn && isLoggingIn) {
        return '/dashboard';
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) => const MaterialPage(child: LoginPage()),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        pageBuilder: (context, state) =>
            const MaterialPage(child: DashboardPage()),
      ),
      GoRoute(
        path: '/shipments',
        name: 'shipments',
        pageBuilder: (context, state) =>
            const MaterialPage(child: ShipmentListPage()),
        routes: [
          GoRoute(
            path: 'add',
            name: 'add-shipment',
            pageBuilder: (context, state) =>
                const MaterialPage(child: AddShipmentPage()),
          ),
          GoRoute(
            path: ':id',
            name: 'shipment-detail',
            pageBuilder: (context, state) {
              // go_router 17 uses `pathParameters`
              final id = state.pathParameters['id']!;
              return MaterialPage(child: ShipmentDetailPage(shipmentId: id));
            },
            routes: [
              GoRoute(
                path: 'edit',
                name: 'edit-shipment',
                pageBuilder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return MaterialPage(child: EditShipmentPage(shipmentId: id));
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/alerts',
        name: 'alerts',
        pageBuilder: (context, state) =>
            const MaterialPage(child: AlertsPage()),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        pageBuilder: (context, state) =>
            const MaterialPage(child: ProfilePage()),
      ),
    ],
  );
}
