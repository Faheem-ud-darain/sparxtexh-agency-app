import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:company_app/firebase_options.dart';

void main() async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    final uid = 'f6tcbIYbx0WhNQk5EF2MXvmJjfz2';
    
    print('PROMOTING UID: $uid');
    
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'uid': uid,
      'is_approved': true,
      'role': 'admin',
      'name': 'Faheem Jadoon',
      'email': 'studiozsparx@gmail.com',
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    print('SUCCESS: Master account activated.');
    exit(0);
  } catch (e) {
    print('ERROR: $e');
    exit(1);
  }
}
