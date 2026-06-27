import 'package_utils.dart';

/// Returns true if [path] matches [pattern].
///
/// If [pattern] contains glob wildcards (`*`, `**`) and no regex character
/// classes (`[`), it is treated as a glob:
///   `*`  → one path segment (no `/`)
///   `**` → any path including separators
///
/// Otherwise [pattern] is used as an anchored regular expression (legacy).
bool matchesPattern(String path, String pattern) {
  final normalizedPath = toForwardSlash(path);
  try {
    final regexStr = _isGlob(pattern) ? _globToRegex(pattern) : pattern;
    return RegExp('^$regexStr\$').hasMatch(normalizedPath);
  } catch (_) {
    return false;
  }
}

/// Returns true if [path] matches any of [patterns].
bool matchesAnyPattern(String path, List<String> patterns) {
  return patterns.any((p) => matchesPattern(path, p));
}

/// Like [matchesPattern] but intended for element-type patterns where a
/// trailing `/*` should also match files inside that directory.
///
/// Example: `lib/features/*` matches `lib/features/auth/page.dart`.
bool matchesElementPattern(String path, String pattern) {
  final normalizedPath = toForwardSlash(path);
  try {
    String regexStr = _isGlob(pattern) ? _globToRegex(pattern) : pattern;
    if (_isGlob(pattern) && _endsWithSingleStar(pattern)) {
      regexStr = '$regexStr(/.*)?';
    }
    return RegExp('^$regexStr\$').hasMatch(normalizedPath);
  } catch (_) {
    return false;
  }
}

// ─── internal helpers ─────────────────────────────────────────────────────────

bool _endsWithSingleStar(String p) => p.endsWith('/*') && !p.endsWith('/**');

/// A pattern is a glob if it contains `*` that is NOT preceded by `.`
/// (which would indicate a regex `.*`) and contains no `[` (character class).
bool _isGlob(String pattern) {
  if (pattern.contains('[')) return false;
  return RegExp(r'(?<!\.)\*').hasMatch(pattern);
}

String _globToRegex(String pattern) {
  final buf = StringBuffer();
  int i = 0;
  while (i < pattern.length) {
    final ch = pattern[i];
    if (ch == '*') {
      if (i + 1 < pattern.length && pattern[i + 1] == '*') {
        buf.write('.*');
        i += 2;
      } else {
        buf.write('[^/]+');
        i++;
      }
    } else if (RegExp(r'[.$^|{}()+?\\]').hasMatch(ch)) {
      buf.write('\\$ch');
      i++;
    } else {
      buf.write(ch);
      i++;
    }
  }
  return buf.toString();
}
