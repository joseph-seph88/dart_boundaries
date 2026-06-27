import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

class BannedImportEntry {
  const BannedImportEntry({
    this.paths,
    required this.deny,
    this.excludePaths = const [],
    this.message,
  });

  final List<String>? paths; // null = applies to every file
  final List<String> deny;
  final List<String> excludePaths;
  final String? message;
}

class ElementType {
  const ElementType({required this.type, required this.pattern});

  final String type;
  final String pattern;
}

enum LayerBoundaryDefault { allow, disallow }

class LayerRule {
  const LayerRule({
    required this.from,
    this.allow = const [],
    this.disallow = const [],
  });

  final String from;
  final List<String> allow;
  final List<String> disallow;
}

/// Full `dart_boundaries:` config parsed from analysis_options.yaml.
class BoundariesConfig {
  const BoundariesConfig({
    this.noCrossFeatureImport,
    this.noBannedImports,
    this.onlyImportFromIndex,
    this.layerBoundaries,
  });

  final NoCrossFeatureConfig? noCrossFeatureImport;
  final NoBannedImportsConfig? noBannedImports;
  final OnlyImportFromIndexConfig? onlyImportFromIndex;
  final LayerBoundariesConfig? layerBoundaries;

  // ─── static cache keyed by package root ───────────────────────────────────

  static final _cache = <String, BoundariesConfig?>{};

  static BoundariesConfig? load(String packageRoot) {
    if (_cache.containsKey(packageRoot)) return _cache[packageRoot];

    final file = File(p.join(packageRoot, 'analysis_options.yaml'));
    if (!file.existsSync()) return _cache[packageRoot] = null;

    try {
      final yaml = loadYaml(file.readAsStringSync());
      if (yaml is! YamlMap) return _cache[packageRoot] = null;

      final section = yaml['dart_boundaries'];
      if (section is! YamlMap) return _cache[packageRoot] = null;

      _warnUnknownKeys(
          section,
          const {
            'no_cross_feature_import',
            'no_banned_imports',
            'only_import_from_index',
            'layer_boundaries',
          },
          'dart_boundaries');

      return _cache[packageRoot] = BoundariesConfig(
        noCrossFeatureImport:
            _parseNoCrossFeature(section['no_cross_feature_import']),
        noBannedImports: _parseNoBannedImports(section['no_banned_imports']),
        onlyImportFromIndex:
            _parseOnlyImportFromIndex(section['only_import_from_index']),
        layerBoundaries: _parseLayerBoundaries(section['layer_boundaries']),
      );
    } catch (_) {
      return _cache[packageRoot] = null;
    }
  }

  // ─── sub-parsers ──────────────────────────────────────────────────────────

  static NoCrossFeatureConfig? _parseNoCrossFeature(dynamic raw) {
    if (raw == null) return null;
    if (raw is! YamlMap) return const NoCrossFeatureConfig();
    _warnUnknownKeys(
        raw, const {'features_path', 'message'}, 'no_cross_feature_import');
    return NoCrossFeatureConfig(
      featuresPath: raw['features_path'] as String? ?? 'lib/features',
      message: raw['message'] as String?,
    );
  }

  static NoBannedImportsConfig? _parseNoBannedImports(dynamic raw) {
    if (raw == null) return null;
    if (raw is! YamlMap) return const NoBannedImportsConfig(entries: []);
    _warnUnknownKeys(raw, const {'entries'}, 'no_banned_imports');

    final rawEntries = raw['entries'];
    if (rawEntries is! YamlList) {
      return const NoBannedImportsConfig(entries: []);
    }

    final entries = <BannedImportEntry>[];
    for (final item in rawEntries) {
      if (item is! YamlMap) continue;
      _warnUnknownKeys(
        item,
        const {'paths', 'deny', 'exclude_paths', 'message'},
        'no_banned_imports.entries[]',
      );
      final deny = _toStringList(item['deny']);
      if (deny.isEmpty) continue;

      // paths is optional: null means "apply to all files"
      final pathsRaw = item['paths'];
      final paths = pathsRaw != null ? _toStringList(pathsRaw) : null;

      entries.add(BannedImportEntry(
        paths: paths,
        deny: deny,
        excludePaths: _toStringList(item['exclude_paths']),
        message: item['message'] as String?,
      ));
    }
    return NoBannedImportsConfig(entries: entries);
  }

