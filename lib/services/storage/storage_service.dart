import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// CampusConnect v8.4.1 — StorageService
///
/// Handles resume PDF upload/delete in Firebase Storage.
///
/// Files are stored at `resumes/{uid}/latest.pdf` (docs/Task.md Phase 1).
/// A new upload always overwrites the existing file (resume versioning is out
/// of scope for v8.4; the future `history/` layout is a sibling folder).
class StorageService {
  final FirebaseStorage _storage;

  StorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  static final StorageService _instance = StorageService();
  factory StorageService.instance() => _instance;

  /// Maximum accepted resume size — 5 MB.
  static const int maxResumeBytes = 5 * 1024 * 1024;

  /// v8.4.1: storage layout follows the spec — `resumes/{uid}/latest.pdf`.
  static const String resumeFileName = 'latest.pdf';

  static const String resumeMimeType = 'application/pdf';

  /// v8.4 storage layout: `resumes/{uid}/latest.pdf`
  String resumePath(String uid) => 'resumes/$uid/$resumeFileName';

  /// Future-ready version-history path: `resumes/{uid}/history/v{n}.pdf`.
  String resumeHistoryPath(String uid, int version) =>
      'resumes/$uid/history/v$version.pdf';

  /// Validates that a picked file is a PDF and within the size limit.
  /// Returns an error message, or null when the file is valid.
  static String? validateResumeFile({
    required String fileName,
    required int length,
  }) {
    if (length <= 0) {
      return 'The selected file is empty.';
    }
    if (length > maxResumeBytes) {
      return 'Maximum resume size is 5 MB. Please upload a smaller file.';
    }
    if (!fileName.toLowerCase().endsWith('.pdf')) {
      return 'Only PDF files are allowed. Please select a .pdf resume.';
    }
    return null;
  }

  /// Uploads a resume PDF to `resumes/{uid}/latest.pdf`.
  ///
  /// On web, pass `bytes` (from `PlatformFile.bytes`). On mobile/desktop
  /// pass `filePath` of the picked file. Returns the upload result metadata.
  Future<ResumeUploadResult> uploadResume({
    required String uid,
    String? filePath,
    Uint8List? bytes,
    required String fileName,
    required int fileLength,
  }) async {
    final validationError = validateResumeFile(
      fileName: fileName,
      length: fileLength,
    );
    if (validationError != null) {
      throw StorageServiceException(validationError);
    }

    final path = resumePath(uid);
    final ref = _storage.ref(path);
    final metadata = SettableMetadata(
      contentType: resumeMimeType,
      customMetadata: {'uid': uid},
    );

    try {
      if (kIsWeb) {
        final data = bytes ?? Uint8List(0);
        if (data.isEmpty) {
          throw const StorageServiceException(
            'Could not read the selected file.',
          );
        }
        await ref.putData(data, metadata);
      } else {
        final pickedPath = filePath;
        if (pickedPath == null || pickedPath.isEmpty) {
          throw const StorageServiceException(
            'Could not read the selected file.',
          );
        }
        await ref.putFile(File(pickedPath), metadata);
      }

      final downloadUrl = await ref.getDownloadURL();
      final now = DateTime.now();
      return ResumeUploadResult(
        downloadUrl: downloadUrl,
        storagePath: path,
        fileName: fileName, // T1: preserve the original picked name.
        fileSize: fileLength,
        mimeType: resumeMimeType,
        uploadDate: now,
        lastUpdated: now,
        parserVersion: null,
      );
    } on StorageServiceException {
      rethrow;
    } catch (e) {
      debugPrint('StorageService: Error uploading resume: $e');
      throw const StorageServiceException(
        'Failed to upload resume. Please try again.',
      );
    }
  }

  /// Deletes the resume PDF from Storage. Safe to call when no resume exists.
  Future<void> deleteResume(String uid) async {
    try {
      await _storage.ref(resumePath(uid)).delete();
    } catch (e) {
      if (e is FirebaseException && e.code == 'object-not-found') {
        return; // Nothing to delete — not an error.
      }
      debugPrint('StorageService: Error deleting resume: $e');
      rethrow;
    }
  }

  /// Resolves a download URL from an arbitrary storage [path].
  ///
  /// Used by [ResumeService.getResumeUrl] for documents that only stored a
  /// storage path. Throws on failure so callers can surface a real error.
  Future<String> downloadUrlFromPath(String path) async {
    try {
      return await _storage.ref(path).getDownloadURL();
    } catch (e) {
      debugPrint('StorageService: Error resolving download URL: $e');
      rethrow;
    }
  }

  /// Downloads the object at [path] into memory.
  ///
  /// Used by [ResumeService.downloadResume] for the "Download Resume" action.
  Future<Uint8List> downloadBytes(String path) async {
    try {
      final data = await _storage.ref(path).getData();
      if (data == null || data.isEmpty) {
        throw const StorageServiceException(
          'Could not read the resume file.',
        );
      }
      return data;
    } on StorageServiceException {
      rethrow;
    } catch (e) {
      debugPrint('StorageService: Error downloading bytes: $e');
      throw const StorageServiceException(
        'Failed to download resume. Please try again.',
      );
    }
  }
}

/// Result of a successful resume upload.
class ResumeUploadResult {
  final String downloadUrl;
  /// Full storage path of the uploaded file — `resumes/{uid}/latest.pdf`.
  final String storagePath;
  /// Original file name selected by the user (e.g. `aman_resume.pdf`).
  final String fileName;
  final int fileSize;
  final String mimeType;
  final DateTime uploadDate;
  final DateTime lastUpdated;
  final String? parserVersion;

  const ResumeUploadResult({
    required this.downloadUrl,
    required this.storagePath,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    required this.uploadDate,
    required this.lastUpdated,
    this.parserVersion,
  });
}

/// Storage operation failure with a user-facing message.
class StorageServiceException implements Exception {
  final String message;
  const StorageServiceException(this.message);

  @override
  String toString() => message;
}
