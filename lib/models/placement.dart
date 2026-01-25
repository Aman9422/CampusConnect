import 'package:campusconnect/models/placement_eligibility.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Placement model - v6.5
/// Enhanced with structured requirements for eligibility checking
class Placement {
  final String id;
  final String company;
  final String role;
  final String description;
  final String eligibility; // Legacy text field
  final String salary;
  final DateTime deadline;
  final DateTime postedAt;
  final bool isActive;

  // v6.5: Structured requirements for rule-based eligibility
  final PlacementRequirements requirements;

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
    this.requirements = const PlacementRequirements(),
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
      // v6.5: Parse structured requirements
      requirements: PlacementRequirements.fromMap(
        data['requirements'] as Map<String, dynamic>?,
      ),
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
      'requirements': requirements.toMap(),
    };
  }

  bool get isDeadlinePassed => DateTime.now().isAfter(deadline);

  /// v6.5: Check if placement has structured requirements
  bool get hasStructuredRequirements => !requirements.isOpenToAll;
}
