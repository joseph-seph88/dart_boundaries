import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:path/path.dart' as p;
import '../config/boundaries_config.dart';
import '../utils/package_utils.dart';

class OnlyImportFromIndex extends DartLintRule {
  const OnlyImportFromIndex() : super(code: _code);

  static const _code = LintCode(
    name: 'only_import_from_index',
    problemMessage: 'Avoid importing internal feature files directly.',
    correctionMessage:
        "Try importing from the feature's index.dart barrel file instead.",
  );

  @override
  bool get enabledByDefault => false;

  @override
  List<Fix> getFixes() => [_ReplaceWithIndexFix()];

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final packageRoot = findPackageRoot(resolver.path);
    if (packageRoot == null) return;

    final cfg = BoundariesConfig.load(packageRoot)?.onlyImportFromIndex;
    if (cfg == null) return;

    // index.dart files may freely import internal files
    if (p.basename(resolver.path) == 'index.dart') return;

    final currentRel = toForwardSlash(
      resolver.path.substring(packageRoot.length + 1),
    );
    final currentFeature = extractFeatureName(currentRel, cfg.featuresPath);
    final normalizedFeatures = toForwardSlash(p.normalize(cfg.featuresPath));
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

      final importedFeature = extractFeatureName(importedRel, cfg.featuresPath);
      if (importedFeature == null) return;

      // Intra-feature imports are always fine
      if (importedFeature == currentFeature) return;

      // Only index.dart is a valid cross-feature import target
      final indexPath = '$normalizedFeatures/$importedFeature/index.dart';
      if (importedRel == indexPath) return;

      reporter.atNode(node, _code);
    });
  }
}

class _ReplaceWithIndexFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    final packageRoot = findPackageRoot(resolver.path);
    if (packageRoot == null) return;

    final cfg = BoundariesConfig.load(packageRoot)?.onlyImportFromIndex;
    if (cfg == null) return;

    final packageName = context.pubspec.name;

    context.registry.addImportDirective((node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      final uri = node.uri.stringValue;
      if (uri == null) return;

      final importedRel = importToRelativePath(
        importUri: uri,
        currentFilePath: resolver.path,
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

      final changeBuilder = reporter.createChangeBuilder(
        message: "Import from '$importedFeature/index.dart'",
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.uri.sourceRange,
          "'$indexUri'",
        );
      });
    });
  }
}
