class Branch {
  final String id;
  final String name;
  final String code;
  final bool isActive;

  Branch({
    required this.id,
    required this.name,
    required this.code,
    required this.isActive,
  });

  factory Branch.fromMap(Map<String, dynamic> map, String documentId) {
    return Branch(
      id: documentId,
      name: map['name'] ?? '',
      code: map['code'] ?? '',
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'code': code,
      'isActive': isActive,
    };
  }
}
