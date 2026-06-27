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

    final currentType = _findType(currentRel, cfg.elements);
    if (currentType == null) return;

    LayerRule? rule;
    for (final r in cfg.rules) {
      if (r.from == currentType) {
        rule = r;
        break;
      }
    }
    if (rule == null) return;

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

      final importedType = _findType(importedRel, cfg.elements);
      if (importedType == null || importedType == currentType) return;

      if (!rule!.allow.contains(importedType)) {
        reporter.atNode(
          node,
          LintCode(
            name: _code.name,
            problemMessage:
                '"$currentType" is not allowed to import from "$importedType".',
            correctionMessage: _code.correctionMessage,
          ),
        );
      }
    });
  }

  String? _findType(String path, List<ElementType> elements) {
    for (final e in elements) {
      if (matchesElementPattern(path, e.pattern)) return e.type;
    }
    return null;
  }
}
