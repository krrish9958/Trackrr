import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/app_scope.dart';
import '../../domain/dashboard_metrics.dart';
import '../../../parcels/data/firestore_shipments_repository.dart';
import '../../../parcels/domain/shipment.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;
    final ShipmentsRepository repository = AppScope.of(context).shipmentsRepository;

    final content = Row(
      children: [
        if (isWide)
          NavigationRail(
            selectedIndex: 0,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (index) {
              switch (index) {
                case 1:
                  context.go('/shipments');
                  break;
                case 2:
                  context.go('/alerts');
                  break;
              }
            },
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Overview'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.local_shipping_outlined),
                selectedIcon: Icon(Icons.local_shipping),
                label: Text('Parcels'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.notifications_none),
                selectedIcon: Icon(Icons.notifications),
                label: Text('Alerts'),
              ),
            ],
          ),
        Expanded(
          child: StreamBuilder<List<Shipment>>(
            stream: repository.watchCurrentUserShipments(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _LoadingFallbackState(
                  title: 'Loading dashboard',
                  message:
                      'If this is the first time on this phone, connect to the internet once so your shipments can sync.',
                  actionLabel: 'Open shipments',
                  onAction: () => context.go('/shipments'),
                );
              }

              if (snapshot.hasError) {
                debugPrint('DashboardPage stream error: ${snapshot.error}');
                return _DashboardErrorState(
                  onViewShipments: () => context.go('/shipments'),
                );
              }

              final shipments = snapshot.data ?? const <Shipment>[];
              final metrics = DashboardMetrics.fromShipments(shipments);
              final recentShipments = shipments.take(4).toList();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroPanel(
                      totalShipments: metrics.total,
                      archivedCount: metrics.archived,
                      deliveredCount: metrics.delivered,
                      onViewShipments: () => context.go('/shipments'),
                      onOpenArchived: () => context.push('/shipments/archived'),
                      onOpenAlerts: () => context.go('/alerts'),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _KpiCard(
                          title: 'Active Shipments',
                          value: '${metrics.total}',
                          subtitle:
                              '${metrics.inTransit} currently moving through the network',
                          color: const Color(0xFF2563EB),
                          icon: Icons.inventory_2_outlined,
                        ),
                        _KpiCard(
                          title: 'Archived',
                          value: '${metrics.archived}',
                          subtitle: 'Hidden from active shipment views',
                          color: const Color(0xFF6B7280),
                          icon: Icons.archive_outlined,
                        ),
                        _KpiCard(
                          title: 'Delivery Rate',
                          value: '${metrics.deliveryRate}%',
                          subtitle:
                              '${metrics.delivered} delivered successfully',
                          color: const Color(0xFF16A34A),
                          icon: Icons.check_circle_outline,
                        ),
                        _KpiCard(
                          title: 'Exceptions',
                          value: '${metrics.failed}',
                          subtitle:
                              '${metrics.failureRate}% of shipments need attention',
                          color: const Color(0xFFDC2626),
                          icon: Icons.error_outline,
                        ),
                        _KpiCard(
                          title: 'Recent Activity',
                          value: metrics.latestMovementLabel,
                          subtitle: metrics.latestMovementSubtitle,
                          color: const Color(0xFFF97316),
                          icon: Icons.schedule_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      crossAxisAlignment: WrapCrossAlignment.start,
                      children: [
                        SizedBox(
                          width: isWide ? 560 : double.infinity,
                          child: _RecentShipmentsCard(
                            shipments: recentShipments,
                            onViewAll: () => context.go('/shipments'),
                          ),
                        ),
                        SizedBox(
                          width: isWide ? 320 : double.infinity,
                          child: _AttentionCard(
                            delayedShipments: metrics.failedShipments,
                            inTransitCount: metrics.inTransit,
                            deliveredTodayCount: metrics.deliveredToday,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: isWide
          ? content
          : Column(
              children: [
                Expanded(child: content),
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _BottomNavIcon(
                        icon: Icons.home,
                        label: 'Home',
                        active: true,
                        onTap: () {},
                      ),
                      _BottomNavIcon(
                        icon: Icons.local_shipping_outlined,
                        label: 'Parcels',
                        active: false,
                        onTap: () => context.go('/shipments'),
                      ),
                      _BottomNavIcon(
                        icon: Icons.notifications_none,
                        label: 'Alerts',
                        active: false,
                        onTap: () => context.go('/alerts'),
                      ),
                      _BottomNavIcon(
                        icon: Icons.person_outline,
                        label: 'Profile',
                        active: false,
                        onTap: () => context.push('/profile'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.totalShipments,
    required this.archivedCount,
    required this.deliveredCount,
    required this.onViewShipments,
    required this.onOpenArchived,
    required this.onOpenAlerts,
  });

  final int totalShipments;
  final int archivedCount;
  final int deliveredCount;
  final VoidCallback onViewShipments;
  final VoidCallback onOpenArchived;
  final VoidCallback onOpenAlerts;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 24,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You are tracking $totalShipments shipment${totalShipments == 1 ? '' : 's'}, with $deliveredCount delivered and $archivedCount archived.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: onViewShipments,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0F172A),
                      ),
                      icon: const Icon(Icons.local_shipping_outlined),
                      label: const Text('Open Shipments'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onOpenArchived,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                      icon: const Icon(Icons.archive_outlined),
                      label: const Text('Archived'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onOpenAlerts,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                      icon: const Icon(Icons.notifications_none),
                      label: const Text('View Alerts'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.local_shipping_rounded,
              size: 56,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: color),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentShipmentsCard extends StatelessWidget {
  const _RecentShipmentsCard({
    required this.shipments,
    required this.onViewAll,
  });

  final List<Shipment> shipments;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Recent Shipments',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onViewAll,
                  child: const Text('View all'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (shipments.isEmpty)
              Text(
                'No shipments yet. Add your first shipment to start tracking.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              ...shipments.map(
                (shipment) => _RecentShipmentTile(shipment: shipment),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecentShipmentTile extends StatelessWidget {
  const _RecentShipmentTile({required this.shipment});

  final Shipment shipment;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColorFor(shipment.normalizedStatus);
    final shippedLabel = DateFormat('dd MMM yyyy').format(shipment.shippedAt);

    return InkWell(
      onTap: () => context.push('/shipments/${shipment.id}'),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.local_shipping_outlined,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shipment.trackingNumber,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${shipment.location} • $shippedLabel',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                shipment.normalizedStatus.label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.delayedShipments,
    required this.inTransitCount,
    required this.deliveredTodayCount,
  });

  final List<Shipment> delayedShipments;
  final int inTransitCount;
  final int deliveredTodayCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Needs Attention',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _AttentionStat(
              label: 'In transit',
              value: '$inTransitCount',
              color: const Color(0xFFF59E0B),
            ),
            const SizedBox(height: 12),
            _AttentionStat(
              label: 'Delivered today',
              value: '$deliveredTodayCount',
              color: const Color(0xFF16A34A),
            ),
            const SizedBox(height: 12),
            _AttentionStat(
              label: 'Exceptions',
              value: '${delayedShipments.length}',
              color: const Color(0xFFDC2626),
            ),
            const SizedBox(height: 16),
            if (delayedShipments.isEmpty)
              Text(
                'No failed shipments right now.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              ...delayedShipments.take(3).map(
                (shipment) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () => context.push('/shipments/${shipment.id}'),
                    borderRadius: BorderRadius.circular(12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Color(0xFFDC2626),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${shipment.trackingNumber} in ${shipment.location}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AttentionStat extends StatelessWidget {
  const _AttentionStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DashboardErrorState extends StatelessWidget {
  const _DashboardErrorState({required this.onViewShipments});

  final VoidCallback onViewShipments;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Failed to load dashboard data.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onViewShipments,
              child: const Text('Open shipments'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingFallbackState extends StatefulWidget {
  const _LoadingFallbackState({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  State<_LoadingFallbackState> createState() => _LoadingFallbackStateState();
}

class _LoadingFallbackStateState extends State<_LoadingFallbackState> {
  bool _showOfflineHint = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 8), () {
      if (mounted) {
        setState(() => _showOfflineHint = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_showOfflineHint) {
      return const Center(child: CircularProgressIndicator());
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: Color(0xFF6B7280),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: widget.onAction,
              child: Text(widget.actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

Color _statusColorFor(ShipmentStatus status) {
  return switch (status) {
    ShipmentStatus.complete => const Color(0xFF16A34A),
    ShipmentStatus.inDelivery => const Color(0xFFF59E0B),
    ShipmentStatus.pending => const Color(0xFF6B7280),
    ShipmentStatus.failed => const Color(0xFFDC2626),
    ShipmentStatus.unknown => const Color(0xFF2563EB),
  };
}

class _BottomNavIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _BottomNavIcon({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.black : Colors.black45;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
