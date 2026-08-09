import 'package:flutter_test/flutter_test.dart';

/// CampusConnect v8.7 — Alumni Group Chat contract tests.
///
/// These tests mirror the FIREBASE SECURITY RULES for
/// `alumni_group_messages/{messageId}` (firestore.rules) as pure Dart
/// functions so they can be unit-tested without Firebase, exactly like the
/// existing `test/alumni_resume_review_test.dart` pattern.
///
/// Rules under test (Task §8):
///   - read:   authenticated && userRole() == 'alumni'
///   - create: authenticated && userRole() == 'alumni' &&
///             senderId == request.auth.uid
///   - update/delete: authenticated && userRole() == 'alumni' &&
///             resource.data.senderId == request.auth.uid
///
/// Students, Teachers and unauthenticated users are denied. The sender UID
/// must come from Firebase Auth — a client-supplied senderId for another
/// user is rejected.
class AlumniGroupChatRuleMirror {
  const AlumniGroupChatRuleMirror._();

  static bool canRead({required bool isAuthenticated, String? role}) =>
      isAuthenticated && role == 'alumni';

  static bool canCreate({
    required bool isAuthenticated,
    String? role,
    required String requestSenderId,
    required String authUid,
  }) => isAuthenticated && role == 'alumni' && requestSenderId == authUid;

  static bool canMutate({
    required bool isAuthenticated,
    String? role,
    required String resourceSenderId,
    required String authUid,
  }) => isAuthenticated && role == 'alumni' && resourceSenderId == authUid;
}

/// Message field contract (Task §7) enforced by the model + service.
class AlumniGroupMessageContract {
  const AlumniGroupMessageContract._();

  /// True when `senderId` equals the authenticated user's UID.
  static bool isFromUser(String senderId, String currentUserId) =>
      senderId == currentUserId;

  /// Soft-deleted messages are filtered client-side (a `where('isDeleted')`
  /// + `orderBy('createdAt')` composite would need an index — Task §16).
  static bool shouldKeep(bool isDeleted) => !isDeleted;

  /// Non-empty message guard (empty/whitespace sends are rejected).
  static bool isValidMessageBody(String message) =>
      message.trim().isNotEmpty && message.trim().length <= 1000;
}

void main() {
  group('AlumniGroupChatRuleMirror.canRead (read: alumni only)', () {
    test('authenticated alumni can read', () {
      expect(
        AlumniGroupChatRuleMirror.canRead(
          isAuthenticated: true,
          role: 'alumni',
        ),
        isTrue,
      );
    });

    test('students cannot read', () {
      expect(
        AlumniGroupChatRuleMirror.canRead(
          isAuthenticated: true,
          role: 'student',
        ),
        isFalse,
      );
    });

    test('teachers cannot read', () {
      expect(
        AlumniGroupChatRuleMirror.canRead(
          isAuthenticated: true,
          role: 'teacher',
        ),
        isFalse,
      );
    });

    test('unauthenticated users cannot read (even with a spoofed role)', () {
      expect(
        AlumniGroupChatRuleMirror.canRead(
          isAuthenticated: false,
          role: 'alumni',
        ),
        isFalse,
      );
    });

    test('missing user document -> role null -> denied', () {
      expect(
        AlumniGroupChatRuleMirror.canRead(isAuthenticated: true, role: null),
        isFalse,
      );
    });
  });

  group('AlumniGroupChatRuleMirror.canCreate (sender = auth uid)', () {
    test('alumni sending with their own UID is allowed', () {
      expect(
        AlumniGroupChatRuleMirror.canCreate(
          isAuthenticated: true,
          role: 'alumni',
          requestSenderId: 'ALUMNI_1',
          authUid: 'ALUMNI_1',
        ),
        isTrue,
      );
    });

    test('alumni cannot spoof another senderId (client-supplied identity)', () {
      // Task §7/§8: never trust a client-provided senderId.
      expect(
        AlumniGroupChatRuleMirror.canCreate(
          isAuthenticated: true,
          role: 'alumni',
          requestSenderId: 'ALUMNI_2',
          authUid: 'ALUMNI_1',
        ),
        isFalse,
      );
    });

    test('students cannot create even with matching UID', () {
      expect(
        AlumniGroupChatRuleMirror.canCreate(
          isAuthenticated: true,
          role: 'student',
          requestSenderId: 'STUDENT_1',
          authUid: 'STUDENT_1',
        ),
        isFalse,
      );
    });

    test('teachers cannot create even with matching UID', () {
      expect(
        AlumniGroupChatRuleMirror.canCreate(
          isAuthenticated: true,
          role: 'teacher',
          requestSenderId: 'TEACHER_1',
          authUid: 'TEACHER_1',
        ),
        isFalse,
      );
    });

    test('unauthenticated users cannot create', () {
      expect(
        AlumniGroupChatRuleMirror.canCreate(
          isAuthenticated: false,
          role: 'alumni',
          requestSenderId: 'ALUMNI_1',
          authUid: 'ALUMNI_1',
        ),
        isFalse,
      );
    });
  });

  group('AlumniGroupChatRuleMirror.canMutate (update/delete own only)', () {
    test('alumni can soft-delete their own message', () {
      expect(
        AlumniGroupChatRuleMirror.canMutate(
          isAuthenticated: true,
          role: 'alumni',
          resourceSenderId: 'ALUMNI_1',
          authUid: 'ALUMNI_1',
        ),
        isTrue,
      );
    });

    test('alumni cannot modify another alumni message', () {
      expect(
        AlumniGroupChatRuleMirror.canMutate(
          isAuthenticated: true,
          role: 'alumni',
          resourceSenderId: 'ALUMNI_2',
          authUid: 'ALUMNI_1',
        ),
        isFalse,
      );
    });

    test('students cannot mutate any message', () {
      expect(
        AlumniGroupChatRuleMirror.canMutate(
          isAuthenticated: true,
          role: 'student',
          resourceSenderId: 'STUDENT_1',
          authUid: 'STUDENT_1',
        ),
        isFalse,
      );
    });

    test('teachers cannot mutate any message', () {
      expect(
        AlumniGroupChatRuleMirror.canMutate(
          isAuthenticated: true,
          role: 'teacher',
          resourceSenderId: 'TEACHER_1',
          authUid: 'TEACHER_1',
        ),
        isFalse,
      );
    });
  });

  group('AlumniGroupMessageContract (message model contract)', () {
    test('isFromUser distinguishes own vs other messages', () {
      expect(
        AlumniGroupMessageContract.isFromUser('ALUMNI_1', 'ALUMNI_1'),
        isTrue,
      );
      expect(
        AlumniGroupMessageContract.isFromUser('ALUMNI_2', 'ALUMNI_1'),
        isFalse,
      );
    });

    test('soft-deleted messages are filtered from the stream', () {
      expect(AlumniGroupMessageContract.shouldKeep(false), isTrue);
      expect(AlumniGroupMessageContract.shouldKeep(true), isFalse);
    });

    test('empty / whitespace / oversized bodies are rejected', () {
      expect(AlumniGroupMessageContract.isValidMessageBody(''), isFalse);
      expect(AlumniGroupMessageContract.isValidMessageBody('   '), isFalse);
      expect(
        AlumniGroupMessageContract.isValidMessageBody('x' * 1001),
        isFalse,
      );
      expect(
        AlumniGroupMessageContract.isValidMessageBody('Hello alumni!'),
        isTrue,
      );
    });
  });
}
