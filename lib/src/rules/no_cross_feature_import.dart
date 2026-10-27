import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../config/boundaries_config.dart';
import '../utils/package_utils.dart';

class NoCrossFeatureImport extends AnalysisRule {
  NoCrossFeatureImport()
    : super(
        name: 'no_cross_feature_import',
        description: 'Reports imports from one feature into another.',
      );

  /// `{0}` is the configured message, or [defaultMessage] when none is set.
  static const code = LintCode(
    'no_cross_feature_import',
    '{0}',
    correctionMessage:
        'Try using a shared layer or dependency injection instead.',
  );

  static const defaultMessage =
      'Avoid importing directly from another feature.';

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

  final NoCrossFeatureImport rule;
  final RuleContext context;

  @override
  void visitImportDirective(ImportDirective node) {
    final unit = context.currentUnit;
    if (unit == null) return;
    final filePath = unit.file.path;

    final packageRoot = findPackageRoot(filePath);
    if (packageRoot == null) return;

    final cfg = BoundariesConfig.load(packageRoot)?.noCrossFeatureImport;
    if (cfg == null) return;

    final currentRel = toForwardSlash(
      filePath.substring(packageRoot.length + 1),
    );
    final currentFeature = extractFeatureName(currentRel, cfg.featuresPath);
    if (currentFeature == null) return;

    final uri = node.uri.stringValue;
    if (uri == null) return;

    final importedRel = importToRelativePath(
      importUri: uri,
      currentFilePath: filePath,
      packageRoot: packageRoot,
      packageName: readPackageName(packageRoot),
    );
    if (importedRel == null) return;

    final importedFeature = extractFeatureName(importedRel, cfg.featuresPath);
    if (importedFeature == null || importedFeature == currentFeature) return;

    rule.reportAtNode(
      node,
      arguments: [cfg.message ?? NoCrossFeatureImport.defaultMessage],
    );
  }
}
