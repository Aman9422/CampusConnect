import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// CampusConnect v8.4 — StorageService
///
/// Handles resume PDF upload/delete in Firebase Storage.
///
/// Files are stored at `resumes/{uid}/resume.pdf`. A new upload always
/// overwrites the existing file (resume versioning is out of scope for v8.4).
class StorageService {
  final FirebaseStorage _storage;

  StorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  static final StorageService _instance = StorageService();
  factory StorageService.instance() => _instance;

  /// Maximum accepted resume size — 5 MB.
  static const int maxResumeBytes = 5 * 1024 * 1024;

  static const String resumeFileName = 'resume.pdf';

  /// v8.4 storage layout: `resumes/{uid}/resume.pdf`
  String resumePath(String uid) => 'resumes/$uid/$resumeFileName';

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

  /// Uploads a resume PDF to `resumes/{uid}/resume.pdf`.
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

    final ref = _storage.ref(resumePath(uid));
    final metadata = SettableMetadata(
      contentType: 'application/pdf',
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
        final path = filePath;
        if (path == null || path.isEmpty) {
          throw const StorageServiceException(
            'Could not read the selected file.',
          );
        }
        await ref.putFile(File(path), metadata);
      }

      final downloadUrl = await ref.getDownloadURL();
      final now = DateTime.now();
      return ResumeUploadResult(
        downloadUrl: downloadUrl,
        fileName: resumeFileName,
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
}

/// Result of a successful resume upload.
class ResumeUploadResult {
  final String downloadUrl;
  final String fileName;
  final DateTime uploadDate;
  final DateTime lastUpdated;
  final String? parserVersion;

  const ResumeUploadResult({
    required this.downloadUrl,
    required this.fileName,
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
