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
    // v9.1 audit (SEC-1 defense-in-depth): a malformed placement doc (e.g.
    // `deadline` stored as a String, or `postedAt` missing) used to crash
    // EVERY client rendering the placements list via the hard casts
    // `(data['deadline'] as Timestamp).toDate()`. The server-side rules now
    // reject such docs, but the model stays tolerant so one bad legacy doc
    // can never take down the whole placements feature.
    final deadline = data['deadline'];
    final postedAt = data['postedAt'];
    return Placement(
      id: doc.id,
      company: data['company'] ?? '',
      role: data['role'] ?? '',
      description: data['description'] ?? '',
      eligibility: data['eligibility'] ?? '',
      salary: data['salary'] ?? 'Not Specified',
      deadline: deadline is Timestamp
          ? deadline.toDate()
          : DateTime.now().add(const Duration(days: 30)),
      postedAt: postedAt is Timestamp
          ? postedAt.toDate()
          : DateTime.now(),
      isActive: data['isActive'] ?? true,
      // v6.5: Parse structured requirements
      // v9.1 audit (SEC-1 defense-in-depth): guard the cast — a malformed
      // legacy doc with a non-map `requirements` (e.g. a String from a
      // console edit) used to throw a TypeError here and crash EVERY client
      // rendering the placements list. A non-map field now degrades to the
      // open-to-all default instead.
      requirements: PlacementRequirements.fromMap(
        data['requirements'] is Map<String, dynamic>
            ? data['requirements'] as Map<String, dynamic>
            : null,
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
