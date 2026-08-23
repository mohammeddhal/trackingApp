import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadSignature(String orderId, Uint8List signatureBytes) async {
    final ref = _storage.ref().child('signatures/$orderId.png');
    final uploadTask = ref.putData(signatureBytes, SettableMetadata(contentType: 'image/png'));
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  Future<String> uploadAttachment(String orderId, File file) async {
    final fileName = file.path.split('/').last;
    final ref = _storage.ref().child('attachments/$orderId/$fileName');
    final uploadTask = ref.putFile(file);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }
}
