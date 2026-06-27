# dart_boundaries

> Enforce import boundaries between features and layers in Dart & Flutter projects.  
> Inspired by [eslint-plugin-boundaries](https://github.com/javierbrea/eslint-plugin-boundaries).

**Author:** Joseph88 — pathetic.sim@gmail.com · **License:** MIT

---

## Why

Feature-based architectures break down when features start importing directly from each other.  
`dart_boundaries` adds lint rules that catch these violations live in your IDE.

```
lib/
  features/
    auth/         ← should not know about home
    home/         ← should not know about auth
  shared/         ← widgets, utilities — usable by features
  core/           ← DI, config — usable by all
```

---

## Installation

**1. Add to `pubspec.yaml`:**

```yaml
dev_dependencies:
  custom_lint: '>=0.8.0 <1.0.0'
  dart_boundaries: ^0.1.0
```

**2. Run:**

```sh
dart pub get
```

**3. Enable the plugin and configure rules in `analysis_options.yaml`:**

```yaml
analyzer:
  plugins:
    - custom_lint

# Enable the rules you want (all rules are off by default)
custom_lint:
  rules:
    - layer_boundaries

# Configure each rule under the dart_boundaries: key
dart_boundaries:
  layer_boundaries:
    elements:
      - type: feature
        pattern: 'lib/features/*'
      - type: shared
        pattern: 'lib/shared/**'
      - type: core
        pattern: 'lib/core/**'
    rules:
      - from: feature
        allow: [shared, core]
      - from: shared
        allow: [core]
```

**4. Restart your IDE's analysis server** to activate the plugin.

> `custom_lint: rules:` controls which rules are active.  
> `dart_boundaries:` controls each rule's options.

---

## Rules

### `layer_boundaries` *(recommended)*

Define named layer types and declare which types are allowed to import from which. Any import that violates the declared rules is flagged.

```yaml
dart_boundaries:
  layer_boundaries:
    elements:
      - type: feature
        pattern: 'lib/features/*'   # * = one direct subfolder
      - type: shared
        pattern: 'lib/shared/**'    # ** = any depth
      - type: core
        pattern: 'lib/core/**'
    rules:
      - from: feature
        allow: [shared, core]   # feature may import shared and core
      - from: shared
        allow: [core]           # shared may only import core
                                # core has no rule → no restriction
```

```dart
// lib/features/home/home_page.dart  (type: feature)

// ❌ layer_boundaries — feature → feature is not in the allow list
import 'package:app/features/auth/auth_service.dart';

// ✅ OK — shared is in the allow list
import 'package:app/shared/widgets/button.dart';
```

**Notes:**
- Files that do not match any `elements` pattern are silently skipped.
- Imports within the same type (e.g. feature → feature *same file*) are always allowed.
- A type with no `rules` entry has no restrictions.

| Option | Description |
|--------|-------------|
| `elements` | List of `type` / `pattern` definitions |
| `rules` | List of `from` / `allow` entries |

---

### `no_cross_feature_import`

Simpler rule — prevents any file inside one feature folder from importing any file in a different feature folder.

```dart
// ❌ no_cross_feature_import
import 'package:app/features/auth/auth_service.dart';

// ✅ OK — core/ is outside lib/features/
import 'package:app/core/di/locator.dart';
```

| Option | Default | Description |
|--------|---------|-------------|
| `features_path` | `lib/features` | Root path of your feature folders |
| `message` | _(built-in)_ | Override the error message |

---

### `no_banned_imports`

Blocks specific import paths. Each entry maps source files (`paths`) to forbidden imports (`deny`).

```yaml
dart_boundaries:
  no_banned_imports:
    entries:
      - paths:
          - 'lib/features/home/**'
        deny:
          - 'lib/features/auth/**'
        message: 'home → auth import is banned.'
      - paths:
          - 'lib/**'
        deny:
          - 'package:firebase_core/.*'
        message: 'Firebase must only be used in the infra/ layer.'
```

**Quick fix:** removes the banned import line.

---

### `only_import_from_index`

When importing from another feature, only its `index.dart` barrel file is allowed.

```dart
// ❌ only_import_from_index
import 'package:app/features/auth/data/auth_repository.dart';

// ✅ OK
import 'package:app/features/auth/index.dart';
```

| Option | Default | Description |
|--------|---------|-------------|
| `features_path` | `lib/features` | Root path of your feature folders |

**Quick fix:** rewrites the import to point at the feature's `index.dart`.

> Files named `index.dart` are exempt.

---

## Suppressing a violation

```dart
// ignore: layer_boundaries
import 'package:app/features/auth/auth_service.dart';
```

Or for the whole file:

```dart
// ignore_for_file: layer_boundaries
```

---

## Pattern syntax

`pattern`, `paths`, and `deny` values support **glob** wildcards or **anchored regular expressions**.

| Pattern | Type | Matches |
|---------|------|---------|
| `lib/features/*` | glob | Any direct subfolder of `lib/features/` (and its files) |
| `lib/features/**` | glob | Any file anywhere under `lib/features/` |
| `lib/features/*/index.dart` | glob | `index.dart` in any direct feature subfolder |
| `lib/features/auth/.*` | regex | Any file under `lib/features/auth/` (legacy) |
| `package:firebase_core/.*` | regex | Any import from `firebase_core` |

> If the pattern contains `*` or `**` (and no `[` character classes), it is treated as a glob.  
> Otherwise it is used as an anchored regular expression — existing regex patterns continue to work.
