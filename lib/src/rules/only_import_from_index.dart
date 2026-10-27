import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';
import 'package:path/path.dart' as p;
import '../config/boundaries_config.dart';
import '../utils/package_utils.dart';

class OnlyImportFromIndex extends AnalysisRule {
  OnlyImportFromIndex()
    : super(
        name: 'only_import_from_index',
        description: "Reports cross-feature imports that bypass the feature's index.dart.",
      );

  static const code = LintCode(
    'only_import_from_index',
    'Avoid importing internal feature files directly.',
    correctionMessage:
        "Try importing from the feature's index.dart barrel file instead.",
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

  final OnlyImportFromIndex rule;
  final RuleContext context;

  @override
  void visitImportDirective(ImportDirective node) {
    final unit = context.currentUnit;
    if (unit == null) return;
    final filePath = unit.file.path;

    final packageRoot = findPackageRoot(filePath);
    if (packageRoot == null) return;

    final cfg = BoundariesConfig.load(packageRoot)?.onlyImportFromIndex;
    if (cfg == null) return;

    // index.dart files may freely import internal files
    if (p.basename(filePath) == 'index.dart') return;

    final currentRel = toForwardSlash(
      filePath.substring(packageRoot.length + 1),
    );
    final currentFeature = extractFeatureName(currentRel, cfg.featuresPath);
    final normalizedFeatures = toForwardSlash(p.normalize(cfg.featuresPath));

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
    if (importedFeature == null) return;

    // Intra-feature imports are always fine
    if (importedFeature == currentFeature) return;

    // Only index.dart is a valid cross-feature import target
    final indexPath = '$normalizedFeatures/$importedFeature/index.dart';
    if (importedRel == indexPath) return;

    rule.reportAtNode(node);
  }
}

class ReplaceWithIndexFix extends ResolvedCorrectionProducer {
  ReplaceWithIndexFix({required super.context});

  // The message depends on the feature name, so it is set per instance.
  static const _kind = FixKind(
    'dart_boundaries.fix.replaceWithIndex',
    DartFixKindPriority.standard,
    "Import from the feature's index.dart",
  );

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final directive = node;
    if (directive is! ImportDirective) return;

    final packageRoot = findPackageRoot(file);
    if (packageRoot == null) return;

    final cfg = BoundariesConfig.load(packageRoot)?.onlyImportFromIndex;
    if (cfg == null) return;

    final uri = directive.uri.stringValue;
    if (uri == null) return;

    final packageName = readPackageName(packageRoot);
    final importedRel = importToRelativePath(
      importUri: uri,
      currentFilePath: file,
      packageRoot: packageRoot,
      packageName: packageName,
    );
    if (importedRel == null) return;

    final importedFeature = extractFeatureName(importedRel, cfg.featuresPath);
    if (importedFeature == null) return;

    // Build the corrected package: URI pointing to index.dart
    final featuresWithoutLib = cfg.featuresPath.startsWith('lib/')
        ? cfg.featuresPath.substring(4)
        : cfg.featuresPath;
    final indexUri =
        'package:$packageName/$featuresWithoutLib/$importedFeature/index.dart';

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(range.node(directive.uri), "'$indexUri'");
    });
  }
}
