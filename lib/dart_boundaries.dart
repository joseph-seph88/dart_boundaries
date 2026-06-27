import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'src/rules/layer_boundaries.dart';
import 'src/rules/no_banned_imports.dart';
import 'src/rules/no_cross_feature_import.dart';
import 'src/rules/only_import_from_index.dart';

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
