/// Error message utility for converting technical errors into user-friendly messages
/// Part of CampusConnect v5.1 stability improvements
class ErrorMessages {
  /// Convert technical error into user-friendly message
  static String getUserFriendlyMessage(dynamic error) {
    if (error == null) return 'An unexpected error occurred';

    final errorString = error.toString().toLowerCase();

    // Network errors
    if (errorString.contains('network') ||
        errorString.contains('socket') ||
        errorString.contains('connection') ||
        errorString.contains('failed host lookup')) {
      return 'Check your internet connection and try again';
    }

    // Firebase Auth errors
    if (errorString.contains('unauthenticated') ||
        errorString.contains('not authenticated') ||
        errorString.contains('permission-denied') ||
        errorString.contains('permission denied')) {
      return 'Please log in again to continue';
    }

    // Timeout errors
    if (errorString.contains('timeout') || errorString.contains('deadline')) {
      return 'Request took too long. Please try again';
    }

    // Already applied
    if (errorString.contains('already applied') ||
        errorString.contains('duplicate')) {
      return 'You have already applied to this placement';
    }

    // Firebase errors
    if (errorString.contains('firebase')) {
      return 'Service temporarily unavailable. Please try again';
    }

    // Rate limiting
    if (errorString.contains('rate limit') ||
        errorString.contains('too many requests')) {
      return 'Too many attempts. Please wait a moment';
    }

    // Invalid data
    if (errorString.contains('invalid-argument') ||
        errorString.contains('invalid argument')) {
      return 'Invalid information provided. Please check and try again';
    }

    // Firestore errors
    if (errorString.contains('firestore') || errorString.contains('document')) {
      return 'Unable to save data. Please try again';
    }

    // Cloud Function errors
    if (errorString.contains('internal') && errorString.contains('function')) {
      return 'Service error. Please try again later';
    }

    // Generic HTTP errors
    if (errorString.contains('http')) {
      return 'Connection error. Please check your internet';
    }

    // Strip "Exception: " prefix if present
    String message = error.toString();
    if (message.startsWith('Exception: ')) {
      message = message.substring(11);
    }

    // If error is already user-friendly (no technical terms), return as-is
    if (!_containsTechnicalTerms(message)) {
      return message;
    }

    // Default fallback
    return 'Something went wrong. Please try again';
  }

  /// Check if message contains technical terms
  static bool _containsTechnicalTerms(String message) {
    final technicalTerms = [
      'exception',
      'error:',
      'firebase',
      'firestore',
      'null',
      'undefined',
      'stack trace',
      'at com.',
      'at java.',
      'httpsError',
    ];

    final lowerMessage = message.toLowerCase();
    return technicalTerms.any((term) => lowerMessage.contains(term));
  }

  /// Get retry-able error message with action hint
  static String getRetryMessage(dynamic error) {
    final baseMessage = getUserFriendlyMessage(error);

    final errorString = error.toString().toLowerCase();

    // Don't suggest retry for auth errors
    if (errorString.contains('unauthenticated') ||
        errorString.contains('permission')) {
      return baseMessage;
    }

    // Don't suggest retry for already applied
    if (errorString.contains('already applied')) {
      return baseMessage;
    }

    return baseMessage;
  }
}
