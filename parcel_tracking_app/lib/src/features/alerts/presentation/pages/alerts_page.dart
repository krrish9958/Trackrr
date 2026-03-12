import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/app_scope.dart';
import '../../data/firestore_alerts_repository.dart';
import '../../domain/alert.dart';

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  bool _isMarkingAllRead = false;
  bool _hasBackfilled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasBackfilled) {
      return;
    }

    _hasBackfilled = true;
    AppScope.of(context).alertsRepository.backfillAlertsFromEvents().catchError((_) {});
  }

  void _handleBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }

    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final repository = AppScope.of(context).alertsRepository;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text('Alerts'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _handleBack(context),
        ),
        actions: [
          TextButton(
            onPressed: _isMarkingAllRead ? null : () => _markAllAsRead(repository),
            child: Text(_isMarkingAllRead ? 'Working...' : 'Mark all read'),
          ),
        ],
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
          final unreadCount = alerts.where((alert) => !alert.isRead).length;

          if (alerts.isEmpty) {
            return Center(
              child: Text(
                'No alerts at the moment.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }

          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.notifications_active_outlined,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$unreadCount unread alert${unreadCount == 1 ? '' : 's'}',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Shipment updates stay unread until opened.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: alerts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final alert = alerts[index];
                    final timeLabel = DateFormat('MMM d, h:mm a').format(alert.createdAt);

                    return Card(
                      elevation: alert.isRead ? 0 : 2,
                      color: alert.isRead ? Colors.white : const Color(0xFFF8FBFF),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _openAlert(repository, alert),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _alertAccent(alert.kind).withValues(
                                    alpha: alert.isRead ? 0.08 : 0.16,
                                  ),
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
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            alert.title,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight: alert.isRead
                                                      ? FontWeight.w600
                                                      : FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                        if (!alert.isRead)
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF2563EB),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
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
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium
                                              ?.copyWith(color: Colors.black54),
                                        ),
                                        if (alert.shipmentId != null) ...[
                                          const SizedBox(width: 12),
                                          Text(
                                            'Open shipment',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelMedium
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
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
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openAlert(
    FirestoreAlertsRepository repository,
    AlertItem alert,
  ) async {
    if (!alert.isRead) {
      try {
        await repository.markAlertAsRead(alert.id);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update alert: $e')),
        );
      }
    }

    if (!mounted || alert.shipmentId == null) {
      return;
    }

    context.push('/shipments/${alert.shipmentId}');
  }

  Future<void> _markAllAsRead(FirestoreAlertsRepository repository) async {
    setState(() => _isMarkingAllRead = true);
    try {
      await repository.markAllAlertsAsRead();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark alerts as read: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isMarkingAllRead = false);
      }
    }
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
