class UserModel {
  final String id;
  final String name;
  final String role; // 'admin' or 'staff'
  final String? branchId;

  UserModel({
    required this.id,
    required this.name,
    required this.role,
    this.branchId,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      id: documentId,
      name: map['name'] ?? '',
      role: map['role'] ?? 'staff',
      branchId: map['branchId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'role': role,
      'branchId': branchId,
    };
  }

  bool get isAdmin => role == 'admin';
}
