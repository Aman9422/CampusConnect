import 'package:campusconnect/models/portfolio/resume_metadata.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// v8.4.2 (S7): ResumeMetadata serialization + copyWith null-clear contract.
///
/// Covers T1 (spec field names + legacy-key fallbacks) and N5/S5e
/// (copyWith can't clear a field back to null — use fresh objects).
void main() {
  group('ResumeMetadata.fromMap', () {
    test('reads spec field names (uploadedAt/updatedAt/latestATSScore)', () {
      final uploaded = DateTime(2026, 6, 1);
      final updated = DateTime(2026, 7, 1);
      final lastReviewAt = DateTime(2026, 6, 20);
      final meta = ResumeMetadata.fromMap({
        'downloadUrl': 'https://x/resume.pdf',
        'storagePath': 'resumes/u1/latest.pdf',
        'uploadedAt': Timestamp.fromDate(uploaded),
        'updatedAt': Timestamp.fromDate(updated),
        'latestATSScore': 88,
        'reviewCount': 4,
        'lastReviewAt': Timestamp.fromDate(lastReviewAt),
      });
      expect(meta.uploadedAt, uploaded);
      expect(meta.updatedAt, updated);
      expect(meta.latestATSScore, 88);
      expect(meta.reviewCount, 4);
      expect(meta.lastReviewAt, lastReviewAt);
    });

    test('falls back to v8.4 legacy keys (uploadDate/lastUpdated/atsScore)', () {
      final uploaded = DateTime(2026, 5, 1);
      final updated = DateTime(2026, 5, 15);
      final meta = ResumeMetadata.fromMap({
        'storagePath': 'resumes/u1/latest.pdf',
        'uploadDate': Timestamp.fromDate(uploaded),
        'lastUpdated': Timestamp.fromDate(updated),
        'atsScore': 74,
      });
      expect(meta.uploadedAt, uploaded);
      expect(meta.updatedAt, updated);
      expect(meta.latestATSScore, 74);
    });

    test('hasResume true when only storagePath is set (N2/S4c)', () {
      final meta = ResumeMetadata.fromMap({'storagePath': 'resumes/u1/latest.pdf'});
      expect(meta.hasResume, isTrue);
    });

    test('hasResume false when both URL fields are empty', () {
      expect(ResumeMetadata.empty().hasResume, isFalse);
    });
  });

  group('ResumeMetadata.copyWith (N5)', () {
    test('null argument keeps the existing value', () {
      final base = const ResumeMetadata(latestATSScore: 88, lastReviewAt: null);
      // Passing null for latestATSScore keeps 88 (x ?? this.x).
      final updated = base.copyWith(latestATSScore: null);
      expect(updated.latestATSScore, 88);
      // Confirms the N5 limitation documented in S5e: a null param cannot
      // clear the field — callers must build a fresh object instead.
    });

    test('non-null argument replaces the value', () {
      const base = ResumeMetadata(latestATSScore: 60);
      final updated = base.copyWith(latestATSScore: 92);
      expect(updated.latestATSScore, 92);
    });
  });

  group('ResumeMetadata back-compat getters', () {
    test('uploadDate/lastUpdated/atsScore alias the spec fields', () {
      final meta = ResumeMetadata.fromMap({
        'storagePath': 'resumes/u1/latest.pdf',
        'uploadedAt': Timestamp.fromDate(DateTime(2026, 6, 1)),
        'updatedAt': Timestamp.fromDate(DateTime(2026, 7, 1)),
        'latestATSScore': 81,
      });
      expect(meta.uploadDate, meta.uploadedAt);
      expect(meta.lastUpdated, meta.updatedAt);
      expect(meta.atsScore, 81);
    });
  });
}
