import 'package:dart_boundaries/src/config/boundaries_config.dart';
import 'package:dart_boundaries/src/utils/pattern_matcher.dart';
import 'package:test/test.dart';

const _elements = [
  ElementType(type: 'feature', pattern: 'lib/features/*'),
  ElementType(type: 'shared', pattern: 'lib/shared/**'),
  ElementType(type: 'core', pattern: 'lib/core/**'),
];

String? _findType(String path) {
  for (final e in _elements) {
    if (matchesElementPattern(path, e.pattern)) return e.type;
  }
  return null;
}

void main() {
  group('element type resolution', () {
    test('resolves feature type for file inside feature dir', () {
      expect(_findType('lib/features/auth/auth_page.dart'), equals('feature'));
    });

    test('resolves feature type for deeply nested file', () {
      expect(
        _findType('lib/features/home/data/home_repo.dart'),
        equals('feature'),
      );
    });

    test('resolves shared type', () {
      expect(_findType('lib/shared/widgets/button.dart'), equals('shared'));
    });

    test('resolves core type', () {
      expect(_findType('lib/core/di/locator.dart'), equals('core'));
    });

    test('returns null for unmatched path', () {
      expect(_findType('lib/generated/l10n.dart'), isNull);
    });
  });

  group('allow-list logic', () {
    const rules = [
      LayerRule(from: 'feature', allow: ['shared', 'core']),
      LayerRule(from: 'shared', allow: ['core']),
    ];

    LayerRule? findRule(String type) {
      for (final r in rules) {
        if (r.from == type) return r;
      }
      return null;
    }

    test('feature → shared is allowed', () {
      final rule = findRule('feature');
      expect(rule?.allow.contains('shared'), isTrue);
    });

    test('feature → core is allowed', () {
      final rule = findRule('feature');
      expect(rule?.allow.contains('core'), isTrue);
    });

    test('feature → feature cross-import is not in allow list', () {
      final rule = findRule('feature');
      expect(rule?.allow.contains('feature'), isFalse);
    });

    test('shared → core is allowed', () {
      final rule = findRule('shared');
      expect(rule?.allow.contains('core'), isTrue);
    });

    test('shared → feature is not allowed', () {
      final rule = findRule('shared');
      expect(rule?.allow.contains('feature'), isFalse);
    });

    test('no rule for core means no restriction applied', () {
      expect(findRule('core'), isNull);
    });
  });
}
