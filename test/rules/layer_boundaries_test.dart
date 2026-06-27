import 'package:dart_boundaries/src/config/boundaries_config.dart';
import 'package:dart_boundaries/src/utils/pattern_matcher.dart';
import 'package:test/test.dart';

// Shared elements used across groups
const _elements = [
  ElementType(type: 'feature', pattern: 'lib/features/{{ name }}'),
  ElementType(type: 'shared', pattern: 'lib/shared/**'),
  ElementType(type: 'core', pattern: 'lib/core/**'),
];

(String, Map<String, String>)? _findType(String path) {
  for (final e in _elements) {
    final captures = matchElementPatternWithCaptures(path, e.pattern);
    if (captures != null) return (e.type, captures);
  }
  return null;
}

bool _capturesMatch(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (a[key] != b[key]) return false;
  }
  return true;
}

void main() {
  group('element type resolution with captures', () {
    test('resolves feature type and captures name', () {
      final result = _findType('lib/features/auth/page.dart');
      expect(result?.$1, equals('feature'));
      expect(result?.$2, equals({'name': 'auth'}));
    });

    test('resolves feature type for deeply nested file', () {
      final result = _findType('lib/features/home/data/home_repo.dart');
      expect(result?.$1, equals('feature'));
      expect(result?.$2, equals({'name': 'home'}));
    });

    test('resolves shared type with empty captures', () {
      final result = _findType('lib/shared/widgets/button.dart');
      expect(result?.$1, equals('shared'));
      expect(result?.$2, equals({}));
    });

    test('resolves core type with empty captures', () {
      final result = _findType('lib/core/di/locator.dart');
      expect(result?.$1, equals('core'));
    });

    test('returns null for unmatched path', () {
      expect(_findType('lib/generated/l10n.dart'), isNull);
    });
  });

  group('same-instance detection via captures', () {
    test('two files in same feature are same instance', () {
      final a = _findType('lib/features/auth/page.dart');
      final b = _findType('lib/features/auth/service.dart');
      expect(a?.$1, equals(b?.$1));
      expect(_capturesMatch(a!.$2, b!.$2), isTrue);
    });

    test('two files in different features are different instances', () {
      final a = _findType('lib/features/auth/page.dart');
      final b = _findType('lib/features/home/page.dart');
      expect(a?.$1, equals(b?.$1)); // same type
      expect(_capturesMatch(a!.$2, b!.$2), isFalse); // different instance
    });

    test('shared files with no captures are always same instance', () {
      final a = _findType('lib/shared/widgets/button.dart');
      final b = _findType('lib/shared/utils/helper.dart');
      expect(_capturesMatch(a!.$2, b!.$2), isTrue);
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
      expect(findRule('feature')?.allow.contains('shared'), isTrue);
    });

    test('feature → core is allowed', () {
      expect(findRule('feature')?.allow.contains('core'), isTrue);
    });

    test('feature is not in its own allow list', () {
      expect(findRule('feature')?.allow.contains('feature'), isFalse);
    });

    test('shared → core is allowed', () {
      expect(findRule('shared')?.allow.contains('core'), isTrue);
    });

    test('no rule for core means no restriction', () {
      expect(findRule('core'), isNull);
    });
  });

  group('disallow-list logic', () {
    const rules = [
      LayerRule(
        from: 'feature',
        disallow: ['feature'],
        allow: ['shared', 'core'],
      ),
      LayerRule(from: 'shared', allow: ['core']),
    ];

    LayerRule? findRule(String type) {
      for (final r in rules) {
        if (r.from == type) return r;
      }
      return null;
    }

    test('feature has feature in disallow list', () {
      expect(findRule('feature')?.disallow.contains('feature'), isTrue);
    });

    test('feature → shared is still in allow list', () {
      expect(findRule('feature')?.allow.contains('shared'), isTrue);
    });

    test('cross-feature detected: different instances, disallowed type', () {
      final authResult = _findType('lib/features/auth/page.dart')!;
      final homeResult = _findType('lib/features/home/page.dart')!;

      final sameType = authResult.$1 == homeResult.$1;
      final sameInstance = _capturesMatch(authResult.$2, homeResult.$2);
      final rule = findRule(authResult.$1);

      // Different instances of same type with disallow → should be flagged
      expect(sameType, isTrue);
      expect(sameInstance, isFalse);
      expect(rule?.disallow.contains(homeResult.$1), isTrue);
    });

    test('intra-feature import: same instance → always allowed', () {
      final a = _findType('lib/features/auth/page.dart')!;
      final b = _findType('lib/features/auth/service.dart')!;

      final sameInstance = _capturesMatch(a.$2, b.$2);
      expect(sameInstance, isTrue); // same instance → skip disallow check
    });
  });

  group('default: disallow behavior', () {
    // Config: feature has a disallow-only rule; core has no rule at all.
    const cfgDefault = LayerBoundariesConfig(
      defaultBehavior: LayerBoundaryDefault.disallow,
      elements: _elements,
      rules: [
        LayerRule(from: 'feature', disallow: ['feature'], allow: ['shared']),
      ],
    );

    // Config: default allow (current behavior baseline)
    const cfgAllow = LayerBoundariesConfig(
      defaultBehavior: LayerBoundaryDefault.allow,
      elements: _elements,
      rules: [
        LayerRule(from: 'feature', disallow: ['feature'], allow: ['shared']),
      ],
    );

    LayerRule? findRule(LayerBoundariesConfig cfg, String type) {
      for (final r in cfg.rules) {
        if (r.from == type) return r;
      }
      return null;
    }

    // Helper that reproduces the flag decision from layer_boundaries.dart
    bool shouldFlag(
      LayerBoundariesConfig cfg,
      String currentType,
      Map<String, String> currentCaptures,
      String importedType,
      Map<String, String> importedCaptures,
    ) {
      // Same instance → never flag
      if (importedType == currentType &&
          _capturesMatch(currentCaptures, importedCaptures)) {
        return false;
      }

      final rule = findRule(cfg, currentType);

      // No rule + default allow → no flag
      if (rule == null && cfg.defaultBehavior == LayerBoundaryDefault.allow) {
        return false;
      }

      // Explicit disallow
      if (rule?.disallow.contains(importedType) == true) return true;

      // Allow list present
      if (rule != null && rule.allow.isNotEmpty) {
        return !rule.allow.contains(importedType);
      }

      // Fall back to default
      return cfg.defaultBehavior == LayerBoundaryDefault.disallow;
    }

    test('feature → core is blocked when not in allow list (default disallow)',
        () {
      final featureCaptures = {'name': 'auth'};
      final coreCaptures = <String, String>{};
      expect(
        shouldFlag(
            cfgDefault, 'feature', featureCaptures, 'core', coreCaptures),
        isTrue,
      );
    });

    test('feature → shared is allowed (in allow list regardless of default)',
        () {
      final featureCaptures = {'name': 'auth'};
      final sharedCaptures = <String, String>{};
      expect(
        shouldFlag(
            cfgDefault, 'feature', featureCaptures, 'shared', sharedCaptures),
        isFalse,
      );
    });

    test('core → feature blocked when no rule and default is disallow', () {
      final coreCaptures = <String, String>{};
      final featureCaptures = {'name': 'home'};
      expect(
        shouldFlag(
            cfgDefault, 'core', coreCaptures, 'feature', featureCaptures),
        isTrue,
      );
    });

    test('core → feature allowed when no rule and default is allow', () {
      final coreCaptures = <String, String>{};
      final featureCaptures = {'name': 'home'};
      expect(
        shouldFlag(cfgAllow, 'core', coreCaptures, 'feature', featureCaptures),
        isFalse,
      );
    });

    test('feature → feature (cross-feature) always blocked by disallow rule',
        () {
      final authCaptures = {'name': 'auth'};
      final homeCaptures = {'name': 'home'};
      expect(
        shouldFlag(
            cfgDefault, 'feature', authCaptures, 'feature', homeCaptures),
        isTrue,
      );
    });

    test('intra-feature never blocked even with default disallow', () {
      final authA = {'name': 'auth'};
      final authB = {'name': 'auth'};
      expect(
        shouldFlag(cfgDefault, 'feature', authA, 'feature', authB),
        isFalse,
      );
    });
  });
}
