import 'package:campusconnect/enums/user_role.dart';
import 'package:campusconnect/services/firestore/engagement_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// CampusConnect v8.7.1 — role-aware "active" badge title.
///
/// The Alumni dashboard's Engagement section previously showed the
/// Student-flavored badge "Active Student" for Alumni (user report). The
/// title is now role-aware — Alumni see "Active Alumni". The Cloud Function
/// mirrors this exact rule so the badge never flickers between writers.
void main() {
  group('EngagementService.activeBadgeTitle (role-aware)', () {
    test('alumni see "Active Alumni"', () {
      expect(
        EngagementService.activeBadgeTitle(UserRole.alumni),
        'Active Alumni',
      );
    });

    test('students keep "Active Student"', () {
      expect(
        EngagementService.activeBadgeTitle(UserRole.student),
        'Active Student',
      );
    });

    test(
      'teachers see the student label (badge is student/alumni-oriented)',
      () {
        // Teachers do not have a dashboard Engagement card surface, but the
        // title must never crash for a non-alumni role.
        expect(
          EngagementService.activeBadgeTitle(UserRole.teacher),
          'Active Student',
        );
      },
    );
  });
}
