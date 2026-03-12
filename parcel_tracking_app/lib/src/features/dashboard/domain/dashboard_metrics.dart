import 'package:intl/intl.dart';

import '../../parcels/domain/shipment.dart';

class DashboardMetrics {
  const DashboardMetrics({
    required this.total,
    required this.archived,
    required this.delivered,
    required this.failed,
    required this.inTransit,
    required this.deliveryRate,
    required this.failureRate,
    required this.deliveredToday,
    required this.failedShipments,
    required this.latestMovementLabel,
    required this.latestMovementSubtitle,
  });

  final int total;
  final int archived;
  final int delivered;
  final int failed;
  final int inTransit;
  final int deliveryRate;
  final int failureRate;
  final int deliveredToday;
  final List<Shipment> failedShipments;
  final String latestMovementLabel;
  final String latestMovementSubtitle;

  factory DashboardMetrics.fromShipments(
    List<Shipment> shipments, {
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final todayStart = DateTime(
      currentTime.year,
      currentTime.month,
      currentTime.day,
    );

    var delivered = 0;
    var archived = 0;
    var failed = 0;
    var inTransit = 0;
    var deliveredToday = 0;
    final failedShipments = <Shipment>[];

    for (final shipment in shipments) {
      if (shipment.isArchived) {
        archived++;
      }

      switch (shipment.normalizedStatus) {
        case ShipmentStatus.complete:
          delivered++;
          if (shipment.shippedAt.isAfter(todayStart)) {
            deliveredToday++;
          }
          break;
        case ShipmentStatus.failed:
          failed++;
          failedShipments.add(shipment);
          break;
        case ShipmentStatus.inDelivery:
          inTransit++;
          break;
        case ShipmentStatus.pending:
        case ShipmentStatus.unknown:
          break;
      }
    }

    final total = shipments.length;
    final deliveryRate = total == 0 ? 0 : ((delivered / total) * 100).round();
    final failureRate = total == 0 ? 0 : ((failed / total) * 100).round();
    final latestShipment = shipments.isEmpty ? null : shipments.first;

    return DashboardMetrics(
      total: total,
      archived: archived,
      delivered: delivered,
      failed: failed,
      inTransit: inTransit,
      deliveryRate: deliveryRate,
      failureRate: failureRate,
      deliveredToday: deliveredToday,
      failedShipments: failedShipments,
      latestMovementLabel: latestShipment == null
          ? 'No data'
          : DateFormat('dd MMM').format(latestShipment.shippedAt),
      latestMovementSubtitle: latestShipment == null
          ? 'Add a shipment to see activity'
          : 'Latest shipment at ${latestShipment.location}',
    );
  }
}
