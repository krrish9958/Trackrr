import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/firestore_alerts_repository.dart';
import '../../domain/alert.dart';

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  void _handleBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }

    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final repository = FirestoreAlertsRepository();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text('Alerts'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _handleBack(context),
        ),
      ),
      body: StreamBuilder<List<AlertItem>>(
        stream: repository.watchCurrentUserAlerts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            debugPrint('AlertsPage stream error: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Failed to load alerts.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _handleBack(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          final alerts = snapshot.data ?? const [];
          if (alerts.isEmpty) {
            return Center(
              child: Text(
                'No alerts at the moment.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: alerts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final alert = alerts[index];
              final timeLabel = DateFormat('MMM d, h:mm a').format(alert.createdAt);

              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: alert.shipmentId == null
                      ? null
                      : () => context.push('/shipments/${alert.shipmentId}'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _alertAccent(alert.kind).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _alertIcon(alert.kind),
                            color: _alertAccent(alert.kind),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                alert.title,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                alert.message,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    timeLabel,
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: Colors.black54,
                                    ),
                                  ),
                                  if (alert.shipmentId != null) ...[
                                    const SizedBox(width: 12),
                                    Text(
                                      'Open shipment',
                                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

IconData _alertIcon(AlertKind kind) {
  return switch (kind) {
    AlertKind.success => Icons.check_circle_outline,
    AlertKind.error => Icons.error_outline,
    AlertKind.warning => Icons.warning_amber_rounded,
    AlertKind.info => Icons.notifications_none,
  };
}

Color _alertAccent(AlertKind kind) {
  return switch (kind) {
    AlertKind.success => const Color(0xFF16A34A),
    AlertKind.error => const Color(0xFFDC2626),
    AlertKind.warning => const Color(0xFFF59E0B),
    AlertKind.info => const Color(0xFF2563EB),
  };
}
