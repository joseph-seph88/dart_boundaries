import 'package:dart_boundaries/src/utils/pattern_matcher.dart';
import 'package:test/test.dart';

void main() {
  group('matchesPattern — legacy regex', () {
    test('exact match', () {
      expect(
        matchesPattern(
          'lib/features/auth/service.dart',
          'lib/features/auth/service.dart',
        ),
        isTrue,
      );
    });

    test('.* matches any suffix', () {
      expect(
        matchesPattern(
          'lib/features/auth/data/service.dart',
          'lib/features/auth/.*',
        ),
        isTrue,
      );
    });

    test('.* does not match sibling', () {
      expect(
        matchesPattern('lib/features/home/page.dart', 'lib/features/auth/.*'),
        isFalse,
      );
    });

    test('[^/]* matches single segment wildcard', () {
      expect(
        matchesPattern(
          'lib/features/auth/page.dart',
          r'lib/features/[^/]*/page\.dart',
        ),
        isTrue,
      );
    });

    test('invalid regex returns false gracefully', () {
      expect(matchesPattern('some/path', '[invalid'), isFalse);
    });
  });

  group('matchesPattern — glob', () {
    test('** matches file at any depth', () {
      expect(
        matchesPattern(
          'lib/features/auth/data/repo.dart',
          'lib/features/**',
        ),
        isTrue,
      );
    });

    test('** does not match file outside the prefix', () {
      expect(
        matchesPattern('lib/shared/utils.dart', 'lib/features/**'),
        isFalse,
      );
    });

    test('* matches a single path segment', () {
      expect(matchesPattern('lib/features/auth', 'lib/features/*'), isTrue);
    });

    test('* does not match across multiple segments', () {
      expect(
        matchesPattern('lib/features/auth/page.dart', 'lib/features/*'),
        isFalse,
      );
    });

    test('glob with literal extension', () {
      expect(
        matchesPattern(
          'lib/features/auth/index.dart',
          'lib/features/*/index.dart',
        ),
        isTrue,
      );
    });

    test('glob does not match wrong extension', () {
      expect(
        matchesPattern(
          'lib/features/auth/page.dart',
          'lib/features/*/index.dart',
        ),
        isFalse,
      );
    });
  });

  group('matchesAnyPattern', () {
    test('returns true when any pattern matches', () {
      expect(
        matchesAnyPattern('lib/features/auth/page.dart', [
          'lib/features/home/.*',
          'lib/features/auth/.*',
        ]),
        isTrue,
      );
    });

    test('returns false when no pattern matches', () {
      expect(
        matchesAnyPattern('lib/core/service.dart', [
          'lib/features/home/.*',
          'lib/features/auth/.*',
        ]),
        isFalse,
      );
    });
  });

  group('matchesElementPattern', () {
    test('lib/features/* matches file within a feature subdirectory', () {
      expect(
        matchesElementPattern(
          'lib/features/auth/page.dart',
          'lib/features/*',
        ),
        isTrue,
      );
    });

    test('lib/features/* matches deeply nested file within a feature', () {
      expect(
        matchesElementPattern(
          'lib/features/auth/data/repositories/auth_repo.dart',
          'lib/features/*',
        ),
        isTrue,
      );
    });

    test('lib/features/* does not match file outside features', () {
      expect(
        matchesElementPattern('lib/shared/utils.dart', 'lib/features/*'),
        isFalse,
      );
    });

    test('lib/shared/** matches file anywhere under shared', () {
      expect(
        matchesElementPattern(
          'lib/shared/utils/string_ext.dart',
          'lib/shared/**',
        ),
        isTrue,
      );
    });

    test('lib/shared/** does not match file outside shared', () {
      expect(
        matchesElementPattern(
          'lib/features/auth/page.dart',
          'lib/shared/**',
        ),
        isFalse,
      );
    });
  });
}
