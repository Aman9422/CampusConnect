import 'package:cloud_firestore/cloud_firestore.dart';

class Placement {
  final String id;
  final String company;
  final String role;
  final String description;
  final String eligibility;
  final String salary;
  final DateTime deadline;
  final DateTime postedAt;
  final bool isActive;

  const Placement({
    required this.id,
    required this.company,
    required this.role,
    required this.description,
    required this.eligibility,
    required this.salary,
    required this.deadline,
    required this.postedAt,
    required this.isActive,
  });

  factory Placement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Placement(
      id: doc.id,
      company: data['company'] ?? '',
      role: data['role'] ?? '',
      description: data['description'] ?? '',
      eligibility: data['eligibility'] ?? '',
      salary: data['salary'] ?? 'Not Specified',
      deadline: (data['deadline'] as Timestamp).toDate(),
      postedAt: (data['postedAt'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'company': company,
      'role': role,
      'description': description,
      'eligibility': eligibility,
      'salary': salary,
      'deadline': Timestamp.fromDate(deadline),
      'postedAt': Timestamp.fromDate(postedAt),
      'isActive': isActive,
    };
  }

  bool get isDeadlinePassed => DateTime.now().isAfter(deadline);
}
