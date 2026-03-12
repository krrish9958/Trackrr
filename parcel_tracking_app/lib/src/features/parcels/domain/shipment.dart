enum ShipmentStatus {
  pending('pending', 'Pending'),
  inDelivery('in_delivery', 'In Delivery'),
  complete('complete', 'Complete'),
  failed('failed', 'Failed'),
  unknown('unknown', 'Unknown');

  const ShipmentStatus(this.value, this.label);

  final String value;
  final String label;

  bool get isDelivered => this == ShipmentStatus.complete;
  bool get isOutForDelivery => this == ShipmentStatus.inDelivery;
  bool get isFailed => this == ShipmentStatus.failed;
  bool get isKnown => this != ShipmentStatus.unknown;

  static ShipmentStatus fromRaw(String? rawStatus) {
    final normalized = rawStatus?.trim().toLowerCase() ?? '';

    return switch (normalized) {
      'pending' => ShipmentStatus.pending,
      'in_delivery' || 'in delivery' => ShipmentStatus.inDelivery,
      'complete' || 'completed' || 'delivered' => ShipmentStatus.complete,
      'failed' || 'cancelled' || 'canceled' => ShipmentStatus.failed,
      _ => ShipmentStatus.unknown,
    };
  }
}

class Shipment {
  final String id;
  final String trackingNumber;
  final DateTime shippedAt;
  final String location;
  final String status;
  final bool isArchived;

  const Shipment({
    required this.id,
    required this.trackingNumber,
    required this.shippedAt,
    required this.location,
    required this.status,
    this.isArchived = false,
  });

  ShipmentStatus get normalizedStatus => ShipmentStatus.fromRaw(status);
}

