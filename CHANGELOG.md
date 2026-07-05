## 0.3.1

- Widened the `analyzer` upper bound from `<9.1.0` to `<15.0.0` to pass pub.dev's "up-to-date dependencies" check; actual resolution is unaffected since `custom_lint_builder`/`custom_lint_visitor` still bound it to 8.x

## 0.3.0

- Widened `custom_lint_builder` to `>=0.7.1 <1.0.0` and `analyzer` to `>=7.3.0 <9.1.0`, restoring support for Flutter 3.19+ / Dart 3.3+ (previously required Flutter 3.35+ / Dart 3.9+)
- Replaced `DiagnosticReporter` (analyzer 8.x+ only) with `ErrorReporter` in all rules, which resolves consistently across analyzer 7.3.0–9.0.0 via analyzer's backwards-compatible typedef
- Verified against analyzer 7.3.0/custom_lint_builder 0.7.1 and analyzer 9.0.0/custom_lint_builder 0.8.1
- Capped the `analyzer` upper bound at `<9.1.0` (the last version `custom_lint_visitor` has a matching build for) so unsupported newer analyzer versions fail `pub get` loudly instead of silently resolving to a mismatched build
- Added a "Version compatibility" section to the README documenting the supported range and the `dependency_overrides` workaround for newer Flutter/analyzer versions

## 0.2.0

- Upgraded to `custom_lint_builder` 0.8.1 and `analyzer` 8.4.0
- Added library-level and `createPlugin` API documentation
- Widened `analyzer` dependency constraint to `>=8.0.0 <15.0.0`

## 0.1.0

- Initial release
- `layer_boundaries`: define named layer types with `allow`/`disallow` rules; `{{ name }}` capture groups enable cross-feature detection; `default: disallow` blocks all cross-type imports unless explicitly allowed
- `no_cross_feature_import`: detects direct imports between feature folders
- `no_banned_imports`: blocks specific import paths; `paths` is optional (global deny), `exclude_paths` for exemptions
- `only_import_from_index`: enforces barrel file (`index.dart`) access pattern
- Glob pattern support (`*`, `**`) and capture group syntax (`{{ name }}`) for all pattern fields
- Config validation: unknown keys in `analysis_options.yaml` are reported to stderr
