## 0.1.0

- Initial release
- `layer_boundaries`: define named layer types with `allow`/`disallow` rules; `{{ name }}` capture groups enable cross-feature detection; `default: disallow` blocks all cross-type imports unless explicitly allowed
- `no_cross_feature_import`: detects direct imports between feature folders
- `no_banned_imports`: blocks specific import paths; `paths` is optional (global deny), `exclude_paths` for exemptions
- `only_import_from_index`: enforces barrel file (`index.dart`) access pattern
- Glob pattern support (`*`, `**`) and capture group syntax (`{{ name }}`) for all pattern fields
- Config validation: unknown keys in `analysis_options.yaml` are reported to stderr
