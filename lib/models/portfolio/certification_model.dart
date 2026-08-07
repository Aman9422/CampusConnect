import 'package:campusconnect/models/portfolio/portfolio_parse.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// CampusConnect v8.4 — Student portfolio certification entry.
class CertificationModel {
  final String id;
  final String title;
  final String issuer;
  final DateTime? issueDate;
  final String? credentialId;
  final String? credentialUrl;

  const CertificationModel({
    required this.id,
    required this.title,
    this.issuer = '',
    this.issueDate,
    this.credentialId,
    this.credentialUrl,
  });

  factory CertificationModel.empty() {
    return CertificationModel(id: '', title: '');
  }

  factory CertificationModel.fromMap(Map<String, dynamic> map) {
    // v8.4.7: tolerant reads — dates may arrive as Timestamp, DateTime or
    // ISO-8601 String; never throws; bad fields degrade to defaults.
    return CertificationModel(
      id: asString(map['id']) ?? '',
      title: asString(map['title']) ?? '',
      issuer: asString(map['issuer']) ?? '',
      issueDate: tsToDate(map['issueDate']),
      credentialId: asString(map['credentialId']),
      credentialUrl: asString(map['credentialUrl']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'issuer': issuer,
      'issueDate': issueDate != null ? Timestamp.fromDate(issueDate!) : null,
      'credentialId': credentialId,
      'credentialUrl': credentialUrl,
    };
  }

  CertificationModel copyWith({
    String? id,
    String? title,
    String? issuer,
    DateTime? issueDate,
    String? credentialId,
    String? credentialUrl,
  }) {
    return CertificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      issuer: issuer ?? this.issuer,
      issueDate: issueDate ?? this.issueDate,
      credentialId: credentialId ?? this.credentialId,
      credentialUrl: credentialUrl ?? this.credentialUrl,
    );
  }

  /// True when the entry has no meaningful content.
  bool get isEmpty => title.trim().isEmpty && issuer.trim().isEmpty;
}
