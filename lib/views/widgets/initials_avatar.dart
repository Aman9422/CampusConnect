import 'package:campusconnect/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// InitialsAvatar - v6.6
///
/// Displays user initials in a circular badge with deterministic gradient.
/// No images, no storage - privacy-first design.
class InitialsAvatar extends StatelessWidget {
  final String? name;
  final String? uid;
  final double size;
  final TextStyle? textStyle;

  const InitialsAvatar({
    super.key,
    this.name,
    this.uid,
    this.size = 40,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(name);
    final gradient = _getGradient(uid ?? name ?? 'U');

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style:
              textStyle ??
              TextStyle(
                color: Colors.white,
                fontSize: size * 0.4,
                fontWeight: FontWeight.w600,
                letterSpacing: initials.length > 1 ? -1 : 0,
              ),
        ),
      ),
    );
  }

  /// Extract initials from name
  /// - Single word: First letter (e.g., "Aman" → "A")
  /// - Two+ words: First letter of first two words (e.g., "Aman Yadav" → "AY")
  /// - Empty/null: Fallback to "U"
  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'U';
    }

    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length == 1) {
      return words[0][0].toUpperCase();
    }

    // Take first letter of first two words
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  /// Generate deterministic gradient based on string hash
  /// Uses UID for consistency, falls back to name
  LinearGradient _getGradient(String seed) {
    final hash = seed.hashCode.abs();
    final index = hash % _gradients.length;
    return _gradients[index];
  }

  /// Predefined gradients for variety
  static final List<LinearGradient> _gradients = [
    // Blue
    LinearGradient(
      colors: [AppTheme.primaryBlue, AppTheme.primaryBlue.withOpacity(0.7)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    // Purple
    const LinearGradient(
      colors: [Color(0xFF7C3AED), Color(0xFFA78BFA)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    // Teal
    const LinearGradient(
      colors: [Color(0xFF0D9488), Color(0xFF5EEAD4)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    // Orange
    const LinearGradient(
      colors: [Color(0xFFEA580C), Color(0xFFFBBF24)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    // Pink
    const LinearGradient(
      colors: [Color(0xFFDB2777), Color(0xFFF472B6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    // Indigo
    const LinearGradient(
      colors: [Color(0xFF4F46E5), Color(0xFF818CF8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    // Green
    const LinearGradient(
      colors: [Color(0xFF16A34A), Color(0xFF4ADE80)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    // Red
    const LinearGradient(
      colors: [Color(0xFFDC2626), Color(0xFFFB7185)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ];
}

/// Large variant for profile screens
class LargeInitialsAvatar extends StatelessWidget {
  final String? name;
  final String? uid;
  final double size;

  const LargeInitialsAvatar({super.key, this.name, this.uid, this.size = 80});

  @override
  Widget build(BuildContext context) {
    return InitialsAvatar(
      name: name,
      uid: uid,
      size: size,
      textStyle: TextStyle(
        color: Colors.white,
        fontSize: size * 0.35,
        fontWeight: FontWeight.w700,
        letterSpacing: -1,
      ),
    );
  }
}

/// Small variant for list items
class SmallInitialsAvatar extends StatelessWidget {
  final String? name;
  final String? uid;

  const SmallInitialsAvatar({super.key, this.name, this.uid});

  @override
  Widget build(BuildContext context) {
    return InitialsAvatar(name: name, uid: uid, size: 32);
  }
}
