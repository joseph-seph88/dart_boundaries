import 'package:dart_boundaries/src/utils/package_utils.dart';
import 'package:test/test.dart';

void main() {
  group('importToRelativePath', () {
    const root = '/project';
    const pkg = 'app';

    test('converts own package: import to lib-relative path', () {
      expect(
        importToRelativePath(
          importUri: 'package:app/features/auth/service.dart',
          currentFilePath: '/project/lib/features/home/page.dart',
          packageRoot: root,
          packageName: pkg,
        ),
        'lib/features/auth/service.dart',
      );
    });

    test('returns null for dart: imports', () {
      expect(
        importToRelativePath(
          importUri: 'dart:core',
          currentFilePath: '/project/lib/main.dart',
          packageRoot: root,
          packageName: pkg,
        ),
        isNull,
      );
    });

    test('returns null for external package: imports', () {
      expect(
        importToRelativePath(
          importUri: 'package:flutter/material.dart',
          currentFilePath: '/project/lib/main.dart',
          packageRoot: root,
          packageName: pkg,
        ),
        isNull,
      );
    });

    test('resolves relative import', () {
      expect(
        importToRelativePath(
          importUri: '../../auth/service.dart',
          currentFilePath: '/project/lib/features/home/ui/page.dart',
          packageRoot: root,
          packageName: pkg,
        ),
        'lib/features/auth/service.dart',
      );
    });
  });

  group('extractFeatureName', () {
    test('extracts feature name from nested path', () {
      expect(
        extractFeatureName(
          'lib/features/auth/data/repository.dart',
          'lib/features',
        ),
        'auth',
      );
    });

    test('extracts feature name from direct child', () {
      expect(
        extractFeatureName('lib/features/home/index.dart', 'lib/features'),
        'home',
      );
    });

    test('returns null for path outside features dir', () {
      expect(
        extractFeatureName('lib/core/di/locator.dart', 'lib/features'),
        isNull,
      );
    });

    test('returns null for the features dir itself', () {
      expect(extractFeatureName('lib/features', 'lib/features'), isNull);
    });
  });
}
