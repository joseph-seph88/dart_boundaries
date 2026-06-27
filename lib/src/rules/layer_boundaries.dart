import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import '../config/boundaries_config.dart';
import '../utils/package_utils.dart';
import '../utils/pattern_matcher.dart';

class LayerBoundaries extends DartLintRule {
  const LayerBoundaries() : super(code: _code);

  static const _code = LintCode(
    name: 'layer_boundaries',
    problemMessage: 'Layer boundary violation.',
    correctionMessage:
        'Check your layer_boundaries rules in analysis_options.yaml.',
  );

  @override
  bool get enabledByDefault => false;

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final packageRoot = findPackageRoot(resolver.path);
    if (packageRoot == null) return;

    final cfg = BoundariesConfig.load(packageRoot)?.layerBoundaries;
    if (cfg == null || cfg.elements.isEmpty) return;

    final currentRel = toForwardSlash(
      resolver.path.substring(packageRoot.length + 1),
    );

    final currentResult = _findTypeWithCaptures(currentRel, cfg.elements);
    if (currentResult == null) return;

    final currentType = currentResult.$1;
    final currentCaptures = currentResult.$2;

    LayerRule? rule;
    for (final r in cfg.rules) {
      if (r.from == currentType) {
        rule = r;
        break;
      }
    }

    // When default is allow and there is no rule, nothing to check.
    if (rule == null && cfg.defaultBehavior == LayerBoundaryDefault.allow) {
      return;
    }

    final packageName = context.pubspec.name;

    context.registry.addImportDirective((node) {
      final uri = node.uri.stringValue;
      if (uri == null) return;

      final importedRel = importToRelativePath(
        importUri: uri,
        currentFilePath: resolver.path,
        packageRoot: packageRoot,
        packageName: packageName,
      );
      if (importedRel == null) return;

      final importedResult = _findTypeWithCaptures(importedRel, cfg.elements);
      if (importedResult == null) return;

      final importedType = importedResult.$1;
      final importedCaptures = importedResult.$2;

      // Same type AND same instance (captures match) → always allowed
      if (importedType == currentType &&
          _capturesMatch(currentCaptures, importedCaptures)) {
        return;
      }

      // Explicit disallow takes precedence
      if (rule?.disallow.contains(importedType) == true) {
        reporter.atNode(node, _makeCode(currentType, importedType));
        return;
      }

      // Allow list present → it controls everything (default does not apply)
      if (rule != null && rule.allow.isNotEmpty) {
        if (!rule.allow.contains(importedType)) {
          reporter.atNode(node, _makeCode(currentType, importedType));
        }
        return;
      }

      // No explicit ruling → fall back to default
      if (cfg.defaultBehavior == LayerBoundaryDefault.disallow) {
        reporter.atNode(node, _makeCode(currentType, importedType));
      }
    });
  }

  (String, Map<String, String>)? _findTypeWithCaptures(
    String path,
    List<ElementType> elements,
  ) {
    for (final e in elements) {
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

  LintCode _makeCode(String from, String to) => LintCode(
        name: _code.name,
        problemMessage: '"$from" is not allowed to import from "$to".',
        correctionMessage: _code.correctionMessage,
      );
}
