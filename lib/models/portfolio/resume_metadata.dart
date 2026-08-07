import 'package:campusconnect/models/portfolio/portfolio_parse.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// CampusConnect v8.4.1 — Metadata for the uploaded resume PDF.
///
/// Stored under `users/{uid}/portfolio.resume`.
///
/// v8.4.1 (T1): Aligned with `docs/Task.md` Phase 2 field names — the spec's
/// `uploadedAt`/`updatedAt`/`latestATSScore` are now the canonical fields, and
/// `storagePath`, `fileSize`, `mimeType`, `reviewCount`, `lastReviewAt` and
/// `isDemoData` were added. v8.4-era reads still work through the
/// back-compat getters (`uploadDate`, `lastUpdated`, `atsScore`) and the
/// tolerant `fromMap` (legacy keys `uploadDate`/`lastUpdated`/`atsScore`).
class ResumeMetadata {
  final String? downloadUrl;
  final String? storagePath;
  /// Original file name selected by the student.
  final String? fileName;
  final int? fileSize;
  final String? mimeType;
  final DateTime? uploadedAt;
  final DateTime? updatedAt;
  final int version;
  final int? latestATSScore;
  final int reviewCount;
  final DateTime? lastReviewAt;
  final bool isDemoData;
  /// Placeholder for the resume parser that arrives in a future version.
  final String? parserVersion;

  const ResumeMetadata({
    this.downloadUrl,
    this.storagePath,
    this.fileName,
    this.fileSize,
    this.mimeType,
    this.uploadedAt,
    this.updatedAt,
    this.version = 1,
    this.latestATSScore,
    this.reviewCount = 0,
    this.lastReviewAt,
    this.isDemoData = false,
    this.parserVersion,
  });

  /// v8.4 back-compat alias for [uploadedAt].
  DateTime? get uploadDate => uploadedAt;

  /// v8.4 back-compat alias for [updatedAt].
  DateTime? get lastUpdated => updatedAt;

  /// v8.4 back-compat alias for [latestATSScore].
  int? get atsScore => latestATSScore;

  factory ResumeMetadata.empty() => const ResumeMetadata();

  factory ResumeMetadata.fromMap(Map<String, dynamic> map) {
    // v8.4.7: tolerant reads — a field stored with an unexpected shape
    // degrades to null/default instead of throwing and blanking the whole
    // portfolio. Dates may arrive as Timestamp, DateTime or ISO-8601 String
    // (console edits / foreign writers); numbers may arrive as double.
    final uploaded = tsToDate(map['uploadedAt']) ?? tsToDate(map['uploadDate']);
    final updated = tsToDate(map['updatedAt']) ?? tsToDate(map['lastUpdated']);
    final atsScore = asInt(map['latestATSScore']) ?? asInt(map['atsScore']);
    return ResumeMetadata(
      downloadUrl: asString(map['downloadUrl']),
      storagePath: asString(map['storagePath']),
      fileName: asString(map['fileName']),
      fileSize: asInt(map['fileSize']),
      mimeType: asString(map['mimeType']),
      uploadedAt: uploaded,
      updatedAt: updated,
      version: asInt(map['version']) ?? 1,
      latestATSScore: atsScore,
      reviewCount: asInt(map['reviewCount']) ?? 0,
      lastReviewAt: tsToDate(map['lastReviewAt']),
      isDemoData: asBool(map['isDemoData']) ?? false,
      parserVersion: asString(map['parserVersion']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'downloadUrl': downloadUrl,
      'storagePath': storagePath,
      'fileName': fileName,
      'fileSize': fileSize,
      'mimeType': mimeType,
      'uploadedAt': uploadedAt != null ? Timestamp.fromDate(uploadedAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'version': version,
      'latestATSScore': latestATSScore,
      'reviewCount': reviewCount,
      'lastReviewAt':
          lastReviewAt != null ? Timestamp.fromDate(lastReviewAt!) : null,
      'isDemoData': isDemoData,
      'parserVersion': parserVersion,
    };
  }

  /// NOTE (N5, v8.4.2): `copyWith` uses `x ?? this.x`, so it CANNOT clear a
  /// field back to null — passing `latestATSScore: null` or `lastReviewAt:
  /// null` keeps the existing value. To null a field, construct a fresh
  /// object (or use a sentinel). Matters when wiring the P1 ATS merge.
  ResumeMetadata copyWith({
    String? downloadUrl,
    String? storagePath,
    String? fileName,
    int? fileSize,
    String? mimeType,
    DateTime? uploadedAt,
    DateTime? updatedAt,
    int? version,
    int? latestATSScore,
    int? reviewCount,
    DateTime? lastReviewAt,
    bool? isDemoData,
    String? parserVersion,
  }) {
    return ResumeMetadata(
      downloadUrl: downloadUrl ?? this.downloadUrl,
      storagePath: storagePath ?? this.storagePath,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      latestATSScore: latestATSScore ?? this.latestATSScore,
      reviewCount: reviewCount ?? this.reviewCount,
      lastReviewAt: lastReviewAt ?? this.lastReviewAt,
      isDemoData: isDemoData ?? this.isDemoData,
      parserVersion: parserVersion ?? this.parserVersion,
    );
  }

  bool get hasResume =>
      (downloadUrl != null && downloadUrl!.isNotEmpty) ||
      (storagePath != null && storagePath!.isNotEmpty);

  /// Days since the resume was uploaded (0 when missing/unknown).
  int get resumeAgeInDays {
    final uploaded = uploadedAt;
    if (uploaded == null) return 0;
    return DateTime.now().difference(uploaded).inDays;
  }
}
