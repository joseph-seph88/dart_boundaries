// ✅ OK — shared and core are in the allow list for feature
import 'package:dart_boundaries_example/shared/widgets/button.dart';
import 'package:dart_boundaries_example/core/di.dart';

// ❌ layer_boundaries   — feature is not allowed to import from feature
// ❌ no_cross_feature_import — direct cross-feature import
// ❌ no_banned_imports  — home → auth is explicitly banned
// ❌ only_import_from_index — internal file, not via index.dart
import 'package:dart_boundaries_example/features/auth/auth_service.dart';

class HomePage {
  final button = AppButton(label: 'Login', onPressed: () {});
  final locator = Locator();
  final auth = AuthService();
}
