import 'dart:io';
import 'package:path/path.dart' as p;

/// Traverses up from [filePath] until a directory containing pubspec.yaml is found.
/// Returns the absolute path of the package root, or null if not found.
String? findPackageRoot(String filePath) {
  var dir = p.dirname(filePath);
  while (true) {
    if (File(p.join(dir, 'pubspec.yaml')).existsSync()) return dir;
    final parent = p.dirname(dir);
    if (parent == dir) return null;
    dir = parent;
  }
}

/// Resolves an import URI to a path relative to the package root.
///
/// Returns null for:
/// - `dart:` imports
/// - `package:` imports from external packages
String? importToRelativePath({
  required String importUri,
  required String currentFilePath,
  required String packageRoot,
  required String packageName,
}) {
  if (importUri.isEmpty) return null;
  if (importUri.startsWith('dart:')) return null;

  if (importUri.startsWith('package:')) {
    final withoutScheme = importUri.substring('package:'.length);
    final slashIdx = withoutScheme.indexOf('/');
    if (slashIdx == -1) return null;

    final importPackage = withoutScheme.substring(0, slashIdx);
    if (importPackage != packageName) return null;

    final libRelative = withoutScheme.substring(slashIdx + 1);
    return toForwardSlash(p.normalize(p.join('lib', libRelative)));
  }

  // Relative import (e.g. '../../auth/service.dart')
  final currentDir = p.dirname(currentFilePath);
  final resolved = p.normalize(p.join(currentDir, importUri));
  return toForwardSlash(p.relative(resolved, from: packageRoot));
}

/// Extracts the feature name from a relative path.
///
/// e.g. 'lib/features/auth/service.dart' with featuresPath 'lib/features' → 'auth'
String? extractFeatureName(String relativePath, String featuresPath) {
  final normalizedPath = toForwardSlash(p.normalize(relativePath));
  final normalizedFeatures = toForwardSlash(p.normalize(featuresPath));

  if (!normalizedPath.startsWith('$normalizedFeatures/')) return null;

  final rest = normalizedPath.substring(normalizedFeatures.length + 1);
  final parts = rest.split('/');
  if (parts.isEmpty || parts[0].isEmpty) return null;

  return parts[0];
}

/// Normalizes path separators to forward slashes for cross-platform consistency.
String toForwardSlash(String path) => path.replaceAll(r'\', '/');
