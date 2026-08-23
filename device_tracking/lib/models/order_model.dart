import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;
  final String branchId;
  final String orderNumber;
  final String deviceType;
  final String manufacturer;
  final String productName;
  final String? color;
  final String imeiOrSerial;
  final String problem;
  final String deviceCondition;
  final String delivererName;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime receivedFromCustomerDate;
  final String? receiverName;
  final String? receiverPhone;
  final String? maintenanceResult;
  final List<String>? accessories;
  final String? intakeNotes;
  final bool? handedOverWithAccessories;
  final String? handoverNotes;
  final String? serviceCenterOrderNumber;
  final String? serviceCenterName;

  OrderModel({
    required this.id,
    required this.branchId,
    required this.orderNumber,
    required this.deviceType,
    required this.manufacturer,
    required this.productName,
    this.color,
    required this.imeiOrSerial,
    required this.problem,
    required this.deviceCondition,
    required this.delivererName,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.receivedFromCustomerDate,
    this.receiverName,
    this.receiverPhone,
    this.maintenanceResult,
    this.accessories,
    this.intakeNotes,
    this.handedOverWithAccessories,
    this.handoverNotes,
    this.serviceCenterOrderNumber,
    this.serviceCenterName,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map, String documentId) {
    final created = (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    return OrderModel(
      id: documentId,
      branchId: map['branchId'] ?? '',
      orderNumber: map['orderNumber'] ?? '',
      deviceType: map['deviceType'] ?? '',
      manufacturer: map['manufacturer'] ?? '',
      productName: map['productName'] ?? '',
      color: map['color'],
      imeiOrSerial: map['imeiOrSerial'] ?? '',
      problem: map['problem'] ?? '',
      deviceCondition: map['deviceCondition'] ?? '',
      delivererName: map['delivererName'] ?? '',
      status: map['status'] ?? 'pending_service_center',
      createdAt: created,
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      receivedFromCustomerDate: (map['receivedFromCustomerDate'] as Timestamp?)?.toDate() ?? created,
      receiverName: map['receiverName'],
      receiverPhone: map['receiverPhone'],
      maintenanceResult: map['maintenanceResult'],
      accessories: map['accessories'] != null ? List<String>.from(map['accessories']) : null,
      intakeNotes: map['intakeNotes'],
      handedOverWithAccessories: map['handedOverWithAccessories'],
      handoverNotes: map['handoverNotes'],
      serviceCenterOrderNumber: map['serviceCenterOrderNumber'],
      serviceCenterName: map['serviceCenterName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'branchId': branchId,
      'orderNumber': orderNumber,
      'deviceType': deviceType,
      'manufacturer': manufacturer,
      'productName': productName,
      'color': color,
      'imeiOrSerial': imeiOrSerial,
      'problem': problem,
      'deviceCondition': deviceCondition,
      'delivererName': delivererName,
      'status': status,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'receivedFromCustomerDate': receivedFromCustomerDate,
      if (receiverName != null) 'receiverName': receiverName,
      if (receiverPhone != null) 'receiverPhone': receiverPhone,
      if (maintenanceResult != null) 'maintenanceResult': maintenanceResult,
      if (accessories != null) 'accessories': accessories,
      if (intakeNotes != null) 'intakeNotes': intakeNotes,
      if (handedOverWithAccessories != null) 'handedOverWithAccessories': handedOverWithAccessories,
      if (handoverNotes != null) 'handoverNotes': handoverNotes,
      if (serviceCenterOrderNumber != null) 'serviceCenterOrderNumber': serviceCenterOrderNumber,
      if (serviceCenterName != null) 'serviceCenterName': serviceCenterName,
    };
  }

  int get maintenanceDays {
    DateTime end = (status == 'completed' || status == 'delivered_branch') ? updatedAt : DateTime.now();
    int days = 0;
    DateTime current = DateTime(receivedFromCustomerDate.year, receivedFromCustomerDate.month, receivedFromCustomerDate.day);
    DateTime endDate = DateTime(end.year, end.month, end.day);
    
    while (current.isBefore(endDate)) {
      if (current.weekday != DateTime.friday && current.weekday != DateTime.saturday) {
        days++;
      }
      current = current.add(const Duration(days: 1));
    }
    return days;
  }
}
