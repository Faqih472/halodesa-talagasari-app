import 'package:cloud_firestore/cloud_firestore.dart';

class AnnouncementModel {
  String id;
  String judul;
  String isi;
  String status; // 'draft', 'pending', 'published'
  String author;
  DateTime createdAt;

  AnnouncementModel({
    required this.id,
    required this.judul,
    required this.isi,
    required this.status,
    required this.author,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'judul': judul,
      'isi': isi,
      'status': status,
      'author': author,
      'createdAt': createdAt,
    };
  }

  factory AnnouncementModel.fromMap(Map<String, dynamic> map) {
    return AnnouncementModel(
      id: map['id'] ?? '',
      judul: map['judul'] ?? '',
      isi: map['isi'] ?? '',
      status: map['status'] ?? 'pending',
      author: map['author'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}