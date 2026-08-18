import 'package:campusconnect/enums/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

/// CampusConnect v8.9 — Teacher Profile & Role-Specific UX contract tests.
///
/// Mirrors the role-based profile routing from `lib/main.dart`
/// (`_RoleAwareProfileView`) and the role-specific edit branch in
/// `lib/views/edit_profile_view.dart` (`_saveProfile`):
///   - Student → Student Profile (ProfileView)
///   - Alumni → Lightweight Alumni Profile (ProfileView alumni branch)
///   - Teacher → TeacherProfileView — never the Student Profile workflow
///   - Teacher edit path updates only the authenticated teacher's own
///     users/{uid} doc (personal + department + designation; no CGPA form)
///   - Logout resets role-gated providers so no stale Student state leaks
///     into Teacher sessions
///
/// Pure-Dart mirror pattern (like test/security_rules_mirror_test.dart) —
/// no Firebase, no API keys.

/// Mirrors the `profileRoute` branch in `_RoleAwareProfileView`.
String resolveProfileRoute(UserRole? role) {
  switch (role) {
    case UserRole.teacher:
      return 'teacher_profile_view';
    case UserRole.alumni:
      return 'profile_view_alumni_branch';
    case UserRole.student:
    case null:
      return 'profile_view_student_branch';
  }
}

/// Mirrors `_saveProfile`'s teacher branch in EditProfileView — the ONLY
/// fields a teacher may update are personal (fullName/phone/bio), department
/// and designation. No academic/CGPA fields are written.
Map<String, dynamic> buildTeacherProfileUpdate({
  required Map<String, dynamic> current,
  required String fullName,
  required String phone,
  required String bio,
  required String department,
  required String designation,
}) {
  return {
    ...current,
    'personal': {
      ...(current['personal'] as Map<String, dynamic>? ?? {}),
      'fullName': fullName.trim(),
      'phone': phone.trim(),
      'bio': bio.trim(),
    },
    if (department.trim().isNotEmpty) 'department': department.trim(),
    if (designation.trim().isNotEmpty) 'designation': designation.trim(),
    // A teacher update NEVER touches academic / cgpa / program.
  };
}

/// Mirrors the presence check used by the Teacher Profile view: a teacher
/// profile must NOT render any Student-only control.
bool teacherProfileShowsStudentOnlyControls(List<String> renderedSections) {
  const studentOnlySections = [
    'Portfolio',
    'Resume Upload',
    'Resume Review / ATS',
    'Career Preferences',
    'Projects / Credentials',
    'Placement actions',
    'Student recommendations',
  ];
  return renderedSections.any(studentOnlySections.contains);
}

void main() {
  group('role-based profile routing', () {
    test('student → Student Profile (student branch)', () {
      expect(
        resolveProfileRoute(UserRole.student),
        'profile_view_student_branch',
      );
    });

    test('alumni → lightweight Alumni Profile branch', () {
      expect(
        resolveProfileRoute(UserRole.alumni),
        'profile_view_alumni_branch',
      );
    });

    test('teacher → TeacherProfileView — never the Student workflow', () {
      expect(resolveProfileRoute(UserRole.teacher), 'teacher_profile_view');
    });

    test('unresolved role does not fall through to the Teacher profile', () {
      expect(resolveProfileRoute(null), 'profile_view_student_branch');
    });
  });

  group('teacher profile edit — ownership-safe, no student-only fields', () {
    test('updates only personal + department + designation', () {
      const current = {
        'role': 'teacher',
        'academic': {'cgpa': 9.1, 'program': 'CSE', 'college': 'X', 'year': 4},
        'department': '',
      };

      final updated = buildTeacherProfileUpdate(
        current: current,
        fullName: '  Dr. Smith  ',
        phone: '123',
        bio: 'Professor',
        department: 'CSE',
        designation: 'Professor',
      );

      expect(updated['personal']['fullName'], 'Dr. Smith');
      expect(updated['department'], 'CSE');
      expect(updated['designation'], 'Professor');
      // Academic/CGPA is PRESERVED untouched — never written by the teacher flow.
      expect(updated['academic'], current['academic']);
      expect(updated['role'], 'teacher');
    });

    test('empty department/designation are dropped (stay unset)', () {
      final updated = buildTeacherProfileUpdate(
        current: {'role': 'teacher'},
        fullName: 'Dr. Smith',
        phone: '',
        bio: '',
        department: '  ',
        designation: '',
      );

      expect(updated.containsKey('department'), isFalse);
      expect(updated.containsKey('designation'), isFalse);
    });
  });

  group('teacher profile surface — no student-only controls', () {
    test('TeacherProfileView sections are teacher-appropriate only', () {
      final teacherSections = [
        'Teacher Information',
        'Email',
        'Department',
        'Designation',
        'Account',
        'App Info',
      ];
      expect(teacherProfileShowsStudentOnlyControls(teacherSections), isFalse);
    });

    test(
      'the old accidental Student reuse would be rejected by this guard',
      () {
        final studentSections = [
          'Portfolio',
          'Resume Upload',
          'Career Preferences',
          'Projects',
        ];
        expect(teacherProfileShowsStudentOnlyControls(studentSections), isTrue);
      },
    );
  });
}
