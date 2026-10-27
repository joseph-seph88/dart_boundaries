// This file exists so that pub.dev recognizes the example directory.
// The actual usage examples are in example/lib/ and example/analysis_options.yaml.
//
// To try dart_boundaries:
// Enable in analysis_options.yaml (no pubspec.yaml change needed):
//      plugins:
//        dart_boundaries:
//          version: ^0.4.0
//          diagnostics:
//            layer_boundaries: true
//      dart_boundaries:
//        layer_boundaries:
//          elements:
//            - type: feature
//              pattern: 'lib/features/{{ name }}'
//          rules:
//            - from: feature
//              disallow: [feature]
void main() {}
