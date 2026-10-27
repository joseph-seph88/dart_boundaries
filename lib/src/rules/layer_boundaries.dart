import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import '../config/boundaries_config.dart';
import '../utils/package_utils.dart';
import '../utils/pattern_matcher.dart';

class LayerBoundaries extends AnalysisRule {
  LayerBoundaries()
    : super(
        name: 'layer_boundaries',
        description: 'Reports imports that violate the configured layer rules.',
      );

  /// `{0}` is the importing layer, `{1}` the imported layer.
  static const code = LintCode(
    'layer_boundaries',
    '"{0}" is not allowed to import from "{1}".',
    correctionMessage:
        'Check your layer_boundaries rules in analysis_options.yaml.',
  );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addImportDirective(this, _Visitor(this, context));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.context);

  final LayerBoundaries rule;
  final RuleContext context;

  @override
  void visitImportDirective(ImportDirective node) {
    final unit = context.currentUnit;
    if (unit == null) return;
    final filePath = unit.file.path;

    final packageRoot = findPackageRoot(filePath);
    if (packageRoot == null) return;

    final cfg = BoundariesConfig.load(packageRoot)?.layerBoundaries;
    if (cfg == null || cfg.elements.isEmpty) return;

    final currentRel = toForwardSlash(
      filePath.substring(packageRoot.length + 1),
    );

    final currentResult = _findTypeWithCaptures(currentRel, cfg.elements);
    if (currentResult == null) return;

    final currentType = currentResult.$1;
    final currentCaptures = currentResult.$2;

    LayerRule? layerRule;
    for (final r in cfg.rules) {
      if (r.from == currentType) {
        layerRule = r;
        break;
      }
    }

    // When default is allow and there is no rule, nothing to check.
    if (layerRule == null &&
        cfg.defaultBehavior == LayerBoundaryDefault.allow) {
      return;
    }

    final uri = node.uri.stringValue;
    if (uri == null) return;

    final importedRel = importToRelativePath(
      importUri: uri,
      currentFilePath: filePath,
      packageRoot: packageRoot,
      packageName: readPackageName(packageRoot),
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

    void report() =>
        rule.reportAtNode(node, arguments: [currentType, importedType]);

    // Explicit disallow takes precedence
    if (layerRule?.disallow.contains(importedType) == true) {
      report();
      return;
    }

    // Allow list present → it controls everything (default does not apply)
    if (layerRule != null && layerRule.allow.isNotEmpty) {
      if (!layerRule.allow.contains(importedType)) report();
      return;
    }

    // No explicit ruling → fall back to default
    if (cfg.defaultBehavior == LayerBoundaryDefault.disallow) report();
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
}
