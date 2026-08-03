/// CampusConnect v8.4 — Validation helpers for the student portfolio.
///
/// Centralizes required-field and URL checks so every portfolio form
/// (edit screen, projects manager, etc.) shares the same validation rules.
class PortfolioValidators {
  PortfolioValidators._();

  /// Validates a required text field value.
  static String? required(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    if (fieldName != 'Title' && value.trim().length < 2) {
      return '$fieldName must be at least 2 characters';
    }
    return null;
  }

  /// Validates a URL. Accepts empty values (optional fields) but rejects
  /// non-empty values that don't start with a valid scheme.
  ///
  /// H3: previously `http://` was accepted unconditionally even when
  /// `allowHttp: false`, and the third clause was dead logic.
  static String? optionalUrl(String? value, {bool allowHttp = true}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;

    final lower = trimmed.toLowerCase();
    final hasValidScheme =
        lower.startsWith('https://') || (allowHttp && lower.startsWith('http://'));
    if (!hasValidScheme) {
      return allowHttp
          ? 'Enter a valid URL starting with http:// or https://'
          : 'Enter a valid URL starting with https://';
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) {
      return 'Enter a valid URL';
    }
    return null;
  }
}
