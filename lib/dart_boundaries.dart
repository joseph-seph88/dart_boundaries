/// dart_boundaries: custom lint rules for enforcing import boundaries in
/// Dart and Flutter projects.
///
/// Configure rules via `analysis_options.yaml` under the `dart_boundaries:` key.
/// See the [package README](https://pub.dev/packages/dart_boundaries) for the
/// full configuration reference.
library;

import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'src/rules/layer_boundaries.dart';
import 'src/rules/no_banned_imports.dart';
import 'src/rules/no_cross_feature_import.dart';
import 'src/rules/only_import_from_index.dart';

/// Creates the dart_boundaries custom lint plugin.
///
/// Entry point for the custom_lint framework — called automatically when
/// `custom_lint` is listed as a plugin in `analysis_options.yaml`.
PluginBase createPlugin() => _DartBoundariesPlugin();

class _DartBoundariesPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => const [
        NoCrossFeatureImport(),
        NoBannedImports(),
        OnlyImportFromIndex(),
        LayerBoundaries(),
      ];
}
