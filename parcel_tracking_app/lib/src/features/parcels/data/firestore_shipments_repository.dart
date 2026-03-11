import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../domain/shipment.dart';
import '../domain/shipment_event.dart';

abstract class ShipmentsRepository {
  Stream<List<Shipment>> watchCurrentUserShipments();
  Future<String> addShipment(Shipment shipment);
  Future<void> updateShipment({
    required Shipment previous,
    required Shipment updated,
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

    final shipmentRef = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('shipments')
        .add({
          'trackingNumber': shipment.trackingNumber,
          'shippedAt': Timestamp.fromDate(shipment.shippedAt),
          'location': shipment.location,
          'status': shipment.normalizedStatus.value,
        });

    await _appendShipmentEvent(
      shipmentId: shipmentRef.id,
      event: buildShipmentEvent(
        shipmentId: shipmentRef.id,
        userId: user.uid,
        status: shipment.normalizedStatus,
        location: shipment.location,
        occurredAt: shipment.shippedAt,
      ),
    );

    return shipmentRef.id;
  }

  @override
  Future<void> updateShipment({
    required Shipment previous,
    required Shipment updated,
  }) async {
    final user = _auth.currentUser;
    if (user == null || updated.id.isEmpty) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('shipments')
        .doc(updated.id)
        .update({
          'trackingNumber': updated.trackingNumber,
          'location': updated.location,
          'status': updated.normalizedStatus.value,
        });

    final didStatusChange = previous.normalizedStatus != updated.normalizedStatus;
    final didLocationChange = previous.location.trim() != updated.location.trim();

    if (didStatusChange || didLocationChange) {
      await _appendShipmentEvent(
        shipmentId: updated.id,
        event: buildShipmentEvent(
          shipmentId: updated.id,
          userId: user.uid,
          status: updated.normalizedStatus,
          location: updated.location,
          occurredAt: DateTime.now(),
        ),
      );
    }
  }

  @override
  Stream<List<Shipment>> watchCurrentUserShipments() {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('FirestoreShipmentsRepository: No user logged in.');
      return const Stream<List<Shipment>>.empty();
    }

    final ref = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('shipments')
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

  Future<void> _appendShipmentEvent({
    required String shipmentId,
    required ShipmentEvent event,
  }) async {
    await _firestore
        .collection('users')
        .doc(event.userId)
        .collection('shipments')
        .doc(shipmentId)
        .collection('events')
        .add({
          'userId': event.userId,
          'shipmentId': event.shipmentId,
          'status': event.status.value,
          'title': event.title,
          'description': event.description,
          'location': event.location,
          'occurredAt': Timestamp.fromDate(event.occurredAt),
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
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }
}
