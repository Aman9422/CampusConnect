import 'package:flutter_test/flutter_test.dart';

/// CampusConnect v8.8.3 — Security rules contract tests (MED-4 / MED-5).
///
/// Mirrors the FIREBASE SECURITY RULES added/updated in `firestore.rules` as
/// pure Dart functions so they can be unit-tested without Firebase, exactly
/// like `test/alumni_group_chat_test.dart`, `test/ai_chat_deletion_test.dart`.
///
/// Under test:
///   - MED-4 (`chats`): participants may read; update limited to the
///     last-message/unread metadata keys; client DELETE denied (Admin SDK
///     only); create requires the creator in participantIds.
///   - MED-5 (`users/{uid}/activities`): create allowed ONLY for the owner's
///     own `resumeReviewed` event of exactly 5 points; all other event types,
///     point values, cross-user writes, update/delete are denied. (The
///     server's `logUserActivity` uses the Admin SDK and bypasses rules, so
///     the engagement pipeline is unaffected.)

/// MED-4 mirror — `match /chats/{chatId}`.
class ChatRules {
  const ChatRules._();

  /// Metadata-only keys the client is allowed to update.
  static const List<String> mutableChatKeys = [
    'lastMessage',
    'lastMessageSenderId',
    'lastMessageAt',
    'unreadCount',
  ];

  /// `allow read`: authenticated && uid in participantIds.
  static bool canRead({
    required bool isAuthenticated,
    required List<String> participantIds,
    required String authUid,
  }) => isAuthenticated && participantIds.contains(authUid);

  /// `allow create`: authenticated && uid in request participantIds.
  static bool canCreate({
    required bool isAuthenticated,
    required List<String> requestedParticipantIds,
    required String authUid,
  }) => isAuthenticated && requestedParticipantIds.contains(authUid);

  /// `allow update`: authenticated && uid in participantIds && only the
  /// mutable metadata keys changed (hasOnly on affectedKeys).
  static bool canUpdate({
    required bool isAuthenticated,
    required List<String> participantIds,
    required String authUid,
    required List<String> affectedKeys,
  }) =>
      isAuthenticated &&
      participantIds.contains(authUid) &&
      affectedKeys.every(mutableChatKeys.contains);

  /// `allow delete`: false — chat removal requires the Admin SDK.
  static bool canDelete() => false;
}

/// MED-5 mirror — `match /users/{userId}/activities/{activityId}`.
class ActivityRules {
  const ActivityRules._();

  /// `allow read`: owner only.
  static bool canRead({
    required bool isAuthenticated,
    required String resourceUserId,
    required String authUid,
  }) => isAuthenticated && resourceUserId == authUid;

  /// `allow create`: owner && `userId == auth.uid` && `eventType ==
  /// 'resumeReviewed'` && `points == 5`. Covers the ONLY client path
  /// (`ResumeReviewProvider` success → 5 pts).
  static bool canCreate({
    required bool isAuthenticated,
    required String resourceUserId,
    required String resourceDataUserId,
    required String eventType,
    required int points,
    required String authUid,
  }) =>
      isAuthenticated &&
      resourceUserId == authUid &&
      resourceDataUserId == authUid &&
      eventType == 'resumeReviewed' &&
      points == 5;

  /// `allow update / delete`: false — activity docs are append-only for
  /// clients (server manages lifecycle via Admin SDK).
  static bool canMutate() => false;
}

