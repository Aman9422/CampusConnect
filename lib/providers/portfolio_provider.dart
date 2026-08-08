import 'dart:async';

import 'package:campusconnect/models/portfolio/portfolio_model.dart';
import 'package:campusconnect/services/firestore/portfolio_service.dart';
import 'package:campusconnect/services/firestore/resume_service.dart';
import 'package:campusconnect/services/portfolio_cache_service.dart';
import 'package:flutter/foundation.dart';

/// CampusConnect v8.4.3 (MB2/MB3) — PortfolioProvider
///
/// Owns the in-memory [PortfolioModel], save state and resume upload logic.
///
/// v8.4.3 fixes (manual-test pass, Bugs 1/2/3):
/// - **Offline-first**: `initWithUser` subscribes to
///   [PortfolioService.portfolioStream] so memory converges with the server
///   instead of depending on a one-shot `get()` (Bug 1 — resume vanishing
///   after refresh when a write/read races a network flap).
/// - **Last-known-good**: a stream error or failed refresh never clears
///   `_portfolio`; the last good value is kept and `_error` is surfaced
///   (Bug 3 — wipe-on-logout).
/// - **Local cache**: every successful read/write snapshots the portfolio to
///   SharedPreferences via [PortfolioCacheService]; `initWithUser` restores
///   that snapshot before the first stream event so logout/re-login never
///   shows an empty portfolio (Bug 3).
/// - **No disposed-drop of persisted data**: `uploadResume`/`deleteResume`
///   commit the new in-memory state before checking `_isDisposed` — the data
///   is already persisted by that point (Bug 3).
/// - **Bounded saves**: `savePortfolio` runs under a [saveTimeout] so a hung
///   Firestore write (UNAVAILABLE keepalive) surfaces an error instead of an
///   infinite spinner (Bug 2).
///
/// v8.4.4 fix (Bugs 1/3 on-device re-verification — "upload says success but
/// the dashboard still shows the No Resume placeholder"):
/// - **Stale-stream guard**: `portfolioStream` emits `PortfolioModel.empty()`
///   whenever a snapshot has no `portfolio` key — which is exactly what the
///   Firestore SDK replays from the local cache (a snapshot taken BEFORE the
///   upload write landed) when the app returns from the document picker or
///   after a network flap. The listener used to assign it unconditionally,
///   clobbering the resume `uploadResume` just committed to memory. The
///   dashboard card therefore showed "No Resume" even though Firestore had
///   the resume and the snackbar said "Resume uploaded successfully!".
///   Now a stream event can never replace a newer in-memory value: events
///   arriving while a local write is in flight are ignored, empty events
///   never overwrite a non-empty portfolio, and an event that drops the
///   resume while memory still has one is ignored. Deletes still surface
///   because `deleteResume`/`reset` set `_portfolio` themselves first.
///
/// v8.4.1 behaviour preserved: resume upload/delete delegate to
/// [ResumeService] (per-section diff), `initWithUser` is uid-guarded.
class PortfolioProvider extends ChangeNotifier {
  final PortfolioService _portfolioService;
  final ResumeService _resumeService;
  final PortfolioCacheService _cacheService;

  /// Cap on a single portfolio save before it is treated as hung.
  static const Duration saveTimeout = Duration(seconds: 20);

  PortfolioProvider({
    PortfolioService? service,
    ResumeService? resumeService,
    PortfolioCacheService? cacheService,
  }) : _portfolioService = service ?? PortfolioService.instance(),
       _resumeService =
           resumeService ??
           ResumeService(
             portfolioService: service ?? PortfolioService.instance(),
           ),
       _cacheService = cacheService ?? PortfolioCacheService.instance();

