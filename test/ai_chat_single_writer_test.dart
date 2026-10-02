import 'dart:io';

import 'package:campusconnect/models/ai_interaction.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// CampusConnect v9.2.4 (D-7) — AI chat single-writer contract tests.
///
/// The v9.2.3 audit found that `users/{uid}/ai_interactions` had **two
/// independent writers with two different schemas**:
///
/// * the server (`functions/ai/chat.js::askAI`) wrote one document per turn —
///   `{ role, message, timestamp }` (two documents per exchange);
/// * the Flutter client (`AIChatProvider._saveInteraction` →
///   `AIInteraction.toFirestore`) wrote a **third** document per exchange with
///   `{ prompt, response, intent, createdAt, metadata }`.
///
/// Consequences: three writes per message; the client's history loader ordered
/// by `createdAt` and so could never see the server's documents; and the
/// retention sweep in `functions/ai/chatDelete.js` (which filters on
/// `timestamp`) could never see the client's — two rows for one history with
/// different lifetimes and different visibility.
///
/// The fix: the server is the single writer, `AIInteraction.toFirestore` and
/// `_saveInteraction` are gone, and there is exactly one timestamp field —
/// `timestamp` — agreed by writer, reader and retention sweep.
///
/// This suite has two halves:
///  - **behavioural** — the model parses the server schema, tolerantly, via
///    `AIInteraction.fromMap` (a pure function; `DocumentSnapshot` is sealed
///    and cannot be faked in a `flutter test` process);
///  - **source contract** — the removed writer cannot quietly come back, and
///    writer / reader / retention sweep still agree on `timestamp`.
void main() {
  group('AIInteraction parses the SERVER schema', () {
    test('a user turn is read as a user turn', () {
      final interaction = AIInteraction.fromMap(
        id: 'doc_1',
        data: {
          'role': 'user',
          'message': 'How do I improve my resume?',
          'timestamp': Timestamp.fromDate(DateTime(2026, 3, 1, 10, 0)),
          'status': 'processed',
        },
      );

      expect(interaction.id, 'doc_1');
      expect(interaction.role, AIChatRole.user);
      expect(interaction.isUserTurn, isTrue);
      expect(interaction.message, 'How do I improve my resume?');
      expect(interaction.timestamp, DateTime(2026, 3, 1, 10, 0));
      expect(interaction.status, 'processed');
      expect(interaction.isAIResponse, isFalse);
    });

    test('an assistant turn is read as an assistant turn', () {
      final interaction = AIInteraction.fromMap(
        id: 'doc_2',
        data: {
          'role': 'assistant',
          'message': 'Add measurable outcomes to each bullet.',
          'timestamp': Timestamp.fromDate(DateTime(2026, 3, 1, 10, 0, 3)),
          'isAIResponse': true,
          'status': 'delivered',
        },
      );

      expect(interaction.role, AIChatRole.assistant);
      expect(interaction.isUserTurn, isFalse);
      expect(interaction.isAIResponse, isTrue);
      expect(interaction.message, 'Add measurable outcomes to each bullet.');
      expect(interaction.status, 'delivered');
    });

    test('one exchange is exactly TWO documents sharing the ordering field',
        () {
      // The single writer emits one document per turn; the transcript is
      // rebuilt from these two rows and no more.
      final sharedMoment = DateTime(2026, 3, 1, 10, 0);
      final userTurn = AIInteraction.fromMap(
        id: 't1',
        data: {
          'role': 'user',
          'message': 'hi',
          'timestamp': Timestamp.fromDate(sharedMoment),
        },
      );
      final assistantTurn = AIInteraction.fromMap(
        id: 't2',
        data: {
          'role': 'assistant',
          'message': 'hello',
          'timestamp': Timestamp.fromDate(sharedMoment),
        },
      );

      expect([userTurn.isUserTurn, assistantTurn.isUserTurn], [true, false]);
      // Both rows carry the SAME ordering field, which is what makes a single
      // `orderBy('timestamp')` query sufficient — no second field to keep in
      // sync.
      expect(userTurn.timestamp, assistantTurn.timestamp);
    });

    test('a document from the REMOVED client schema is not translated', () {
      // `prompt`/`response`/`intent`/`createdAt` are not read, so a legacy row
      // degrades to an empty assistant turn (and is skipped by the loader)
      // rather than pretending to be a real exchange. The canonical row set is
      // the server's.
      final legacy = AIInteraction.fromMap(
        id: 'legacy',
        data: {
          'prompt': 'old question',
          'response': 'old answer',
          'intent': 'general',
          'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
        },
      );

      expect(legacy.message, isEmpty);
      expect(legacy.role, AIChatRole.assistant);
      expect(legacy.isUserTurn, isFalse);
      expect(legacy.isAIResponse, isFalse);
    });
  });

  group('AIChatRole.fromFirestoreValue — never render an unknown turn as the '
      'student', () {
    test('"user" maps to user, everything else to assistant', () {
      expect(AIChatRole.fromFirestoreValue('user'), AIChatRole.user);
      expect(AIChatRole.fromFirestoreValue('assistant'), AIChatRole.assistant);
      expect(AIChatRole.fromFirestoreValue(null), AIChatRole.assistant);
      expect(AIChatRole.fromFirestoreValue('SYSTEM'), AIChatRole.assistant);
      expect(AIChatRole.fromFirestoreValue(42), AIChatRole.assistant);
      expect(AIChatRole.fromFirestoreValue(''), AIChatRole.assistant);
    });
  });

  group('AIInteraction tolerates partial documents', () {
    test('a missing message degrades to an empty string', () {
      final interaction = AIInteraction.fromMap(
        id: 'doc',
        data: {'role': 'user'},
      );
      expect(interaction.message, isEmpty);
      expect(interaction.status, isEmpty);
      expect(interaction.isAIResponse, isFalse);
      expect(interaction.role, AIChatRole.user);
    });

    test('a missing timestamp falls back instead of throwing', () {
      final interaction = AIInteraction.fromMap(
        id: 'doc',
        data: {'role': 'assistant', 'message': 'x'},
      );
      expect(interaction.timestamp, isA<DateTime>());
    });

    test('a non-Timestamp timestamp does not throw', () {
      final interaction = AIInteraction.fromMap(
        id: 'doc',
        data: {
          'role': 'assistant',
          'message': 'x',
          'timestamp': '2026-03-01T00:00:00Z',
        },
      );
      expect(interaction.timestamp, isA<DateTime>());
    });

    test('a wrong-typed message/status does not throw', () {
      expect(
        () => AIInteraction.fromMap(
          id: 'doc',
          data: {'message': 123, 'status': 7, 'isAIResponse': 'yes'},
        ),
        throwsA(isA<TypeError>()),
        reason: 'a wrong type is a genuine contract break, not a partial doc',
      );
    });

    test('an empty document does not throw', () {
      final interaction = AIInteraction.fromMap(id: 'doc', data: const {});
      expect(interaction.message, isEmpty);
      expect(interaction.role, AIChatRole.assistant);
      expect(interaction.isUserTurn, isFalse);
    });
  });

  group('source contract — the duplicate writer cannot come back', () {
    late String modelSource;
    late String providerSource;
    late String chatDeleteSource;
    late String chatSource;

    setUpAll(() {
      modelSource = File('lib/models/ai_interaction.dart').readAsStringSync();
      providerSource =
          File('lib/providers/ai_chat_provider.dart').readAsStringSync();
      chatDeleteSource = File('functions/ai/chatDelete.js').readAsStringSync();
      chatSource = File('functions/ai/chat.js').readAsStringSync();
    });

    test('AIInteraction no longer exposes a Firestore serialiser', () {
      // Match the DECLARATION, not a mention: the model's header comment
      // deliberately names `toFirestore` while explaining what was removed, so
      // a plain `contains` would be a false positive.
      expect(
        RegExp(r'\btoFirestore\s*\(').hasMatch(modelSource),
        isFalse,
        reason: 'a client-side writer would re-create the second schema',
      );
      expect(
        RegExp(r'\bfromFirestore\s*\(').hasMatch(modelSource),
        isTrue,
        reason: 'the reader is still required',
      );
    });

    test('AIChatProvider no longer writes ai_interactions', () {
      expect(
        providerSource.contains('_saveInteraction'),
        isFalse,
        reason: 'the removed duplicate writer must not return',
      );
      expect(
        providerSource.contains('toFirestore'),
        isFalse,
        reason: 'no client serialisation of a chat exchange may remain',
      );
      expect(
        providerSource.contains('ai_interactions'),
        isTrue,
        reason: 'it still READS the collection for history',
      );
    });

    test('the provider reads the server ordering field', () {
      expect(providerSource.contains("orderBy('timestamp'"), isTrue);
      expect(
        providerSource.contains("orderBy('createdAt'"),
        isFalse,
        reason: 'createdAt only ever existed on the removed client schema',
      );
    });

    test('the server writer emits role + message + timestamp', () {
      expect(
        chatSource.contains('timestamp'),
        isTrue,
        reason: 'the single writer stamps the shared ordering field',
      );
      expect(
        chatSource.contains('ai_interactions'),
        isTrue,
        reason: 'askAI is the single writer',
      );
    });

    test('every ai_interactions write uses `timestamp`, never `createdAt`',
        () {
      // Scope the check to the actual WRITE blocks: `createdAt` legitimately
      // appears elsewhere in the file (analytics / rate-limit documents), so a
      // whole-file `contains` would be a false positive.
      final blocks = aiInteractionWriteBlocks(chatSource);

      expect(
        blocks,
        isNotEmpty,
        reason: 'askAI must still write the per-turn documents',
      );
      for (final block in blocks) {
        expect(block.contains('timestamp:'), isTrue);
        expect(block.contains('role:'), isTrue);
        expect(block.contains('message:'), isTrue);
        expect(
          block.contains('createdAt'),
          isFalse,
          reason: 'one timestamp field only — retention must see every row',
        );
      }
    });

    test('the retention sweep filters on the SAME field the writer emits', () {
      expect(
        chatDeleteSource.contains('timestamp'),
        isTrue,
        reason: 'cleanupExpiredAIConversations must see every stored row',
      );
      expect(
        chatDeleteSource.contains('ai_interactions'),
        isTrue,
      );
    });

    test('the legacy ai_conversations store is still cleaned up, never '
        'written', () {
      // Task §9: "Do not restore ai_conversations writes." The transition
      // contract is that it may still be READ for deletion, never written.
      expect(chatDeleteSource.contains('ai_conversations'), isTrue);
      // Match the COLLECTION REFERENCE, not a mention: chat.js still names the
      // legacy store in comments that explain its removal.
      expect(
        RegExp(r'''collection\(\s*["']ai_conversations["']''')
            .hasMatch(chatSource),
        isFalse,
        reason: 'askAI must not write the legacy store',
      );
    });

    test('the history loader still consumes the server schema', () {
      expect(providerSource.contains('AIInteraction.fromFirestore'), isTrue);
    });
  });
}
/// Extracts every `collection("ai_interactions")…add({ … })` payload from a
/// Functions source file so the assertions can be scoped to the real WRITE
/// blocks instead of the whole file (comments and unrelated analytics writes
/// legitimately mention other field names).
List<String> aiInteractionWriteBlocks(String source) {
  const marker = 'collection("ai_interactions")';
  final blocks = <String>[];
  var searchFrom = 0;

  while (true) {
    final start = source.indexOf(marker, searchFrom);
    if (start == -1) break;
    final end = source.indexOf('});', start);
    if (end == -1) break;
    blocks.add(source.substring(start + marker.length, end));
    searchFrom = end + 1;
  }

  return blocks;
}
