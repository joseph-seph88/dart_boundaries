import 'package_utils.dart';

/// Returns true if [path] matches [pattern].
///
/// Supports two forms:
/// - Glob (`*`, `**`): pattern has no `[` and contains `*` not preceded by `.`
/// - Anchored regex: everything else (legacy)
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

/// Like [matchesPattern] but for element-type patterns.
/// A trailing `/*` or `{{ capture }}` also matches files inside that directory.
bool matchesElementPattern(String path, String pattern) {
  return matchElementPatternWithCaptures(path, pattern) != null;
}

/// Matches [path] against an element-type [pattern] and returns captured values.
///
/// [pattern] may include:
/// - `{{ name }}` — captures one path segment under the key `name`
/// - `*`          — glob wildcard for one segment (no capture)
/// - `**`         — glob wildcard for any depth
/// - Anchored regex (legacy, when pattern has no `{{` and contains `[`)
///
/// Returns `null` if the path does not match.
/// Returns an empty map `{}` if matched with no capture groups.
Map<String, String>? matchElementPatternWithCaptures(
  String path,
  String pattern,
) {
  final normalizedPath = toForwardSlash(path);

  if (pattern.contains('{{')) {
    final (regexBase, captureNames) = _buildCapturingRegex(pattern);
    final regexStr =
        _needsTrailingSuffix(pattern) ? '$regexBase(/.*)?' : regexBase;
    try {
      final match = RegExp('^$regexStr\$').firstMatch(normalizedPath);
      if (match == null) return null;
      final captures = <String, String>{};
      for (final name in captureNames) {
        final value = match.namedGroup(name);
        if (value != null) captures[name] = value;
      }
      return captures;
    } catch (_) {
      return null;
    }
  }

  // No captures — use existing glob / raw-regex logic
  try {
    String regexStr = _isGlob(pattern) ? _globToRegex(pattern) : pattern;
    if (_isGlob(pattern) && _endsWithSingleStar(pattern)) {
      regexStr = '$regexStr(/.*)?';
    }
    return RegExp('^$regexStr\$').hasMatch(normalizedPath) ? {} : null;
  } catch (_) {
    return null;
  }
}

// ─── internal helpers ─────────────────────────────────────────────────────────

bool _endsWithSingleStar(String p) => p.endsWith('/*') && !p.endsWith('/**');

/// Trailing `/*` or `{{ name }}` at the end should also match files inside.
bool _needsTrailingSuffix(String pattern) {
  final t = pattern.trimRight();
  return t.endsWith('}}') || _endsWithSingleStar(t);
}

/// A pattern is glob if it has `*` not preceded by `.` and no `[` class.
bool _isGlob(String pattern) {
  if (pattern.contains('[')) return false;
  return RegExp(r'(?<!\.)\*').hasMatch(pattern);
}

/// Converts glob wildcards to regex fragments.
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

/// Converts a capture-group pattern to a regex string with named groups.
/// `{{ name }}` → `(?<name>[^/]+)`, glob wildcards handled as in [_globToRegex].
(String, List<String>) _buildCapturingRegex(String pattern) {
  final captureNames = <String>[];
  final buf = StringBuffer();
  int i = 0;

  while (i < pattern.length) {
    // Detect {{ name }}
    if (pattern[i] == '{' && i + 1 < pattern.length && pattern[i + 1] == '{') {
      final end = pattern.indexOf('}}', i + 2);
      if (end != -1) {
        final name = pattern.substring(i + 2, end).trim();
        if (RegExp(r'^\w+$').hasMatch(name)) {
          captureNames.add(name);
          buf.write('(?<$name>[^/]+)');
          i = end + 2;
          continue;
        }
      }
    }

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

  return (buf.toString(), captureNames);
}
