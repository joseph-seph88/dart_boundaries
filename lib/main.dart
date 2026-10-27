import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'src/rules/layer_boundaries.dart';
import 'src/rules/no_banned_imports.dart';
import 'src/rules/no_cross_feature_import.dart';
import 'src/rules/only_import_from_index.dart';

final plugin = DartBoundariesPlugin();

class DartBoundariesPlugin extends Plugin {
  @override
  String get name => 'dart_boundaries';

  @override
  void register(PluginRegistry registry) {
    registry
      ..registerLintRule(NoCrossFeatureImport())
      ..registerLintRule(NoBannedImports())
      ..registerLintRule(OnlyImportFromIndex())
      ..registerLintRule(LayerBoundaries())
      ..registerFixForRule(NoBannedImports.code, RemoveBannedImportFix.new)
      ..registerFixForRule(OnlyImportFromIndex.code, ReplaceWithIndexFix.new);
  }
}
