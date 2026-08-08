import 'dart:async';

import 'package:campusconnect/models/portfolio/portfolio_model.dart';
import 'package:campusconnect/models/portfolio/resume_metadata.dart';
import 'package:campusconnect/services/firestore/portfolio_service.dart';
import 'package:campusconnect/services/storage/storage_service.dart';
import 'package:flutter/foundation.dart';

/// CampusConnect v8.4.1 — ResumeService (docs/Task.md Phase 4).
///
/// Orchestrates the resume lifecycle end-to-end:
///
/// 1. Storage operations (upload / download / delete / URL) are delegated to
///    [StorageService] at `resumes/{uid}/latest.pdf`.
/// 2. Metadata lives in the portfolio nested map (`users/{uid}/portfolio.resume`)
///    and is written through [PortfolioService] as a per-section diff — the
///    H4/F5 behaviour is preserved, so sibling sections (skills, projects, …)
///    are never clobbered by a resume update.
///
/// Widgets and providers depend on this facade instead of calling the two
/// services directly — business logic stays out of the UI.
///
/// NOTE: version history storage (`resumes/{uid}/history/v{n}.pdf`) is a
/// future-version feature; [historyPath] is provided now for forward
/// compatibility (v8.5 Resume Versioning).
class ResumeService {
  final PortfolioService _portfolioService;
  final StorageService _storageService;

  ResumeService({
    PortfolioService? portfolioService,
    StorageService? storageService,
  }) : _portfolioService = portfolioService ?? PortfolioService.instance(),
       _storageService = storageService ?? StorageService.instance();

  static final ResumeService _instance = ResumeService();
  factory ResumeService.instance() => _instance;

  /// Uploads a resume PDF and persists its metadata.
  ///
  /// Uses the same platform split as StorageService: `filePath` on
  /// mobile/desktop, `bytes` on web. The metadata is written as a per-section
  /// diff (previous portfolio passed as `previous`) so other portfolio
  /// sections are left untouched.
  ///
  /// Returns the new [PortfolioModel] carrying the uploaded resume metadata.
  /// Throws [StorageServiceException] for validation/storage failures and
  /// rethrows Firestore errors so the caller can surface a meaningful error.
  Future<PortfolioModel> uploadResume({
    required String uid,
    String? filePath,
    Uint8List? bytes,
    required String fileName,
    required int fileLength,
    PortfolioModel? previousPortfolio,
  }) async {
    final result = await _storageService.uploadResume(
      uid: uid,
      filePath: filePath,
      bytes: bytes,
      fileName: fileName,
      fileLength: fileLength,
    );

    final current = previousPortfolio ?? PortfolioModel.empty();
    final updated = current.copyWith(
      resume: ResumeMetadata(
        downloadUrl: result.downloadUrl,
        storagePath: result.storagePath,
        fileName: result.fileName,
        fileSize: result.fileSize,
        mimeType: result.mimeType,
        uploadedAt: result.uploadDate,
        updatedAt: result.lastUpdated,
        version: (current.resume?.version ?? 0) + 1,
        latestATSScore: null,
        parserVersion: null,
      ),
    );

    await _portfolioService
        .savePortfolio(uid, updated, previous: current)
        .timeout(PortfolioService.saveTimeout);
    return updated;
  }

  /// Deletes the stored resume PDF and clears its metadata from the portfolio.
  ///
  /// Safe to call when no resume exists (StorageService tolerates a missing
  /// object). The metadata clear is a per-section diff.
  Future<PortfolioModel> deleteResume({
    required String uid,
    PortfolioModel? previousPortfolio,
  }) async {
    await _storageService.deleteResume(uid);

    final current = previousPortfolio ?? PortfolioModel.empty();
    final updated = current.copyWithoutResume();
    // v8.4.10: bound the metadata write like the upload path — a hung
    // Firestore write must never leave the Remove button spinning forever.
    await _portfolioService
        .savePortfolio(uid, updated, previous: current)
        .timeout(PortfolioService.saveTimeout);
    return updated;
  }

  /// Reads the resume metadata for a user.
  ///
  /// Returns null when the portfolio or resume section is missing. Real
  /// errors (permission/network) are rethrown — the caller decides how to
  /// surface them (mirrors F9 behaviour in PortfolioService.getPortfolio).
  Future<ResumeMetadata?> readMetadata(String uid) async {
    final portfolio = await _portfolioService.getPortfolio(uid);
    final resume = portfolio.resume;
    if (resume == null || !resume.hasResume) return null;
    return resume;
  }

  /// True when the user has a resume stored.
  Future<bool> checkResumeExists(String uid) async {
    final metadata = await readMetadata(uid);
    return metadata != null;
  }

  /// Resolves the downloadable URL for the user's resume.
  ///
  /// Prefers the cached Firestore download URL; falls back to resolving the
  /// Storage reference when the URL is absent (e.g. legacy documents that
  /// only stored `storagePath`). Returns null when no resume exists.
  Future<String?> getResumeUrl(String uid) async {
    final metadata = await readMetadata(uid);
    if (metadata == null) return null;
    if (metadata.downloadUrl != null && metadata.downloadUrl!.isNotEmpty) {
      return metadata.downloadUrl;
    }
    if (metadata.storagePath != null && metadata.storagePath!.isNotEmpty) {
      return _storageService.downloadUrlFromPath(metadata.storagePath!);
    }
    return null;
  }

  /// Downloads the resume bytes for a user.
  ///
  /// Returns null when no resume exists. Throws on storage failures so the
  /// caller can surface a meaningful error.
  Future<Uint8List?> downloadResume(
    String uid, {
    String? storagePath,
  }) async {
    final path = storagePath ?? _storageService.resumePath(uid);
    try {
      final data = await _storageService.downloadBytes(path);
      return data;
    } on StorageServiceException {
      rethrow;
    } catch (e) {
      debugPrint('ResumeService: Error downloading resume: $e');
      rethrow;
    }
  }

  /// Future-ready version-history path helper (v8.5 Resume Versioning).
  String historyPath(String uid, int version) =>
      _storageService.resumeHistoryPath(uid, version);
}
