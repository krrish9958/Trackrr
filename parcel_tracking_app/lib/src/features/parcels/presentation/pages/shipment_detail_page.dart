import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/firestore_shipments_repository.dart';
import '../../domain/shipment.dart';
import '../../domain/shipment_event.dart';

class ShipmentDetailPage extends StatelessWidget {
  final String shipmentId;

  const ShipmentDetailPage({super.key, required this.shipmentId});

  @override
  Widget build(BuildContext context) {
    final repository = FirestoreShipmentsRepository();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text('Track Shipment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go('/shipments');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/shipments/$shipmentId/edit'),
          ),
        ],
      ),
      body: StreamBuilder<Shipment?>(
        stream: repository.watchShipment(shipmentId),
        builder: (context, shipmentSnapshot) {
          if (shipmentSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (shipmentSnapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load shipment.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }

          final shipment = shipmentSnapshot.data;
          if (shipment == null) {
            return Center(
              child: Text(
                'Shipment not found.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }

          return StreamBuilder<List<ShipmentEvent>>(
            stream: repository.watchShipmentEvents(shipmentId),
            builder: (context, eventsSnapshot) {
              if (eventsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (eventsSnapshot.hasError) {
                return Center(
                  child: Text(
                    'Failed to load shipment history.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                );
              }

              final events = eventsSnapshot.data ?? const <ShipmentEvent>[];
              final latestEvent = events.isNotEmpty ? events.first : null;
              final shippedAtLabel = DateFormat('dd MMM yyyy, HH:mm').format(shipment.shippedAt);
              final progressValue = _progressValueFor(shipment.normalizedStatus);

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _StatusSummaryCard(
                    trackingNumber: shipment.trackingNumber,
                    statusLabel: shipment.normalizedStatus.label,
                    statusColor: _statusColorFor(shipment.normalizedStatus),
                    progressValue: progressValue,
                    location: shipment.location,
                    shippedAtLabel: shippedAtLabel,
                  ),
                  const SizedBox(height: 16),
                  _CurrentCheckpointCard(
                    title: latestEvent?.title ?? 'Shipment created',
                    description: latestEvent?.description ??
                        'Shipment is waiting for the next status update.',
                    statusLabel: shipment.normalizedStatus.label,
                    statusColor: _statusColorFor(shipment.normalizedStatus),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tracking Timeline',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (events.isEmpty)
                            Text(
                              'No tracking events yet.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            )
                          else
                            ...List.generate(
                              events.length,
                              (index) => _TimelineTile(
                                event: events[index],
                                accentColor: _statusColorFor(events[index].status),
                                isLast: index == events.length - 1,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Shipment Details',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              _DetailStat(label: 'Shipment ID', value: shipment.id),
                              _DetailStat(
                                label: 'Tracking Number',
                                value: shipment.trackingNumber,
                              ),
                              _DetailStat(
                                label: 'Current Location',
                                value: shipment.location,
                              ),
                              _DetailStat(
                                label: 'Status',
                                value: shipment.normalizedStatus.label,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _StatusSummaryCard extends StatelessWidget {
  final String trackingNumber;
  final String statusLabel;
  final Color statusColor;
  final double progressValue;
  final String location;
  final String shippedAtLabel;

  const _StatusSummaryCard({
    required this.trackingNumber,
    required this.statusLabel,
    required this.statusColor,
    required this.progressValue,
    required this.location,
    required this.shippedAtLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF1F2937)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tracking Number',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      trackingNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: progressValue,
            minHeight: 8,
            color: statusColor,
            backgroundColor: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _SummaryMeta(
                icon: Icons.pin_drop_outlined,
                label: 'Current checkpoint',
                value: location,
              ),
              _SummaryMeta(
                icon: Icons.schedule_outlined,
                label: 'Shipped at',
                value: shippedAtLabel,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMeta extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryMeta({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.white70),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white60,
              ),
            ),
            SizedBox(
              width: 160,
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CurrentCheckpointCard extends StatelessWidget {
  final String title;
  final String description;
  final String statusLabel;
  final Color statusColor;

  const _CurrentCheckpointCard({
    required this.title,
    required this.description,
    required this.statusLabel,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.route_outlined, color: statusColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final ShipmentEvent event;
  final Color accentColor;
  final bool isLast;

  const _TimelineTile({
    required this.event,
    required this.accentColor,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final timeLabel = DateFormat('dd MMM, HH:mm').format(event.occurredAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 48,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  color: accentColor.withOpacity(0.3),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  event.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  timeLabel,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  final String label;
  final String value;

  const _DetailStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

double _progressValueFor(ShipmentStatus status) {
  return switch (status) {
    ShipmentStatus.pending => 0.25,
    ShipmentStatus.inDelivery => 0.7,
    ShipmentStatus.complete => 1.0,
    ShipmentStatus.failed => 1.0,
    ShipmentStatus.unknown => 0.15,
  };
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
