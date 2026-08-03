import 'package:cloud_firestore/cloud_firestore.dart';

/// CampusConnect v8.4 — Metadata for the uploaded resume PDF.
///
/// Stored under `users/{uid}/portfolio.resume`.
/// `atsScore` starts null (resume parsing belongs to a future version) and
/// `parserVersion` is a placeholder for the parser that will be introduced later.
class ResumeMetadata {
  final String? downloadUrl;
  final String? fileName;
  final DateTime? uploadDate;
  final DateTime? lastUpdated;
  final int version;
  final int? atsScore;
  final String? parserVersion;

  const ResumeMetadata({
    this.downloadUrl,
    this.fileName,
    this.uploadDate,
    this.lastUpdated,
    this.version = 1,
    this.atsScore,
    this.parserVersion,
  });

  factory ResumeMetadata.empty() => const ResumeMetadata();

  factory ResumeMetadata.fromMap(Map<String, dynamic> map) {
    return ResumeMetadata(
      downloadUrl: map['downloadUrl'] as String?,
      fileName: map['fileName'] as String?,
      uploadDate: (map['uploadDate'] as Timestamp?)?.toDate(),
      lastUpdated: (map['lastUpdated'] as Timestamp?)?.toDate(),
      version: map['version'] as int? ?? 1,
      atsScore: map['atsScore'] as int?,
      parserVersion: map['parserVersion'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'downloadUrl': downloadUrl,
      'fileName': fileName,
      'uploadDate': uploadDate != null ? Timestamp.fromDate(uploadDate!) : null,
      'lastUpdated':
          lastUpdated != null ? Timestamp.fromDate(lastUpdated!) : null,
      'version': version,
      'atsScore': atsScore,
      'parserVersion': parserVersion,
    };
  }

  ResumeMetadata copyWith({
    String? downloadUrl,
    String? fileName,
    DateTime? uploadDate,
    DateTime? lastUpdated,
    int? version,
    int? atsScore,
    String? parserVersion,
  }) {
    return ResumeMetadata(
      downloadUrl: downloadUrl ?? this.downloadUrl,
      fileName: fileName ?? this.fileName,
      uploadDate: uploadDate ?? this.uploadDate,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      version: version ?? this.version,
      atsScore: atsScore ?? this.atsScore,
      parserVersion: parserVersion ?? this.parserVersion,
    );
  }

  bool get hasResume => downloadUrl != null && downloadUrl!.isNotEmpty;
}