  static OnlyImportFromIndexConfig? _parseOnlyImportFromIndex(dynamic raw) {
    if (raw == null) return null;
    if (raw is! YamlMap) return const OnlyImportFromIndexConfig();
    _warnUnknownKeys(raw, const {'features_path'}, 'only_import_from_index');
    return OnlyImportFromIndexConfig(
      featuresPath: raw['features_path'] as String? ?? 'lib/features',
    );
  }

  static LayerBoundariesConfig? _parseLayerBoundaries(dynamic raw) {
    if (raw == null) return null;
    if (raw is! YamlMap) return null;
    _warnUnknownKeys(
        raw, const {'elements', 'rules', 'default'}, 'layer_boundaries');

    final elements = <ElementType>[];
    final rawElements = raw['elements'];
    if (rawElements is YamlList) {
      for (final item in rawElements) {
        if (item is! YamlMap) continue;
        _warnUnknownKeys(
            item, const {'type', 'pattern'}, 'layer_boundaries.elements[]');
        final type = item['type'] as String?;
        final pattern = item['pattern'] as String?;
        if (type == null || pattern == null) continue;
        elements.add(ElementType(type: type, pattern: pattern));
      }
    }

    final rules = <LayerRule>[];
    final rawRules = raw['rules'];
    if (rawRules is YamlList) {
      for (final item in rawRules) {
        if (item is! YamlMap) continue;
        _warnUnknownKeys(item, const {'from', 'allow', 'disallow'},
            'layer_boundaries.rules[]');
        final from = item['from'] as String?;
        if (from == null) continue;
        rules.add(LayerRule(
          from: from,
          allow: _toStringList(item['allow']),
          disallow: _toStringList(item['disallow']),
        ));
      }
    }

    final defaultRaw = raw['default'] as String?;
    if (defaultRaw != null &&
        defaultRaw != 'allow' &&
        defaultRaw != 'disallow') {
      stderr.writeln(
        '[dart_boundaries] Invalid value "$defaultRaw" for layer_boundaries.default. '
        'Use "allow" or "disallow".',
      );
    }
    final defaultBehavior = defaultRaw == 'disallow'
        ? LayerBoundaryDefault.disallow
        : LayerBoundaryDefault.allow;

    return LayerBoundariesConfig(
      elements: elements,
      rules: rules,
      defaultBehavior: defaultBehavior,
    );
  }

  // ─── helpers ──────────────────────────────────────────────────────────────

  static List<String> _toStringList(dynamic value) {
    if (value is YamlList) return value.map((e) => e.toString()).toList();
    if (value is String) return [value];
    return [];
  }

  static void _warnUnknownKeys(
    YamlMap map,
    Set<String> knownKeys,
    String section,
  ) {
    for (final key in map.keys) {
      final k = key.toString();
      if (!knownKeys.contains(k)) {
        stderr.writeln(
          '[dart_boundaries] Unknown key "$k" in $section. '
          'Known keys: ${knownKeys.join(', ')}',
        );
      }
    }
  }
}

// ─── config models ────────────────────────────────────────────────────────────

class NoCrossFeatureConfig {
  const NoCrossFeatureConfig({
    this.featuresPath = 'lib/features',
    this.message,
  });

  final String featuresPath;
  final String? message;
}

class NoBannedImportsConfig {
  const NoBannedImportsConfig({required this.entries});

  final List<BannedImportEntry> entries;
}

class OnlyImportFromIndexConfig {
  const OnlyImportFromIndexConfig({this.featuresPath = 'lib/features'});

  final String featuresPath;
}

class LayerBoundariesConfig {
  const LayerBoundariesConfig({
    required this.elements,
    required this.rules,
    this.defaultBehavior = LayerBoundaryDefault.allow,
  });

  final List<ElementType> elements;
  final List<LayerRule> rules;
  final LayerBoundaryDefault defaultBehavior;
}
