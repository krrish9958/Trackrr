import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../features/alerts/data/firestore_alerts_repository.dart';
import '../features/parcels/data/firestore_shipments_repository.dart';

class AppServices {
  AppServices({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : auth = auth ?? FirebaseAuth.instance,
       firestore = firestore ?? FirebaseFirestore.instance,
       shipmentsRepository = FirestoreShipmentsRepository(
         auth: auth ?? FirebaseAuth.instance,
         firestore: firestore ?? FirebaseFirestore.instance,
       ),
       alertsRepository = FirestoreAlertsRepository(
         auth: auth ?? FirebaseAuth.instance,
         firestore: firestore ?? FirebaseFirestore.instance,
       );

  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final FirestoreShipmentsRepository shipmentsRepository;
  final FirestoreAlertsRepository alertsRepository;
}
