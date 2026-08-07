import 'package:campusconnect/models/application.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// v8.4.2 (S7): Data-contract tests for the placement application record.
///
/// Covers M1 (status unified to "applied" on both write paths) and T5
/// (resume snapshot fields preserved at apply time — docs/Task.md Phase 8).
void main() {
  Map<String, dynamic> minimalData({String? status}) => {
    'userId': 'u1',
    'placementId': 'p1',
    'resumeUrl': '',
    'appliedAt': Timestamp.fromDate(DateTime(2026, 7, 1)),
    if (status != null) 'status': status,
  };

  group('Application.fromFirestore', () {
    test('defaults status to "applied" when missing (M1)', () {
      final app = Application.fromFirestore(
        FakeDocumentSnapshot(minimalData()),
      );
      expect(app.status, 'applied');
    });

    test('reads the unified "applied" status (M1/S3b)', () {
      final app = Application.fromFirestore(
        FakeDocumentSnapshot(minimalData(status: 'applied')),
      );
      expect(app.status, 'applied');
    });

    test('preserves T5 resume snapshot fields', () {
      final app = Application.fromFirestore(
        FakeDocumentSnapshot({
          ...minimalData(status: 'applied'),
          'resumeVersion': 3,
          'resumeStoragePath': 'resumes/u1/latest.pdf',
          'atsScoreAtApplication': 82,
        }),
      );
      expect(app.resumeVersion, 3);
      expect(app.resumeStoragePath, 'resumes/u1/latest.pdf');
      expect(app.atsScoreAtApplication, 82);
    });

    test('tolerates null snapshot fields (legacy applications)', () {
      final app = Application.fromFirestore(FakeDocumentSnapshot(minimalData()));
      expect(app.resumeVersion, isNull);
      expect(app.resumeStoragePath, isNull);
      expect(app.atsScoreAtApplication, isNull);
    });
  });

  group('Application.toMap', () {
    test('aliases studentId and writes the unified status', () {
      final app = Application.fromFirestore(
        FakeDocumentSnapshot(minimalData(status: 'applied')),
      );
      final map = app.toMap();
      expect(map['studentId'], 'u1');
      expect(map['userId'], 'u1');
      expect(map['status'], 'applied');
    });

    test('omits null snapshot fields from toMap', () {
      final app = Application.fromFirestore(FakeDocumentSnapshot(minimalData()));
      final map = app.toMap();
      expect(map.containsKey('resumeVersion'), isFalse);
      expect(map.containsKey('resumeStoragePath'), isFalse);
      expect(map.containsKey('atsScoreAtApplication'), isFalse);
    });
  });
}

// ignore: subtype_of_sealed_class
/// Minimal DocumentSnapshot stand-in — Application.fromFirestore only needs
/// `id` and `data()`. DocumentSnapshot is sealed in cloud_firestore, so the
/// test double opts out of subtype_of_sealed_class (standard for SDK types).
class FakeDocumentSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic> _data;

  FakeDocumentSnapshot(this._data);

  @override
  String get id => 'app1';

  @override
  Map<String, dynamic> data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
