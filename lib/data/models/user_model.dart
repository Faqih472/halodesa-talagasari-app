class UserModel {
  String uid;
  String namaLengkap;
  String email;
  String noTelp;
  String role;

  UserModel({
    required this.uid,
    required this.namaLengkap,
    required this.email,
    required this.noTelp,
    required this.role,
  });

  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      namaLengkap: data['namaLengkap'] ?? '',
      email: data['email'] ?? '',
      noTelp: data['noTelp'] ?? '',
      role: data['role'] ?? 'warga',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'namaLengkap': namaLengkap,
      'email': email,
      'noTelp': noTelp,
      'role': role,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }
}