/// PlacementPipelineData — v8.2.3
///
/// Typed container for all placement pipeline stages.
/// Every field represents UNIQUE student count, NOT application count.
///
/// Future-compatible: when Firestore gains stage tracking (shortlisted,
/// interview, placed), simply populate the remaining fields — no UI changes needed.
class PlacementPipelineData {
  final int eligibleStudents;
  final int appliedStudents;
  final int shortlistedStudents;
  final int interviewedStudents;
  final int placedStudents;

  const PlacementPipelineData({
    required this.eligibleStudents,
    required this.appliedStudents,
    this.shortlistedStudents = 0,
    this.interviewedStudents = 0,
    this.placedStudents = 0,
  });

  /// Whether any stage beyond Eligible has real data.
  bool get hasActivity =>
      appliedStudents > 0 ||
      shortlistedStudents > 0 ||
      interviewedStudents > 0 ||
      placedStudents > 0;

  /// All stage values as a list, in pipeline order (for charting, maxY, etc.).
  List<int> get allStageValues => [
        eligibleStudents,
        appliedStudents,
        shortlistedStudents,
        interviewedStudents,
        placedStudents,
      ];

  /// Human-readable stage labels (for tooltips).
  static const List<String> stageLabels = [
    'Eligible Students',
    'Students Applied',
    'Students Shortlisted',
    'Students Interviewed',
    'Students Placed',
  ];

  /// Short labels (for chart axes).
  static const List<String> shortLabels = [
    'Eligible',
    'Applied',
    'Shortlisted',
    'Interview',
    'Placed',
  ];

  /// Whether the stage at [stageIndex] has real tracked data.
  ///
  /// v9.1: ALL stages are now tracked — applications carry a `status` field
  /// (`applied | shortlisted | interviewed | placed | rejected`) written by
  /// the `updateApplicationStatus` Cloud Function, and
  /// `TeacherAnalyticsService.getApplicationPipelineCounts` buckets statuses
  /// into per-stage distinct-student counts.
  static bool isStageTracked(int stageIndex) {
    return stageIndex >= 0 && stageIndex < stageLabels.length;
  }
}
