import 'package:campusconnect/models/portfolio/portfolio_model.dart';

/// v9.2.7 — A portfolio read/listener result paired with the two Firestore
/// snapshot flags the provider needs.
///
/// The portfolio listeners used to consume a bare [PortfolioModel], which
/// erased the distinction between a value the SERVER confirmed and a value
/// replayed from the device's local cache. That distinction is the whole
/// "upload/remove succeeded but the old resume came back" story:
///
///  * the Firestore SDK replays its last cached document — for example the
///    snapshot taken BEFORE an upload/remove landed, or a pre-logout state —
///    as a normal event, so a bare model could not be told apart from server
///    truth, and
///  * the provider's stale-guards then had to guess, and one of those guesses
///    ("resume present in memory ⇒ drop every event that lacks it") could lock
///    a removed resume back into the UI permanently.
///
/// Carrying [isFromCache] lets the listener apply the simple, correct rule
/// instead: a cache-sourced snapshot may bootstrap empty state, but it may
/// never overwrite a value the client already holds.
class PortfolioSnapshot {
  const PortfolioSnapshot({
    required this.portfolio,
    required this.isFromCache,
    required this.hasPendingWrites,
  });

  /// The parsed portfolio carried by the snapshot.
  final PortfolioModel portfolio;

  /// True when the snapshot came from the local cache rather than the server,
  /// i.e. it may predate the most recent server write.
  final bool isFromCache;

  /// True while this client still has an unacknowledged write reflected in
  /// this snapshot.
  final bool hasPendingWrites;

  @override
  String toString() =>
      'PortfolioSnapshot(fromCache: $isFromCache, '
      'pendingWrites: $hasPendingWrites, empty: ${portfolio.isEmpty})';
}
