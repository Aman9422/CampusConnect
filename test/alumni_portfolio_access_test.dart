import 'package:flutter_test/flutter_test.dart';

/// CampusConnect v8.7 — Alumni Portfolio access contract tests.
///
/// Mirrors the role-gating in `main.dart` (`_guardStudentPortfolio`) and the
/// read-only student portfolio rules as pure Dart functions (Task §1/§5/§13):
///
///   1. Alumni cannot access the Student Portfolio editing workflow.
///   2. Students can still access the Portfolio editing workflow.
///   3. Alumni cannot modify a Student's portfolio data (read-only).
class StudentPortfolioAccessGate {
  const StudentPortfolioAccessGate._();

  /// Editing routes deny Alumni and show a blocked view instead (Task §5).
  static bool canEditPortfolio(String? role) => role == 'student';

  /// The read-only portfolio route stays open for Alumni (Task §13).
  static bool canViewPortfolioReadOnly(String? role) =>
      role == 'student' || role == 'alumni' || role == 'teacher';

  /// A client write to another user's portfolio doc is always denied by
  /// `firestore.rules` (`isOwner` + alumni-read-only). Mirrors the rule that
  /// Alumni may READ a student doc but never WRITE it.
  static bool canWriteUserDocument({
    required bool isOwner,
    required String writerRole,
  }) =>
      isOwner &&
      (writerRole == 'student' ||
          writerRole == 'alumni' ||
          writerRole == 'teacher');
}

void main() {
  group('StudentPortfolioAccessGate (editing is student-only)', () {
    test('Alumni cannot access the Student Portfolio editing workflow', () {
      expect(StudentPortfolioAccessGate.canEditPortfolio('alumni'), isFalse);
    });

    test('Students can access the Portfolio editing workflow', () {
      expect(StudentPortfolioAccessGate.canEditPortfolio('student'), isTrue);
    });

    test('Teachers cannot edit a student portfolio either (issue M5)', () {
      expect(StudentPortfolioAccessGate.canEditPortfolio('teacher'), isFalse);
    });

    test('unresolved role cannot edit', () {
      expect(StudentPortfolioAccessGate.canEditPortfolio(null), isFalse);
    });
  });

  group('StudentPortfolioAccessGate (read-only views stay open)', () {
    test('Alumni keep read-only access to a student portfolio', () {
      expect(
        StudentPortfolioAccessGate.canViewPortfolioReadOnly('alumni'),
        isTrue,
      );
    });

    test('Students can view their own portfolio read-only', () {
      expect(
        StudentPortfolioAccessGate.canViewPortfolioReadOnly('student'),
        isTrue,
      );
    });
  });

  group('StudentPortfolioAccessGate (no cross-user writes)', () {
    test('Alumni cannot modify a student\'s portfolio data', () {
      // Alumni reading a student doc (Firestore rule) grants READ only — a
      // write to that doc is denied because the writer is not the owner.
      expect(
        StudentPortfolioAccessGate.canWriteUserDocument(
          isOwner: false,
          writerRole: 'alumni',
        ),
        isFalse,
      );
    });

    test('owner writes are allowed for any verified role', () {
      expect(
        StudentPortfolioAccessGate.canWriteUserDocument(
          isOwner: true,
          writerRole: 'student',
        ),
        isTrue,
      );
    });
  });
}
