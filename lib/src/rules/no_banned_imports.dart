import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import '../config/boundaries_config.dart';
import '../utils/package_utils.dart';
import '../utils/pattern_matcher.dart';

class NoBannedImports extends DartLintRule {
  const NoBannedImports() : super(code: _code);

  static const _code = LintCode(
    name: 'no_banned_imports',
    problemMessage: 'This import is banned by the project configuration.',
    correctionMessage:
        'Try removing this import or using an allowed alternative.',
  );

  @override
  bool get enabledByDefault => false;

  @override
  List<Fix> getFixes() => [_RemoveBannedImportFix()];

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final packageRoot = findPackageRoot(resolver.path);
    if (packageRoot == null) return;

    final entries =
        BoundariesConfig.load(packageRoot)?.noBannedImports?.entries;
    if (entries == null || entries.isEmpty) return;

    final currentRel = toForwardSlash(
      resolver.path.substring(packageRoot.length + 1),
    );
    final packageName = context.pubspec.name;

    context.registry.addImportDirective((node) {
      final uri = node.uri.stringValue;
      if (uri == null) return;

      for (final entry in entries) {
        if (!matchesAnyPattern(currentRel, entry.paths)) continue;

        final importedRel = importToRelativePath(
          importUri: uri,
          currentFilePath: resolver.path,
          packageRoot: packageRoot,
          packageName: packageName,
        );
        final pathToCheck = importedRel ?? uri;

        if (matchesAnyPattern(pathToCheck, entry.deny)) {
          reporter.atNode(
            node,
            LintCode(
              name: _code.name,
              problemMessage: entry.message ?? 'This import is not allowed.',
            ),
          );
          return;
        }
      }
    });
  }
}

class _RemoveBannedImportFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addImportDirective((node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Remove banned import',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Delete the entire line including the trailing newline
        final lineIndex =
            resolver.lineInfo.getLocation(node.offset).lineNumber - 1;
        final start = resolver.lineInfo.getOffsetOfLine(lineIndex);
        final end = resolver.lineInfo.getOffsetOfLine(lineIndex + 1);
        builder.addDeletion(SourceRange(start, end - start));
      });
    });
  }
}