void main() {
  group(
    'ChatRules — MED-4 (participants read; metadata-only update; no delete)',
    () {
      test('a participant can read the chat', () {
        expect(
          ChatRules.canRead(
            isAuthenticated: true,
            participantIds: ['A', 'B'],
            authUid: 'A',
          ),
          isTrue,
        );
      });

      test('a non-participant cannot read', () {
        expect(
          ChatRules.canRead(
            isAuthenticated: true,
            participantIds: ['A', 'B'],
            authUid: 'C',
          ),
          isFalse,
        );
      });

      test('unauthenticated users cannot read even as a participant id', () {
        expect(
          ChatRules.canRead(
            isAuthenticated: false,
            participantIds: ['A', 'B'],
            authUid: 'A',
          ),
          isFalse,
        );
      });

      test('a participant may update ONLY the metadata keys', () {
        expect(
          ChatRules.canUpdate(
            isAuthenticated: true,
            participantIds: ['A', 'B'],
            authUid: 'A',
            affectedKeys: ['lastMessage', 'lastMessageAt', 'unreadCount'],
          ),
          isTrue,
        );
      });

      test('a participant CANNOT rewrite identity fields (participants)', () {
        expect(
          ChatRules.canUpdate(
            isAuthenticated: true,
            participantIds: ['A', 'B'],
            authUid: 'A',
            affectedKeys: ['participantIds'],
          ),
          isFalse,
        );
      });

      test(
        'a participant CANNOT rewrite identity fields (relatedMentorshipId)',
        () {
          expect(
            ChatRules.canUpdate(
              isAuthenticated: true,
              participantIds: ['A', 'B'],
              authUid: 'A',
              affectedKeys: ['relatedMentorshipId'],
            ),
            isFalse,
          );
        },
      );

      test('a non-participant cannot update even metadata-only', () {
        expect(
          ChatRules.canUpdate(
            isAuthenticated: true,
            participantIds: ['A', 'B'],
            authUid: 'C',
            affectedKeys: ['lastMessage'],
          ),
          isFalse,
        );
      });

      test('client delete is denied for everyone (Admin SDK only)', () {
        expect(ChatRules.canDelete(), isFalse);
      });

      test('create requires the creator in the participant list', () {
        expect(
          ChatRules.canCreate(
            isAuthenticated: true,
            requestedParticipantIds: ['A', 'B'],
            authUid: 'A',
          ),
          isTrue,
        );
        expect(
          ChatRules.canCreate(
            isAuthenticated: true,
            requestedParticipantIds: ['A', 'B'],
            authUid: 'C',
          ),
          isFalse,
        );
      });
    },
  );

  group('ActivityRules — MED-5 (owner-only resumeReviewed / 5 pts)', () {
    test('legit Resume Reviewer write (own uid, resumeReviewed, 5 pts)', () {
      expect(
        ActivityRules.canCreate(
          isAuthenticated: true,
          resourceUserId: 'U1',
          resourceDataUserId: 'U1',
          eventType: 'resumeReviewed',
          points: 5,
          authUid: 'U1',
        ),
        isTrue,
      );
    });

    test('a client cannot self-award arbitrary points', () {
      expect(
        ActivityRules.canCreate(
          isAuthenticated: true,
          resourceUserId: 'U1',
          resourceDataUserId: 'U1',
          eventType: 'resumeReviewed',
          points: 99999,
          authUid: 'U1',
        ),
        isFalse,
      );
    });

    test('a client cannot forge other event types (e.g. chatMessageSent)', () {
      expect(
        ActivityRules.canCreate(
          isAuthenticated: true,
          resourceUserId: 'U1',
          resourceDataUserId: 'U1',
          eventType: 'chatMessageSent',
          points: 5,
          authUid: 'U1',
        ),
        isFalse,
      );
    });

    test('a client cannot write to another user\'s activities collection', () {
      expect(
        ActivityRules.canCreate(
          isAuthenticated: true,
          resourceUserId: 'U2',
          resourceDataUserId: 'U2',
          eventType: 'resumeReviewed',
          points: 5,
          authUid: 'U1',
        ),
        isFalse,
      );
    });

    test('a client cannot spoof a different userId in the payload', () {
      expect(
        ActivityRules.canCreate(
          isAuthenticated: true,
          resourceUserId: 'U1',
          resourceDataUserId: 'U2', // payload userId != auth.uid
          eventType: 'resumeReviewed',
          points: 5,
          authUid: 'U1',
        ),
        isFalse,
      );
    });

    test('unauthenticated creation is denied', () {
      expect(
        ActivityRules.canCreate(
          isAuthenticated: false,
          resourceUserId: 'U1',
          resourceDataUserId: 'U1',
          eventType: 'resumeReviewed',
          points: 5,
          authUid: 'U1',
        ),
        isFalse,
      );
    });

    test('owner can read their own activities; others cannot', () {
      expect(
        ActivityRules.canRead(
          isAuthenticated: true,
          resourceUserId: 'U1',
          authUid: 'U1',
        ),
        isTrue,
      );
      expect(
        ActivityRules.canRead(
          isAuthenticated: true,
          resourceUserId: 'U1',
          authUid: 'U2',
        ),
        isFalse,
      );
    });

    test('update / delete are denied for clients', () {
      expect(ActivityRules.canMutate(), isFalse);
    });
  });
}
