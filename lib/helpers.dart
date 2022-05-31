import 'package:cloud_firestore/cloud_firestore.dart';

void _nameFromMail(mail) async {
  DocumentReference ref =
      FirebaseFirestore.instance.collection('Rooms').doc(mail);
  var doc = await ref.get();
  return doc.get('name');
}
