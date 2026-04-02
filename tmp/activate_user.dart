import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:company_app/firebase_options.dart';

void main() async {
  try {
    // 1. Initialize Firebase for the script
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final db = FirebaseFirestore.instance;
    final email = 'studiozsparx@gmail.com';

    print('Searching for user: $email...');

    // 2. Find the user by email
    final query = await db.collection('users').where('email', isEqualTo: email).get();

    if (query.docs.isEmpty) {
      print('ERROR: User not found in database. Make sure you signed in first!');
      exit(1);
    }

    final userDoc = query.docs.first;
    final uid = userDoc.id;
    final data = userDoc.data();

    print('FOUND USER: ${data['name']} (UID: $uid)');

    // 3. Promote to Admin and Approve
    await db.collection('users').doc(uid).update({
      'role': 'admin',
      'is_approved': true,
    });

    print('SUCCESS: User $email has been activated and promoted to Admin.');
    print('UID_FOR_APP_CONSTANTS: $uid');

    exit(0);
  } catch (e) {
    print('EXCEPTION: $e');
    exit(1);
  }
}
