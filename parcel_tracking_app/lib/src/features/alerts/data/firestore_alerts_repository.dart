import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../parcels/domain/shipment.dart';
import '../domain/alert.dart';

abstract class AlertsRepository {
  Stream<List<AlertItem>> watchCurrentUserAlerts();
  Future<void> markAlertAsRead(String alertId);
  Future<void> markAllAlertsAsRead();
  Future<void> backfillAlertsFromEvents();
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
        .collection('users')
        .doc(user.uid)
        .collection('alerts')
        .orderBy('createdAt', descending: true);

    return ref.snapshots().map((snapshot) {
      try {
        return snapshot.docs.map(_alertFromDoc).toList();
      } catch (e) {
        debugPrint('FirestoreAlertsRepository error in map: $e');
        return [];
      }
    });
  }

  @override
  Future<void> markAlertAsRead(String alertId) async {
    final user = _auth.currentUser;
    if (user == null || alertId.isEmpty) {
      throw StateError('No user logged in.');
    }

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('alerts')
        .doc(alertId)
        .update({'isRead': true});
  }

  @override
  Future<void> markAllAlertsAsRead() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No user logged in.');
    }

    final unreadSnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('alerts')
        .where('isRead', isEqualTo: false)
        .get();

    if (unreadSnapshot.docs.isEmpty) {
      return;
    }

    final batch = _firestore.batch();
    for (final doc in unreadSnapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  @override
  Future<void> backfillAlertsFromEvents() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No user logged in.');
    }

    final alertsRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('alerts');
    final existingAlertsSnapshot = await alertsRef.get();
    final existingAlertIds = existingAlertsSnapshot.docs
        .map((doc) => doc.id)
        .toSet();

    final eventsSnapshot = await _firestore
        .collectionGroup('events')
        .where('userId', isEqualTo: user.uid)
        .get();

    final batch = _firestore.batch();
    var writeCount = 0;

    for (final doc in eventsSnapshot.docs) {
      if (existingAlertIds.contains(doc.id)) {
        continue;
      }

      final alertRef = alertsRef.doc(doc.id);
      final data = doc.data();
      final status = ShipmentStatus.fromRaw(data['status'] as String?);

      batch.set(alertRef, {
        'shipmentId': data['shipmentId'] as String?,
        'eventId': doc.id,
        'title': (data['title'] as String?) ?? 'Shipment update',
        'description': (data['description'] as String?) ?? '',
        'kind': _kindForStatus(status).name,
        'isRead': false,
        'createdAt': data['occurredAt'] ?? Timestamp.now(),
      });
      writeCount++;
    }

    if (writeCount > 0) {
      await batch.commit();
    }
  }

  AlertItem _alertFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    return AlertItem(
      id: doc.id,
      title: (data['title'] as String?) ?? 'Shipment update',
      message: (data['description'] as String?) ?? '',
      createdAt: _parseDate(data['createdAt']),
      shipmentId: data['shipmentId'] as String?,
      kind: _kindFromRaw(data['kind'] as String?),
      isRead: (data['isRead'] as bool?) ?? false,
    );
  }

  AlertKind _kindFromRaw(String? rawKind) {
    return switch (rawKind) {
      'success' => AlertKind.success,
      'error' => AlertKind.error,
      'warning' => AlertKind.warning,
      _ => AlertKind.info,
    };
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

AlertKind _kindForStatus(ShipmentStatus status) {
  return switch (status) {
    ShipmentStatus.complete => AlertKind.success,
    ShipmentStatus.inDelivery => AlertKind.info,
    ShipmentStatus.pending => AlertKind.info,
    ShipmentStatus.failed => AlertKind.error,
    ShipmentStatus.unknown => AlertKind.warning,
  };
}
