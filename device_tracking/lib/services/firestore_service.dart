import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/branch.dart';
import '../models/user_model.dart';
import '../models/order_model.dart';
import '../models/order_history.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Users
  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  Stream<UserModel?> getUserStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }

  // Branches
  Stream<List<Branch>> getBranches() {
    return _db.collection('branches').where('isActive', isEqualTo: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Branch.fromMap(doc.data(), doc.id)).toList();
    });
  }

  // Orders
  Future<bool> isOrderNumberExists(String orderNumber) async {
    final query = await _db
        .collection('orders')
        .where('orderNumber', isEqualTo: orderNumber)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  Future<void> createOrder(OrderModel order, OrderHistory history) async {
    final batch = _db.batch();
    
    final orderRef = _db.collection('orders').doc(order.id);
    batch.set(orderRef, order.toMap());

    final historyRef = _db.collection('order_history').doc(history.id);
    batch.set(historyRef, history.toMap());

    batch.commit();
  }

  Future<void> updateOrderStatus(String orderId, String newStatus, OrderHistory history, {Map<String, dynamic>? additionalData}) async {
    final batch = _db.batch();
    
    final orderRef = _db.collection('orders').doc(orderId);
    final updateData = <String, dynamic>{
      'status': newStatus,
      'updatedAt': DateTime.now(),
    };
    
    if (additionalData != null) {
      updateData.addAll(additionalData);
    }
    
    batch.update(orderRef, updateData);

    final historyRef = _db.collection('order_history').doc(history.id);
    batch.set(historyRef, history.toMap());

    batch.commit();
  }

  Stream<List<OrderModel>> getOrders() {
    return _db.collection('orders').orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => OrderModel.fromMap(doc.data(), doc.id)).toList();
    });
  }
  
  Stream<List<OrderHistory>> getOrderHistory(String orderId) {
    return _db
        .collection('order_history')
        .where('orderId', isEqualTo: orderId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => OrderHistory.fromMap(doc.data(), doc.id)).toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }
}
