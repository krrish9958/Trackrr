import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_tracking_app/src/features/alerts/data/firestore_alerts_repository.dart';
import 'package:parcel_tracking_app/src/features/parcels/data/firestore_shipments_repository.dart';
import 'package:parcel_tracking_app/src/features/parcels/domain/shipment.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late FirestoreShipmentsRepository shipmentsRepository;
  late FirestoreAlertsRepository alertsRepository;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'user-1', email: 'test@example.com'),
    );
    shipmentsRepository = FirestoreShipmentsRepository(
      firestore: firestore,
      auth: auth,
    );
    alertsRepository = FirestoreAlertsRepository(
      firestore: firestore,
      auth: auth,
    );
  });

  test('addShipment creates shipment, initial event, and unread alert', () async {
    final shipment = Shipment(
      id: '',
      trackingNumber: 'TRK-100',
      shippedAt: DateTime(2026, 3, 12, 9),
      location: 'Mumbai',
      status: ShipmentStatus.pending.value,
    );

    final shipmentId = await shipmentsRepository.addShipment(shipment);

    final shipmentDoc = await firestore
        .collection('users')
        .doc('user-1')
        .collection('shipments')
        .doc(shipmentId)
        .get();
    final eventDocs = await firestore
        .collection('users')
        .doc('user-1')
        .collection('shipments')
        .doc(shipmentId)
        .collection('events')
        .get();
    final alerts = await alertsRepository.watchCurrentUserAlerts().first;

    expect(shipmentDoc.exists, isTrue);
    expect(shipmentDoc.data()?['trackingNumber'], 'TRK-100');
    expect(eventDocs.docs, hasLength(1));
    expect(eventDocs.docs.first.data()['shipmentId'], shipmentId);
    expect(alerts, hasLength(1));
    expect(alerts.first.shipmentId, shipmentId);
    expect(alerts.first.isRead, isFalse);
  });

  test('addShipmentEvent updates shipment and creates event plus alert', () async {
    final shipmentId = await shipmentsRepository.addShipment(
      Shipment(
        id: '',
        trackingNumber: 'TRK-200',
        shippedAt: DateTime(2026, 3, 10, 12),
        location: 'Delhi',
        status: ShipmentStatus.pending.value,
      ),
    );

    final originalShipment = Shipment(
      id: shipmentId,
      trackingNumber: 'TRK-200',
      shippedAt: DateTime(2026, 3, 10, 12),
      location: 'Delhi',
      status: ShipmentStatus.pending.value,
    );

    await shipmentsRepository.addShipmentEvent(
      shipment: originalShipment,
      status: ShipmentStatus.inDelivery,
      title: 'Reached local hub',
      description: 'Shipment scanned at the local distribution hub.',
      location: 'Pune',
      occurredAt: DateTime(2026, 3, 11, 15),
    );

    final shipmentDoc = await firestore
        .collection('users')
        .doc('user-1')
        .collection('shipments')
        .doc(shipmentId)
        .get();
    final eventDocs = await firestore
        .collection('users')
        .doc('user-1')
        .collection('shipments')
        .doc(shipmentId)
        .collection('events')
        .orderBy('occurredAt', descending: true)
        .get();
    final alerts = await alertsRepository.watchCurrentUserAlerts().first;

    expect(shipmentDoc.data()?['location'], 'Pune');
    expect(shipmentDoc.data()?['status'], ShipmentStatus.inDelivery.value);
    expect(eventDocs.docs, hasLength(2));
    expect(eventDocs.docs.first.data()['title'], 'Reached local hub');
    expect(alerts, hasLength(2));
    expect(alerts.first.title, 'Reached local hub');
    expect(alerts.first.isRead, isFalse);
  });

  test('deleteShipment removes shipment events and related alerts', () async {
    final shipmentId = await shipmentsRepository.addShipment(
      Shipment(
        id: '',
        trackingNumber: 'TRK-300',
        shippedAt: DateTime(2026, 3, 9, 8),
        location: 'Bengaluru',
        status: ShipmentStatus.pending.value,
      ),
    );

    final shipment = Shipment(
      id: shipmentId,
      trackingNumber: 'TRK-300',
      shippedAt: DateTime(2026, 3, 9, 8),
      location: 'Bengaluru',
      status: ShipmentStatus.pending.value,
    );

    await shipmentsRepository.addShipmentEvent(
      shipment: shipment,
      status: ShipmentStatus.failed,
      title: 'Delivery exception',
      description: 'Recipient unavailable.',
      location: 'Bengaluru',
    );

    await shipmentsRepository.deleteShipment(shipmentId);

    final shipmentDoc = await firestore
        .collection('users')
        .doc('user-1')
        .collection('shipments')
        .doc(shipmentId)
        .get();
    final eventDocs = await firestore
        .collection('users')
        .doc('user-1')
        .collection('shipments')
        .doc(shipmentId)
        .collection('events')
        .get();
    final alerts = await alertsRepository.watchCurrentUserAlerts().first;

    expect(shipmentDoc.exists, isFalse);
    expect(eventDocs.docs, isEmpty);
    expect(alerts, isEmpty);
  });

  test('deleteShipment permanently removes an archived shipment', () async {
    final shipmentId = await shipmentsRepository.addShipment(
      Shipment(
        id: '',
        trackingNumber: 'TRK-301',
        shippedAt: DateTime(2026, 3, 9, 8),
        location: 'Kolkata',
        status: ShipmentStatus.pending.value,
      ),
    );

    await shipmentsRepository.archiveShipment(shipmentId);
    await shipmentsRepository.deleteShipment(shipmentId);

    final archivedShipments = await shipmentsRepository.watchArchivedShipments().first;
    final shipmentDoc = await firestore
        .collection('users')
        .doc('user-1')
        .collection('shipments')
        .doc(shipmentId)
        .get();

    expect(archivedShipments.where((shipment) => shipment.id == shipmentId), isEmpty);
    expect(shipmentDoc.exists, isFalse);
  });

  test('archiveShipment hides shipment from active lists without deleting history', () async {
    final shipmentId = await shipmentsRepository.addShipment(
      Shipment(
        id: '',
        trackingNumber: 'TRK-350',
        shippedAt: DateTime(2026, 3, 9, 8),
        location: 'Chennai',
        status: ShipmentStatus.pending.value,
      ),
    );

    await shipmentsRepository.archiveShipment(shipmentId);

    final activeShipments = await shipmentsRepository.watchCurrentUserShipments().first;
    final shipmentDoc = await firestore
        .collection('users')
        .doc('user-1')
        .collection('shipments')
        .doc(shipmentId)
        .get();
    final eventDocs = await firestore
        .collection('users')
        .doc('user-1')
        .collection('shipments')
        .doc(shipmentId)
        .collection('events')
        .get();

    expect(activeShipments.where((item) => item.id == shipmentId), isEmpty);
    expect(shipmentDoc.exists, isTrue);
    expect(shipmentDoc.data()?['isArchived'], isTrue);
    expect(eventDocs.docs, hasLength(1));
  });

  test('restoreShipment moves shipment back into active lists', () async {
    final shipmentId = await shipmentsRepository.addShipment(
      Shipment(
        id: '',
        trackingNumber: 'TRK-360',
        shippedAt: DateTime(2026, 3, 9, 8),
        location: 'Hyderabad',
        status: ShipmentStatus.pending.value,
      ),
    );

    await shipmentsRepository.archiveShipment(shipmentId);
    await shipmentsRepository.restoreShipment(shipmentId);

    final activeShipments = await shipmentsRepository.watchCurrentUserShipments().first;
    final archivedShipments = await shipmentsRepository.watchArchivedShipments().first;
    final shipmentDoc = await firestore
        .collection('users')
        .doc('user-1')
        .collection('shipments')
        .doc(shipmentId)
        .get();

    expect(activeShipments.map((shipment) => shipment.id), contains(shipmentId));
    expect(archivedShipments.where((shipment) => shipment.id == shipmentId), isEmpty);
    expect(shipmentDoc.data()?['isArchived'], isFalse);
    expect(shipmentDoc.data()?['archivedAt'], isNull);
  });

  test('rejects invalid shipment event payloads before writing', () async {
    final shipmentId = await shipmentsRepository.addShipment(
      Shipment(
        id: '',
        trackingNumber: 'TRK-400',
        shippedAt: DateTime(2026, 3, 9, 8),
        location: 'Jaipur',
        status: ShipmentStatus.pending.value,
      ),
    );

    final shipment = Shipment(
      id: shipmentId,
      trackingNumber: 'TRK-400',
      shippedAt: DateTime(2026, 3, 9, 8),
      location: 'Jaipur',
      status: ShipmentStatus.pending.value,
    );

    await expectLater(
      () => shipmentsRepository.addShipmentEvent(
        shipment: shipment,
        status: ShipmentStatus.inDelivery,
        title: '   ',
        description: 'Valid description',
        location: 'Jaipur',
      ),
      throwsArgumentError,
    );
  });
}
