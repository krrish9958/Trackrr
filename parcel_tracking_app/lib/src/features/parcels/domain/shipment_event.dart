import 'shipment.dart';

class ShipmentEvent {
  final String id;
  final String shipmentId;
  final String userId;
  final ShipmentStatus status;
  final String title;
  final String description;
  final String location;
  final DateTime occurredAt;

  const ShipmentEvent({
    required this.id,
    required this.shipmentId,
    required this.userId,
    required this.status,
    required this.title,
    required this.description,
    required this.location,
    required this.occurredAt,
  });
}

ShipmentEvent buildShipmentEvent({
  required String shipmentId,
  required String userId,
  required ShipmentStatus status,
  required String location,
  required DateTime occurredAt,
}) {
  final title = switch (status) {
    ShipmentStatus.pending => 'Shipment created',
    ShipmentStatus.inDelivery => 'Out for delivery',
    ShipmentStatus.complete => 'Shipment delivered',
    ShipmentStatus.failed => 'Delivery exception',
    ShipmentStatus.unknown => 'Shipment updated',
  };

  final description = switch (status) {
    ShipmentStatus.pending => 'Order registered and waiting for the next scan.',
    ShipmentStatus.inDelivery => 'Courier is heading to $location.',
    ShipmentStatus.complete => 'Shipment completed successfully in $location.',
    ShipmentStatus.failed => 'A delivery issue occurred near $location.',
    ShipmentStatus.unknown => 'Shipment status was updated.',
  };

  return ShipmentEvent(
    id: '',
    shipmentId: shipmentId,
    userId: userId,
    status: status,
    title: title,
    description: description,
    location: location,
    occurredAt: occurredAt,
  );
}
