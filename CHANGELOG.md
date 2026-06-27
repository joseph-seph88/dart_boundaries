## 0.1.0

- Initial release
- `layer_boundaries`: define named layer types and declare which layers are allowed to import from which
- `no_cross_feature_import`: detects direct imports between feature folders
- `no_banned_imports`: blocks specific import paths with custom messages
- `only_import_from_index`: enforces barrel file (`index.dart`) access pattern
- Glob pattern support (`*`, `**`) for all pattern fields
- Config validation: unknown keys in `analysis_options.yaml` are reported to stderr
