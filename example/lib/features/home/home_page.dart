// ✅ OK — shared and core are in the allow list for the feature layer
import 'package:dart_boundaries_example/shared/widgets/button.dart';
import 'package:dart_boundaries_example/core/di.dart';

// ❌ layer_boundaries        — "feature/home" cannot import from "feature/auth"
//                              ({{ name }} captures distinguish the two features)
// ❌ no_cross_feature_import — direct cross-feature import
// ❌ no_banned_imports       — home → auth is banned in config
// ❌ only_import_from_index  — internal file, not via index.dart
import 'package:dart_boundaries_example/features/auth/auth_service.dart';

class HomePage {
  final button = AppButton(label: 'Login', onPressed: () {});
  final locator = Locator();
  final auth = AuthService();
}
