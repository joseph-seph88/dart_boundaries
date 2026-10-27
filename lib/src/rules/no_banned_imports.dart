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
import '../config/boundaries_config.dart';
import '../utils/package_utils.dart';
import '../utils/pattern_matcher.dart';

class NoBannedImports extends AnalysisRule {
  NoBannedImports()
    : super(
        name: 'no_banned_imports',
        description: 'Reports imports banned by the project configuration.',
      );

  /// `{0}` is the configured message, or [defaultMessage] when none is set.
  static const code = LintCode(
    'no_banned_imports',
    '{0}',
    correctionMessage:
        'Try removing this import or using an allowed alternative.',
  );

  static const defaultMessage =
      'This import is banned by the project configuration.';

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

  final NoBannedImports rule;
  final RuleContext context;

  @override
  void visitImportDirective(ImportDirective node) {
    final unit = context.currentUnit;
    final packageRoot = findPackageRoot(unit?.file.path ?? '');
    if (unit == null || packageRoot == null) return;

    final entries = BoundariesConfig.load(packageRoot)
        ?.noBannedImports
        ?.entries;
    if (entries == null || entries.isEmpty) return;

    final uri = node.uri.stringValue;
    if (uri == null) return;

    final filePath = unit.file.path;
    final currentRel = toForwardSlash(
      filePath.substring(packageRoot.length + 1),
    );

    final importedRel = importToRelativePath(
      importUri: uri,
      currentFilePath: filePath,
      packageRoot: packageRoot,
      packageName: readPackageName(packageRoot),
    );
    final pathToCheck = importedRel ?? uri;

    for (final entry in entries) {
      // paths == null → applies to all files; otherwise check match
      if (entry.paths != null && !matchesAnyPattern(currentRel, entry.paths!)) {
        continue;
      }

      // Skip files that are explicitly excluded
      if (entry.excludePaths.isNotEmpty &&
          matchesAnyPattern(currentRel, entry.excludePaths)) {
        continue;
      }

      if (matchesAnyPattern(pathToCheck, entry.deny)) {
        rule.reportAtNode(
          node,
          arguments: [entry.message ?? NoBannedImports.defaultMessage],
        );
        return;
      }
    }
  }
}

class RemoveBannedImportFix extends ResolvedCorrectionProducer {
  RemoveBannedImportFix({required super.context});

  static const _kind = FixKind(
    'dart_boundaries.fix.removeBannedImport',
    DartFixKindPriority.standard,
    'Remove banned import',
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

    await builder.addDartFileEdit(file, (builder) {
      builder.addDeletion(range.deletionRange(directive));
    });
  }
}
