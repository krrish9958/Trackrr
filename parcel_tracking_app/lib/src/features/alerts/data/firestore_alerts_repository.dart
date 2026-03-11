import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../parcels/domain/shipment.dart';
import '../domain/alert.dart';

abstract class AlertsRepository {
  Stream<List<AlertItem>> watchCurrentUserAlerts();
}

class FirestoreAlertsRepository implements AlertsRepository {
  FirestoreAlertsRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  @override
  Stream<List<AlertItem>> watchCurrentUserAlerts() {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('FirestoreAlertsRepository: no user logged in');
      return Stream.value([]);
    }

    final ref = _firestore
        .collectionGroup('events')
        .where('userId', isEqualTo: user.uid)
        .orderBy('occurredAt', descending: true);

    return ref.snapshots().map((snapshot) {
      try {
        return snapshot.docs.map(_alertFromEvent).toList();
      } catch (e) {
        debugPrint('FirestoreAlertsRepository error in map: $e');
        return [];
      }
    });
  }

  AlertItem _alertFromEvent(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final status = ShipmentStatus.fromRaw(data['status'] as String?);

    return AlertItem(
      id: doc.id,
      title: (data['title'] as String?) ?? 'Shipment update',
      message: (data['description'] as String?) ?? '',
      createdAt: _parseDate(data['occurredAt']),
      shipmentId: data['shipmentId'] as String?,
      kind: switch (status) {
        ShipmentStatus.complete => AlertKind.success,
        ShipmentStatus.inDelivery => AlertKind.info,
        ShipmentStatus.pending => AlertKind.info,
        ShipmentStatus.failed => AlertKind.error,
        ShipmentStatus.unknown => AlertKind.warning,
      },
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
