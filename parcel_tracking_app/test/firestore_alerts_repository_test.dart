import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_tracking_app/src/features/alerts/data/firestore_alerts_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late FirestoreAlertsRepository alertsRepository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'user-1', email: 'test@example.com'),
    );
    alertsRepository = FirestoreAlertsRepository(
      firestore: firestore,
      auth: auth,
    );
  });

  Future<void> seedAlert(String id, {required bool isRead}) {
    return firestore
        .collection('users')
        .doc('user-1')
        .collection('alerts')
        .doc(id)
        .set({
          'shipmentId': 'shipment-1',
          'eventId': 'event-$id',
          'title': 'Shipment update $id',
          'description': 'Description $id',
          'kind': 'info',
          'isRead': isRead,
          'createdAt': DateTime(2026, 3, 12, 10),
        });
  }

  test('markAlertAsRead updates one alert only', () async {
    await seedAlert('a1', isRead: false);
    await seedAlert('a2', isRead: false);

    await alertsRepository.markAlertAsRead('a1');

    final alerts = await alertsRepository.watchCurrentUserAlerts().first;
    final first = alerts.firstWhere((alert) => alert.id == 'a1');
    final second = alerts.firstWhere((alert) => alert.id == 'a2');

    expect(first.isRead, isTrue);
    expect(second.isRead, isFalse);
  });

  test('markAllAlertsAsRead updates all unread alerts', () async {
    await seedAlert('a1', isRead: false);
    await seedAlert('a2', isRead: true);
    await seedAlert('a3', isRead: false);

    await alertsRepository.markAllAlertsAsRead();

    final alerts = await alertsRepository.watchCurrentUserAlerts().first;
    expect(alerts.every((alert) => alert.isRead), isTrue);
  });

  test('backfillAlertsFromEvents is idempotent for the same event id', () async {
    await firestore
        .collection('users')
        .doc('user-1')
        .collection('shipments')
        .doc('shipment-1')
        .collection('events')
        .doc('event-1')
        .set({
          'userId': 'user-1',
          'shipmentId': 'shipment-1',
          'status': 'pending',
          'title': 'Shipment created',
          'description': 'Registered',
          'location': 'Delhi',
          'occurredAt': DateTime(2026, 3, 12, 10),
        });

    await alertsRepository.backfillAlertsFromEvents();
    await alertsRepository.backfillAlertsFromEvents();

    final alertsSnapshot = await firestore
        .collection('users')
        .doc('user-1')
        .collection('alerts')
        .get();

    expect(alertsSnapshot.docs, hasLength(1));
    expect(alertsSnapshot.docs.single.id, 'event-1');
  });
}