  // State
  PortfolioModel? _portfolio;
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isSaving = false;
  bool _isUploadingResume = false;
  String? _error;
  bool _isDisposed = false;
  String? _lastUid;
  StreamSubscription<PortfolioModel>? _streamSubscription;

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
  ///
  /// v8.4.3 (MB2): loads the SharedPreferences snapshot immediately (so a
  /// previous session's data is visible before the first stream event), then
  /// subscribes to `portfolioStream` for live convergence. A first-time user
  /// with no cached portfolio still reads through the stream's initial event.
  Future<void> initWithUser(String userId) async {
    if (_isInitialized && _lastUid == userId) {
      return;
    }

    _cancelStream();
    _isDisposed = false;
    _lastUid = userId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Restore last-known-good from local cache (offline-first bootstrap).
      if (_portfolio == null) {
        final cached = await _cacheService.restore(userId);
        if (_isDisposed) return;
        if (cached != null && !cached.isEmpty) {
          _portfolio ??= cached;
        }
      }

      // Subscribe to the live stream — replaces the one-shot get().
      _listenToPortfolio(userId);

      // Prime `_portfolio` from the server when no cache existed yet. The
      // stream also emits immediately, but this guarantees a value even if
      // the stream races a dispose.
      if (_portfolio == null) {
        try {
          final fresh = await _portfolioService.getPortfolio(userId);
          if (_isDisposed) return;
          _portfolio = fresh;
          await _cacheService.cache(userId, fresh);
        } catch (e) {
          // v8.4.8 (MB12): a failed one-shot read must surface the error.
          // Previously this path fell back to `PortfolioModel.empty()` WITHOUT
          // setting `_error`, so the v8.4.7 banner never fired and a failed
          // startup read rendered as "a newly initiated portfolio at 10%
          // strength" with no banner — Symptom 1's exact UI. Set `_error`
          // whenever we fall back to empty so the banner surfaces "present
          // but failed to load" instead of silently masquerading as a fresh
          // portfolio. A cached portfolio (restored above) is still kept.
          debugPrint('PortfolioProvider init one-shot read failed: $e');
          if (_portfolio == null) {
            _portfolio = PortfolioModel.empty();
            _error = 'Failed to load portfolio';
          }
        }
      }

      if (_isDisposed) return;
      _isInitialized = true;
      // MB12: do NOT clear `_error` here — a failed one-shot read (inner
      // catch above) must keep its error so the v8.4.7 banner surfaces
      // "present but failed to load" rather than a silent fresh portfolio.
      // `_error` was already reset at the top of this method; the stream
      // listener clears it again once a real event arrives.
    } catch (e) {
      if (_isDisposed) return;
      _error = 'Failed to load portfolio';
      debugPrint('PortfolioProvider init error: $e');
      _portfolio ??= PortfolioModel.empty();
      _isInitialized = true;
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Subscribes to the portfolio stream so server + memory stay converged.
  ///
  /// v8.4.4 (Bugs 1/3 re-verified): stream events are applied ONLY when they
  /// are at least as new as the in-memory state. Every write path
  /// (`uploadResume`/`deleteResume`/`savePortfolio`) commits to memory before
  /// it returns, so an event that would REMOVE data we just committed is by
  /// definition stale — either a local-cache replay of the pre-write document
  /// (fired when the app returns from the document picker or after a network
  /// flap) or the initial empty snapshot racing a completed upload. Applying
  /// it made the dashboard placeholder show "No Resume" despite a successful
  /// upload and a resume present in Firestore.
  void _listenToPortfolio(String userId) {
    _streamSubscription = _portfolioService.portfolioStream(userId).listen(
      (fresh) async {
        if (_isDisposed || _lastUid != userId) return;

        // 1) A local write is in flight — the in-memory result is the
        //    authoritative value until the server confirms; the confirmed
        //    event arrives after and is applied below.
        if (_isUploadingResume || _isSaving) return;

        final current = _portfolio;

        // 2) Never let an empty stream event wipe a portfolio we already
        //    hold. `PortfolioModel.empty()` means "snapshot had no
        //    portfolio key" — the signature of a stale pre-write replay or a
        //    first-time-user snapshot. A real clear goes through
        //    deleteResume/reset, which set `_portfolio` themselves.
        if (fresh.isEmpty && current != null && !current.isEmpty) return;

        // 3) Never let a stream event drop the resume while memory still has
        //    one — covers a stale non-empty snapshot (portfolio sections
        //    without the just-uploaded resume) racing the upload.
        if (current?.resume?.hasResume == true &&
            fresh.resume?.hasResume != true) {
          return;
        }

        _portfolio = fresh;
        _error = null;
        notifyListeners();
        // Best-effort local snapshot — never blocks the UI.
        unawaited(_cacheService.cache(userId, fresh));
      },
      onError: (Object e) {
        if (_isDisposed || _lastUid != userId) return;
        // MB2: keep last-known-good; only surface the error, never clear data.
        _error = 'Portfolio updates are temporarily unavailable';
        debugPrint('PortfolioProvider stream error: $e');
        notifyListeners();
      },
    );
  }

  void _cancelStream() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
  }

