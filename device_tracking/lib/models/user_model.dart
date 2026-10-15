import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String role; // 'admin' or 'staff'
  final String? branchId;
  final String? region; // e.g. 'الرياض', 'الشرقية', 'الغربية', 'الجنوبية'
  final List<String>? assignedBranchIds;
  final String? phone;
  final bool isActive;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.name,
    this.email = '',
    required this.role,
    this.branchId,
    this.region,
    this.assignedBranchIds,
    this.phone,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      id: documentId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'staff',
      branchId: map['branchId'],
      region: map['region'],
      assignedBranchIds: map['assignedBranchIds'] != null ? List<String>.from(map['assignedBranchIds']) : [],
      phone: map['phone'],
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'branchId': branchId,
      'region': region,
      'assignedBranchIds': assignedBranchIds ?? [],
      if (phone != null) 'phone': phone,
      'isActive': isActive,
      'createdAt': createdAt,
    };
  }

  bool get isAdmin => role == 'admin';
}
