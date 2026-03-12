import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_tracking_app/src/features/dashboard/domain/dashboard_metrics.dart';
import 'package:parcel_tracking_app/src/features/parcels/domain/shipment.dart';

void main() {
  test('calculates dashboard metrics from shipments', () {
    final now = DateTime(2026, 3, 12, 10);
    final shipments = [
      Shipment(
        id: '1',
        trackingNumber: 'TRK-001',
        shippedAt: DateTime(2026, 3, 12, 8),
        location: 'Mumbai',
        status: ShipmentStatus.complete.value,
      ),
      Shipment(
        id: '2',
        trackingNumber: 'TRK-002',
        shippedAt: DateTime(2026, 3, 11, 18),
        location: 'Delhi',
        status: ShipmentStatus.failed.value,
      ),
      Shipment(
        id: '3',
        trackingNumber: 'TRK-003',
        shippedAt: DateTime(2026, 3, 10, 9),
        location: 'Pune',
        status: ShipmentStatus.inDelivery.value,
      ),
    ];

    final metrics = DashboardMetrics.fromShipments(shipments, now: now);

    expect(metrics.total, 3);
    expect(metrics.archived, 0);
    expect(metrics.delivered, 1);
    expect(metrics.failed, 1);
    expect(metrics.inTransit, 1);
    expect(metrics.deliveryRate, 33);
    expect(metrics.failureRate, 33);
    expect(metrics.deliveredToday, 1);
    expect(metrics.failedShipments.map((shipment) => shipment.id), ['2']);
    expect(metrics.latestMovementLabel, '12 Mar');
    expect(metrics.latestMovementSubtitle, 'Latest shipment at Mumbai');
  });

  test('returns empty-state metrics when shipments are missing', () {
    final metrics = DashboardMetrics.fromShipments(const [], now: DateTime(2026, 3, 12));

    expect(metrics.total, 0);
    expect(metrics.archived, 0);
    expect(metrics.deliveryRate, 0);
    expect(metrics.failureRate, 0);
    expect(metrics.latestMovementLabel, 'No data');
    expect(metrics.latestMovementSubtitle, 'Add a shipment to see activity');
  });
}