  /// Persist the full portfolio under `users/{uid}/portfolio`.
  ///
  /// v8.4.3 (MB3): wrapped in a bounded [saveTimeout] so a hung Firestore
  /// write can never leave the UI in a permanent spinner, and state flags are
  /// reset in `finally`.
  Future<bool> savePortfolio(PortfolioModel updatedPortfolio) async {
    final uid = _lastUid;
    if (uid == null) return false;

    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      // H4 (F5): pass the current in-memory portfolio as `previous` so the
      // service only writes the sections that actually changed.
      await _portfolioService
          .savePortfolio(uid, updatedPortfolio, previous: _portfolio)
          .timeout(saveTimeout);
      if (_isDisposed) return false;
      _portfolio = updatedPortfolio;
      _error = null;
      // MB2: keep the local cache converged with what the user just saved.
      await _cacheService.cache(uid, updatedPortfolio);
      return true;
    } catch (e) {
      if (_isDisposed) return false;
      _error = e is TimeoutException
          ? 'Save timed out. Check your connection and try again.'
          : 'Failed to save portfolio';
      debugPrint('PortfolioProvider save error: $e');
      return false;
    } finally {
      if (!_isDisposed) {
        _isSaving = false;
        notifyListeners();
      }
    }
  }

  /// Upload a resume PDF to Storage, then persist its metadata in Firestore.
  ///
  /// `filePath` is used on mobile/desktop; `bytes` on web.
  /// T2: delegates to `ResumeService.uploadResume` (per-section diff).
  /// MB3: the in-memory state is committed BEFORE the `_isDisposed` check —
  /// by the time this returns the data is already persisted, so a logout
  /// racing the upload must not drop it from memory.
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
      final updated = await _resumeService.uploadResume(
        uid: userId,
        filePath: filePath,
        bytes: bytes,
        fileName: fileName,
        fileLength: fileLength,
        previousPortfolio: _portfolio,
      );
      // Commit to memory first — the data is already on the server.
      _portfolio = updated;
      await _cacheService.cache(userId, updated);
      if (_isDisposed) return false;
      _error = null;
      return true;
    } catch (e) {
      if (_isDisposed) return false;
      _error = _friendlyError(e);
      debugPrint('PortfolioProvider upload resume error: $e');
      return false;
    } finally {
      if (!_isDisposed) {
        _isUploadingResume = false;
        notifyListeners();
      }
    }
  }

  /// Remove the stored resume PDF and clear its metadata.
  ///
  /// T2: delegates to `ResumeService.deleteResume` (per-section diff).
  Future<bool> deleteResume({required String userId}) async {
    _isSaving = true;
    _error = null;
    _lastUid = userId;
    notifyListeners();

    try {
      final updated = await _resumeService.deleteResume(
        uid: userId,
        previousPortfolio: _portfolio,
      );
      // Commit to memory first — the data is already on the server.
      _portfolio = updated;
      await _cacheService.cache(userId, updated);
      if (_isDisposed) return false;
      _error = null;
      return true;
    } catch (e) {
      if (_isDisposed) return false;
      _error = 'Failed to remove resume. Please try again.';
      debugPrint('PortfolioProvider delete resume error: $e');
      return false;
    } finally {
      if (!_isDisposed) {
        _isSaving = false;
        notifyListeners();
      }
    }
  }

  /// Refresh the portfolio from Firestore (used after remote changes).
  ///
  /// v8.4.3 (MB2): a failed refresh keeps the last-known-good `_portfolio`
  /// and only sets `_error` — it never silently replaces data with an empty
  /// portfolio (Bug 1/3 root cause).
  ///
  /// v8.4.8 (MB11): `refresh()` now applies the SAME stale-guards as the
  /// stream listener (v8.4.4). Previously a single `getPortfolio()` returning
  /// `PortfolioModel.empty()` (doc missing / `portfolio` key missing /
  /// transient failure) unconditionally overwrote the just-uploaded resume in
  /// memory AND overwrote the SharedPreferences cache with the empty result —
  /// the exact mechanism of "upload → visible → pull-to-refresh → wiped".
  /// - If a local write is in flight, the in-memory result is authoritative,
  ///   so the refresh result is skipped entirely.
  /// - An `empty` fresh result never wipes a non-empty `_portfolio`.
  /// - A fresh result that drops the resume while memory still has one is
  ///   ignored (stale pre-write snapshot racing a completed upload).
  /// - The local cache is only re-written when the fresh value actually
  ///   replaces memory, so an ignored stale/empty result cannot poison the
  ///   SharedPreferences snapshot that restores state after re-login.
  Future<void> refresh() async {
    final uid = _lastUid;
    if (uid == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final fresh = await _portfolioService.getPortfolio(uid);
      if (_isDisposed) return;

      // 1) A local write is in flight — the in-memory result is authoritative
      //    until the server confirms; the confirmed stream event arrives
      //    after and is applied by the listener.
      if (_isUploadingResume || _isSaving) return;

      final current = _portfolio;

      // 2) Never let an empty read wipe a portfolio we already hold
      //    (`getPortfolio` returns empty when the doc or `portfolio` key is
      //    missing — a signature of a stale cache replay or a first-time
      //    user, not of data deletion).
      if (fresh.isEmpty && current != null && !current.isEmpty) return;

      // 3) Never let a refresh drop the resume while memory still has one —
      //    covers a stale non-empty snapshot (sections without the
      //    just-uploaded resume) racing the upload.
      if (current?.resume?.hasResume == true && fresh.resume?.hasResume != true) {
        return;
      }

      _portfolio = fresh;
      _error = null;
      // Only re-cache when the fresh value actually replaced memory.
      await _cacheService.cache(uid, fresh);
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
  ///
  /// Cancels the stream subscription so no late stream event can resurrect
  /// state after the user signs out. The SharedPreferences snapshot is kept
  /// (per-user key) so the next login restores the last-known-good portfolio.
  void reset() {
    _cancelStream();
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

  /// Maps a caught exception to a user-facing message. Storage validation
  /// errors (file too large / wrong type / timeouts) carry their own message.
  String _friendlyError(Object e) {
    final message = e.toString();
    if (message.contains('Maximum resume size') ||
        message.contains('Only PDF files') ||
        message.contains('empty') ||
        message.contains('timed out')) {
      return message;
    }
    return 'Failed to upload resume. Please try again.';
  }
}
