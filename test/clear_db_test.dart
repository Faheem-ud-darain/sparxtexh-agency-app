import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:company_app/firebase_options.dart';

void main() {
  test('Clear Users Collection', () async {
    print('Initializing Firebase...');
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    
    final usersCol = FirebaseFirestore.instance.collection('users');
    final snapshot = await usersCol.get();
    
    print('Found ${snapshot.docs.length} users. Deleting...');
    
    for (var doc in snapshot.docs) {
      await usersCol.doc(doc.id).delete();
    }
    
    print('Success: All users deleted.');
  });
}
