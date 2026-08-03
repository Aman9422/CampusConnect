import 'package:campusconnect/models/portfolio/portfolio_model.dart';
import 'package:campusconnect/models/portfolio/resume_metadata.dart';
import 'package:campusconnect/services/firestore/portfolio_service.dart';
import 'package:campusconnect/services/storage/storage_service.dart';
import 'package:flutter/foundation.dart';

/// CampusConnect v8.4 — PortfolioProvider
///
/// Owns the in-memory [PortfolioModel], save state and resume upload logic.
/// Lifecycle mirrors ProfileProvider:
/// - `initWithUser` loads the portfolio for the signed-in student.
/// - `reset` stops all async work after logout (`_isDisposed` guard).
class PortfolioProvider extends ChangeNotifier {
  final PortfolioService _portfolioService;
  final StorageService _storageService;

  PortfolioProvider({
    PortfolioService? service,
    StorageService? storageService,
  }) : _portfolioService = service ?? PortfolioService.instance(),
       _storageService = storageService ?? StorageService.instance();

  // State
  PortfolioModel? _portfolio;
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isSaving = false;
  bool _isUploadingResume = false;
  String? _error;
  bool _isDisposed = false;
  String? _lastUid;

  // Getters
  PortfolioModel? get portfolio => _portfolio;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isSaving => _isSaving;
  bool get isUploadingResume => _isUploadingResume;
  String? get error => _error;
  bool get hasPortfolio => _portfolio != null;

  /// The uid of the user whose portfolio is currently loaded.
  String? get currentUserId => _lastUid;

  /// Initialize provider with the logged-in user's uid.
  ///
  /// L4: the guard is uid-based (`_lastUid`) so a stale early-return can never
  /// serve one user's cached portfolio to a different signed-in user.
  Future<void> initWithUser(String userId) async {
    if (_isInitialized && _lastUid == userId) {
      return;
    }

    _isDisposed = false;
    _lastUid = userId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _portfolio = await _portfolioService.getPortfolio(userId);
      if (_isDisposed) return;
      _isInitialized = true;
      _error = null;
    } catch (e) {
      if (_isDisposed) return;
      _error = 'Failed to load portfolio';
      debugPrint('PortfolioProvider init error: $e');
      _portfolio = PortfolioModel.empty();
      _isInitialized = true;
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Persist the full portfolio under `users/{uid}/portfolio`.
  Future<bool> savePortfolio(PortfolioModel updatedPortfolio) async {
    final uid = _lastUid;
    if (uid == null) return false;

    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      // H4 (F5): pass the current in-memory portfolio as `previous` so the
      // service only writes the sections that actually changed.
      await _portfolioService.savePortfolio(
        uid,
        updatedPortfolio,
        previous: _portfolio,
      );
      if (_isDisposed) return false;
      _portfolio = updatedPortfolio;
      _isSaving = false;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      if (_isDisposed) return false;
      _isSaving = false;
      _error = 'Failed to save portfolio';
      debugPrint('PortfolioProvider save error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Upload a resume PDF to Storage, then persist its metadata in Firestore.
  ///
  /// `filePath` is used on mobile/desktop; `bytes` on web.
  Future<bool> uploadResume({
    required String userId,
    String? filePath,
    Uint8List? bytes,
    required String fileName,
    required int fileLength,
  }) async {
    _isUploadingResume = true;
    _error = null;
    _lastUid = userId;
    notifyListeners();

    try {
      final result = await _storageService.uploadResume(
        uid: userId,
        filePath: filePath,
        bytes: bytes,
        fileName: fileName,
        fileLength: fileLength,
      );
      if (_isDisposed) return false;

      final current = _portfolio ?? PortfolioModel.empty();
      final updated = current.copyWith(
        resume: ResumeMetadata(
          downloadUrl: result.downloadUrl,
          fileName: result.fileName,
          uploadDate: result.uploadDate,
          lastUpdated: result.lastUpdated,
          version: (current.resume?.version ?? 0) + 1,
          atsScore: null,
          parserVersion: null,
        ),
      );

      // H4 (F5): per-section diff — the resume section is the only change.
      await _portfolioService.savePortfolio(
        userId,
        updated,
        previous: current,
      );
      if (_isDisposed) return false;
      _portfolio = updated;
      _isUploadingResume = false;
      _error = null;
      notifyListeners();
      return true;
    } on StorageServiceException catch (e) {
      if (_isDisposed) return false;
      _isUploadingResume = false;
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      if (_isDisposed) return false;
      _isUploadingResume = false;
      _error = 'Failed to upload resume. Please try again.';
      debugPrint('PortfolioProvider upload resume error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Remove the stored resume PDF and clear its metadata.
  Future<bool> deleteResume({required String userId}) async {
    _isSaving = true;
    _error = null;
    _lastUid = userId;
    notifyListeners();

    try {
      await _storageService.deleteResume(userId);
      if (_isDisposed) return false;
      final current = _portfolio ?? PortfolioModel.empty();
      final updated = current.copyWithoutResume();
      // H4 (F5): per-section diff — the resume section is the only change.
      await _portfolioService.savePortfolio(
        userId,
        updated,
        previous: current,
      );
      if (_isDisposed) return false;
      _portfolio = updated;
      _isSaving = false;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      if (_isDisposed) return false;
      _isSaving = false;
      _error = 'Failed to remove resume. Please try again.';
      debugPrint('PortfolioProvider delete resume error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Refresh the portfolio from Firestore (used after remote changes).
  Future<void> refresh() async {
    final uid = _lastUid;
    if (uid == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final fresh = await _portfolioService.getPortfolio(uid);
      if (_isDisposed) return;
      _portfolio = fresh;
      _error = null;
    } catch (e) {
      if (_isDisposed) return;
      _error = 'Failed to refresh portfolio';
      debugPrint('PortfolioProvider refresh error: $e');
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Reset provider (on logout).
  void reset() {
    _isDisposed = true;
    _portfolio = null;
    _isLoading = false;
    _isInitialized = false;
    _isSaving = false;
    _isUploadingResume = false;
    _error = null;
    _lastUid = null;
    notifyListeners();
  }
}
