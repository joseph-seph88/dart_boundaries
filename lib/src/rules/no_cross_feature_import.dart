import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import '../config/boundaries_config.dart';
import '../utils/package_utils.dart';

class NoCrossFeatureImport extends DartLintRule {
  const NoCrossFeatureImport() : super(code: _code);

  static const _code = LintCode(
    name: 'no_cross_feature_import',
    problemMessage: 'Avoid importing directly from another feature.',
    correctionMessage:
        'Try using a shared layer or dependency injection instead.',
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

    final cfg = BoundariesConfig.load(packageRoot)?.noCrossFeatureImport;
    if (cfg == null) return;

    final currentRel = toForwardSlash(
      resolver.path.substring(packageRoot.length + 1),
    );
    final currentFeature = extractFeatureName(currentRel, cfg.featuresPath);
    if (currentFeature == null) return;

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
      if (importedFeature == null || importedFeature == currentFeature) return;

      final effectiveCode = cfg.message != null
          ? LintCode(name: _code.name, problemMessage: cfg.message!)
          : _code;

      reporter.atNode(node, effectiveCode);
    });
  }
}
