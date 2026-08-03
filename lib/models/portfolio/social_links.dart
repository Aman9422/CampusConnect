/// CampusConnect v8.4 — Social links for the student portfolio.
///
/// Stored under `users/{uid}/portfolio.links`. Existing root-level URL fields
/// on the user document (linkedinProfile, githubUrl, portfolioUrl, ...) are
/// kept untouched for backward compatibility with the alumni profile.
class SocialLinks {
  final String? github;
  final String? linkedin;
  final String? portfolio;
  final String? leetcode;
  final String? codeforces;
  final String? hackerrank;

  const SocialLinks({
    this.github,
    this.linkedin,
    this.portfolio,
    this.leetcode,
    this.codeforces,
    this.hackerrank,
  });

  factory SocialLinks.empty() => const SocialLinks();

  factory SocialLinks.fromMap(Map<String, dynamic> map) {
    return SocialLinks(
      github: map['github'] as String?,
      linkedin: map['linkedin'] as String?,
      portfolio: map['portfolio'] as String?,
      leetcode: map['leetcode'] as String?,
      codeforces: map['codeforces'] as String?,
      hackerrank: map['hackerrank'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'github': github,
      'linkedin': linkedin,
      'portfolio': portfolio,
      'leetcode': leetcode,
      'codeforces': codeforces,
      'hackerrank': hackerrank,
    };
  }

  SocialLinks copyWith({
    String? github,
    String? linkedin,
    String? portfolio,
    String? leetcode,
    String? codeforces,
    String? hackerrank,
  }) {
    return SocialLinks(
      github: github ?? this.github,
      linkedin: linkedin ?? this.linkedin,
      portfolio: portfolio ?? this.portfolio,
      leetcode: leetcode ?? this.leetcode,
      codeforces: codeforces ?? this.codeforces,
      hackerrank: hackerrank ?? this.hackerrank,
    );
  }

  /// Returns key/value pairs for only the links that have a value.
  Map<String, String> get activeLinks {
    final links = <String, String>{};
    if (github?.isNotEmpty == true) links['github'] = github!;
    if (linkedin?.isNotEmpty == true) links['linkedin'] = linkedin!;
    if (portfolio?.isNotEmpty == true) links['portfolio'] = portfolio!;
    if (leetcode?.isNotEmpty == true) links['leetcode'] = leetcode!;
    if (codeforces?.isNotEmpty == true) links['codeforces'] = codeforces!;
    if (hackerrank?.isNotEmpty == true) links['hackerrank'] = hackerrank!;
    return links;
  }

  bool get isEmpty => activeLinks.isEmpty;

  bool get isNotEmpty => !isEmpty;
}
