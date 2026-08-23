import 'package:cloud_firestore/cloud_firestore.dart';

class OrderHistory {
  final String id;
  final String orderId;
  final String actionName;
  final DateTime timestamp;
  final String userName;
  final String? notes;

  OrderHistory({
    required this.id,
    required this.orderId,
    required this.actionName,
    required this.timestamp,
    required this.userName,
    this.notes,
  });

  factory OrderHistory.fromMap(Map<String, dynamic> map, String documentId) {
    return OrderHistory(
      id: documentId,
      orderId: map['orderId'] ?? '',
      actionName: map['actionName'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      userName: map['userName'] ?? '',
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'actionName': actionName,
      'timestamp': timestamp,
      'userName': userName,
      'notes': notes,
    };
  }
}
