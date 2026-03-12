import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../alerts/domain/alert.dart';
import '../domain/shipment.dart';
import '../domain/shipment_event.dart';

abstract class ShipmentsRepository {
  Stream<List<Shipment>> watchCurrentUserShipments();
  Stream<List<Shipment>> watchArchivedShipments();
  Future<String> addShipment(Shipment shipment);
  Future<void> updateShipment({
    required Shipment previous,
    required Shipment updated,
  });
  Future<void> archiveShipment(String shipmentId);
  Future<void> restoreShipment(String shipmentId);
  Future<void> deleteShipment(String shipmentId);
  Future<void> addShipmentEvent({
    required Shipment shipment,
    required ShipmentStatus status,
    required String title,
    required String description,
    required String location,
    DateTime? occurredAt,
  });
  Stream<Shipment?> watchShipment(String id);
  Stream<List<ShipmentEvent>> watchShipmentEvents(String shipmentId);
}

class FirestoreShipmentsRepository implements ShipmentsRepository {
  FirestoreShipmentsRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  @override
  Future<String> addShipment(Shipment shipment) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No user logged in.');
    }

    final trackingNumber = _requireNonEmpty(
      shipment.trackingNumber,
      fieldName: 'trackingNumber',
    );
    final location = _requireNonEmpty(shipment.location, fieldName: 'location');
    final status = _normalizeStatus(shipment.normalizedStatus);
    final shipmentRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('shipments')
        .doc();
    final event = buildShipmentEvent(
      shipmentId: shipmentRef.id,
      userId: user.uid,
      status: status,
      location: location,
      occurredAt: shipment.shippedAt,
    );
    final batch = _firestore.batch();

    batch.set(shipmentRef, {
      'trackingNumber': trackingNumber,
      'shippedAt': Timestamp.fromDate(shipment.shippedAt),
      'location': location,
      'status': status.value,
      'isArchived': false,
    });
    _queueShipmentEventWrite(batch: batch, shipmentId: shipmentRef.id, event: event);
    await batch.commit();

    return shipmentRef.id;
  }

  @override
  Future<void> updateShipment({
    required Shipment previous,
    required Shipment updated,
  }) async {
    final user = _auth.currentUser;
    if (user == null || updated.id.isEmpty) {
      throw StateError('No user logged in.');
    }

    final trackingNumber = _requireNonEmpty(
      updated.trackingNumber,
      fieldName: 'trackingNumber',
    );
    final location = _requireNonEmpty(updated.location, fieldName: 'location');
    final status = _normalizeStatus(updated.normalizedStatus);
    final shipmentRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('shipments')
        .doc(updated.id);

    final batch = _firestore.batch();

    batch.update(shipmentRef, {
      'trackingNumber': trackingNumber,
      'location': location,
      'status': status.value,
    });

    final didStatusChange = previous.normalizedStatus != status;
    final didLocationChange = previous.location.trim() != location;

    if (didStatusChange || didLocationChange) {
      _queueShipmentEventWrite(
        batch: batch,
        shipmentId: updated.id,
        event: buildShipmentEvent(
          shipmentId: updated.id,
          userId: user.uid,
          status: status,
          location: location,
          occurredAt: DateTime.now(),
        ),
      );
    }

    await batch.commit();
  }

  @override
  Future<void> deleteShipment(String shipmentId) async {
    final user = _auth.currentUser;
    if (user == null || shipmentId.isEmpty) {
      throw StateError('No user logged in.');
    }

    final shipmentRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('shipments')
        .doc(shipmentId);

    final eventsSnapshot = await shipmentRef.collection('events').get();
    final alertsSnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('alerts')
        .where('shipmentId', isEqualTo: shipmentId)
        .get();
    final batch = _firestore.batch();

    for (final eventDoc in eventsSnapshot.docs) {
      batch.delete(eventDoc.reference);
    }
    for (final alertDoc in alertsSnapshot.docs) {
      batch.delete(alertDoc.reference);
    }

    batch.delete(shipmentRef);
    await batch.commit();
  }

  @override
  Future<void> archiveShipment(String shipmentId) async {
    final user = _auth.currentUser;
    if (user == null || shipmentId.isEmpty) {
      throw StateError('No user logged in.');
    }

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('shipments')
        .doc(shipmentId)
        .update({
          'isArchived': true,
          'archivedAt': Timestamp.now(),
        });
  }

  @override
  Future<void> restoreShipment(String shipmentId) async {
    final user = _auth.currentUser;
    if (user == null || shipmentId.isEmpty) {
      throw StateError('No user logged in.');
    }

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('shipments')
        .doc(shipmentId)
        .update({
          'isArchived': false,
          'archivedAt': FieldValue.delete(),
        });
  }

  @override
  Future<void> addShipmentEvent({
    required Shipment shipment,
    required ShipmentStatus status,
    required String title,
    required String description,
    required String location,
    DateTime? occurredAt,
  }) async {
    final user = _auth.currentUser;
    if (user == null || shipment.id.isEmpty) {
      throw StateError('No user logged in.');
    }

    final normalizedStatus = _normalizeStatus(status);
    final normalizedTitle = _requireNonEmpty(title, fieldName: 'title');
    final normalizedDescription = _requireNonEmpty(
      description,
      fieldName: 'description',
    );
    final normalizedLocation = _requireNonEmpty(location, fieldName: 'location');

    final shipmentRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('shipments')
        .doc(shipment.id);

    final batch = _firestore.batch();
    batch.update(shipmentRef, {
      'location': normalizedLocation,
      'status': normalizedStatus.value,
    });

    _queueShipmentEventWrite(
      batch: batch,
      shipmentId: shipment.id,
      event: ShipmentEvent(
        id: '',
        shipmentId: shipment.id,
        userId: user.uid,
        status: normalizedStatus,
        title: normalizedTitle,
        description: normalizedDescription,
        location: normalizedLocation,
        occurredAt: occurredAt ?? DateTime.now(),
      ),
    );
    await batch.commit();
  }

  @override
  Stream<List<Shipment>> watchCurrentUserShipments() {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('FirestoreShipmentsRepository: No user logged in.');
      return Stream.value(const <Shipment>[]);
    }

    final ref = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('shipments')
        .where('isArchived', isEqualTo: false)
        .orderBy('shippedAt', descending: true);

    return ref
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_fromDoc).toList())
        .handleError((error) {
          debugPrint(
            'FirestoreShipmentsRepository: Error fetching shipments: $error',
          );
        });
  }

  @override
  Stream<List<Shipment>> watchArchivedShipments() {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('FirestoreShipmentsRepository: No user logged in.');
      return Stream.value(const <Shipment>[]);
    }

    final ref = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('shipments')
        .where('isArchived', isEqualTo: true)
        .orderBy('shippedAt', descending: true);

    return ref
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_fromDoc).toList())
        .handleError((error) {
          debugPrint(
            'FirestoreShipmentsRepository: Error fetching archived shipments: $error',
          );
        });
  }

  @override
  Stream<Shipment?> watchShipment(String id) {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint(
        'FirestoreShipmentsRepository.watchShipment: No user logged in.',
      );
      return const Stream<Shipment?>.empty();
    }

    final docRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('shipments')
        .doc(id);

    return docRef
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return null;
          return _fromSnapshot(snapshot);
        })
        .handleError((error) {
          debugPrint(
            'FirestoreShipmentsRepository: Error fetching shipment $id: $error',
          );
          return null;
        });
  }

  @override
  Stream<List<ShipmentEvent>> watchShipmentEvents(String shipmentId) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream<List<ShipmentEvent>>.empty();
    }

    final ref = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('shipments')
        .doc(shipmentId)
        .collection('events')
        .orderBy('occurredAt', descending: true);

    return ref.snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => _eventFromDoc(doc, shipmentId)).toList(),
    );
  }

  void _queueShipmentEventWrite({
    required WriteBatch batch,
    required String shipmentId,
    required ShipmentEvent event,
  }) {
    final eventRef = _firestore
        .collection('users')
        .doc(event.userId)
        .collection('shipments')
        .doc(shipmentId)
        .collection('events')
        .doc();
    final alertRef = _firestore
        .collection('users')
        .doc(event.userId)
        .collection('alerts')
        .doc(eventRef.id);

    batch.set(eventRef, {
      'userId': event.userId,
      'shipmentId': event.shipmentId,
      'status': event.status.value,
      'title': event.title,
      'description': event.description,
      'location': event.location,
      'occurredAt': Timestamp.fromDate(event.occurredAt),
    });
    batch.set(alertRef, {
          'shipmentId': event.shipmentId,
          'eventId': eventRef.id,
          'title': event.title,
          'description': event.description,
          'kind': _alertKindFor(event.status).name,
          'isRead': false,
          'createdAt': Timestamp.fromDate(event.occurredAt),
        });
  }

  Shipment _fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Shipment(
      id: doc.id,
      trackingNumber: (data['trackingNumber'] as String?) ?? '',
      shippedAt: _parseDate(data['shippedAt']),
      location: (data['location'] as String?) ?? '',
      status: (data['status'] as String?) ?? ShipmentStatus.pending.value,
      isArchived: (data['isArchived'] as bool?) ?? false,
    );
  }

  Shipment _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return Shipment(
      id: doc.id,
      trackingNumber: (data['trackingNumber'] as String?) ?? '',
      shippedAt: _parseDate(data['shippedAt']),
      location: (data['location'] as String?) ?? '',
      status: (data['status'] as String?) ?? ShipmentStatus.pending.value,
      isArchived: (data['isArchived'] as bool?) ?? false,
    );
  }

  ShipmentEvent _eventFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String shipmentId,
  ) {
    final data = doc.data();
    return ShipmentEvent(
      id: doc.id,
      shipmentId: (data['shipmentId'] as String?) ?? shipmentId,
      userId: (data['userId'] as String?) ?? '',
      status: ShipmentStatus.fromRaw(data['status'] as String?),
      title: (data['title'] as String?) ?? 'Shipment updated',
      description: (data['description'] as String?) ?? '',
      location: (data['location'] as String?) ?? '',
      occurredAt: _parseDate(data['occurredAt']),
    );
  }

  DateTime _parseDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }
}

String _requireNonEmpty(String value, {required String fieldName}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(value, fieldName, 'must not be empty');
  }
  return trimmed;
}

ShipmentStatus _normalizeStatus(ShipmentStatus status) {
  return status == ShipmentStatus.unknown ? ShipmentStatus.pending : status;
}

AlertKind _alertKindFor(ShipmentStatus status) {
  return switch (status) {
    ShipmentStatus.complete => AlertKind.success,
    ShipmentStatus.inDelivery => AlertKind.info,
    ShipmentStatus.pending => AlertKind.info,
    ShipmentStatus.failed => AlertKind.error,
    ShipmentStatus.unknown => AlertKind.warning,
  };
}
