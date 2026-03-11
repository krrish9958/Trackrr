import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../parcels/data/firestore_shipments_repository.dart';
import '../../../parcels/domain/shipment.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;
    final repository = FirestoreShipmentsRepository();

    final content = Row(
      children: [
        if (isWide)
          NavigationRail(
            selectedIndex: 0,
            labelType: NavigationRailLabelType.all,
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
                icon: Icon(Icons.analytics_outlined),
                selectedIcon: Icon(Icons.analytics),
                label: Text('Analytics'),
              ),
            ],
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back 👋',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Here is an overview of your logistics activity.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                StreamBuilder<List<Shipment>>(
                  stream: repository.watchCurrentUserShipments(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      debugPrint(
                        'DashboardPage: StreamBuilder error: ${snapshot.error}',
                      );
                      // If Firestore errors or returns null, just treat as zero stats
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _StatCard(
                            title: 'Active Shipments',
                            value: '0',
                            color: const Color(0xFF2563EB),
                          ),
                          _StatCard(
                            title: 'Delivered',
                            value: '0',
                            color: const Color(0xFF16A34A),
                          ),
                          _StatCard(
                            title: 'Failed',
                            value: '0',
                            color: const Color(0xFFDC2626),
                          ),
                          _StatCard(
                            title: 'Out for Delivery',
                            value: '0',
                            color: const Color(0xFFF97316),
                          ),
                        ],
                      );
                    }

                    final shipments = snapshot.data ?? const <Shipment>[];

                    int total = shipments.length;
                    int delivered = 0;
                    int failed = 0;
                    int outForDelivery = 0;

                    for (final s in shipments) {
                      final status = s.normalizedStatus;
                      if (status.isDelivered) {
                        delivered++;
                      } else if (status.isFailed) {
                        failed++;
                      } else if (status.isOutForDelivery) {
                        outForDelivery++;
                      }
                    }

                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _StatCard(
                          title: 'Active Shipments',
                          value: '$total',
                          color: const Color(0xFF2563EB),
                        ),
                        _StatCard(
                          title: 'Delivered',
                          value: '$delivered',
                          color: const Color(0xFF16A34A),
                        ),
                        _StatCard(
                          title: 'Failed',
                          value: '$failed',
                          color: const Color(0xFFDC2626),
                        ),
                        _StatCard(
                          title: 'Out for Delivery',
                          value: '$outForDelivery',
                          color: const Color(0xFFF97316),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () {
                    context.push('/shipments');
                  },
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text('View Shipping Records'),
                ),
              ],
            ),
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

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
