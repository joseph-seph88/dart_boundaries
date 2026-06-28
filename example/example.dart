// This file exists so that pub.dev recognizes the example directory.
// The actual usage examples are in example/lib/ and example/analysis_options.yaml.
//
// To try dart_boundaries:
// 1. Add to pubspec.yaml dev_dependencies:
//      custom_lint: '>=0.8.1 <1.0.0'
//      dart_boundaries: ^0.2.0
// 2. Enable in analysis_options.yaml:
//      analyzer:
//        plugins:
//          - custom_lint
//      dart_boundaries:
//        layer_boundaries:
//          elements:
//            - type: feature
//              pattern: 'lib/features/{{ name }}'
//          rules:
//            - from: feature
//              disallow: [feature]
void main() {}
