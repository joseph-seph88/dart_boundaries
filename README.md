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

custom_lint:
  rules:
    - layer_boundaries

dart_boundaries:
  layer_boundaries:
    elements:
      - type: feature
        pattern: 'lib/features/{{ name }}'
      - type: shared
        pattern: 'lib/shared/**'
      - type: core
        pattern: 'lib/core/**'
    rules:
      - from: feature
        disallow: [feature]
        allow: [shared, core]
      - from: shared
        allow: [core]
```

**4. Restart your IDE's analysis server** to activate the plugin.

> `custom_lint: rules:` controls which rules are active.  
> `dart_boundaries:` controls each rule's options.  
> After editing `analysis_options.yaml`, restart the analysis server to pick up config changes.

---

## Rules

### `layer_boundaries` *(recommended)*

Define named layer types and declare which types are allowed to import from which.

#### Capture groups — `{{ name }}`

`{{ name }}` in a pattern captures a single path segment. Files with the **same captured value** are treated as the same instance (intra-feature), while files with **different values** are treated as different instances (cross-feature).

```yaml
dart_boundaries:
  layer_boundaries:
    elements:
      - type: feature
        pattern: 'lib/features/{{ name }}'  # captures: auth, home, profile …
      - type: shared
        pattern: 'lib/shared/**'
      - type: core
        pattern: 'lib/core/**'
    rules:
      - from: feature
        disallow: [feature]      # cross-feature (different {{ name }}) is denied
        allow: [shared, core]    # intra-feature imports remain fine
      - from: shared
        allow: [core]
```

```dart
// lib/features/home/home_page.dart  (type: feature, name: home)

// ❌ layer_boundaries — "feature" (home) is not allowed to import from "feature" (auth)
import 'package:app/features/auth/auth_service.dart';

// ✅ OK — intra-feature (same name capture)
import 'package:app/features/home/home_service.dart';

// ✅ OK — shared is in the allow list
import 'package:app/shared/widgets/button.dart';
```

#### `allow` vs `disallow`

| Option | Behavior |
|--------|----------|
| `allow: [shared, core]` | Block every import not in the list (positive list) |
| `disallow: [feature]` | Block only the listed types; everything else is fine (negative list) |
| Both | `disallow` takes precedence; `allow` governs the rest |

#### `default` — global fallback

Controls what happens when a type has no explicit ruling for an import:

| Value | Behavior |
|-------|----------|
| `allow` *(default)* | Types without a `from` rule are unrestricted; `disallow`-only rules block only the listed types |
| `disallow` | Types without a `from` rule block all cross-type imports; `disallow`-only rules also block everything not explicitly `allow`-ed |

```yaml
dart_boundaries:
  layer_boundaries:
    default: disallow   # block everything unless explicitly allowed
    elements:
      - type: feature
        pattern: 'lib/features/{{ name }}'
      - type: shared
        pattern: 'lib/shared/**'
      - type: core
        pattern: 'lib/core/**'
    rules:
      - from: feature
        allow: [shared, core]   # feature may import shared and core only
      - from: shared
        allow: [core]           # shared may import core only
      # core has no rule → default: disallow blocks all cross-type imports from core
```

#### Notes

- Files that match no element pattern are silently skipped.
- Same-instance imports (same type + same captured values) are always allowed even under `default: disallow`.
- When `allow` is specified in a rule it always takes full control of that type regardless of `default`.

| Option | Description |
|--------|-------------|
| `default` | `allow` (default) or `disallow` — global fallback for types without an explicit ruling |
| `elements` | List of `type` / `pattern` definitions |
| `rules` | List of `from` / `allow` / `disallow` entries |

---

### `no_cross_feature_import`

Simpler rule — prevents any file inside one feature folder from importing any file in a different feature folder. No configuration required beyond enabling.

```dart
// ❌ no_cross_feature_import
import 'package:app/features/auth/auth_service.dart';

// ✅ OK — core/ is outside lib/features/
import 'package:app/core/di.dart';
```

| Option | Default | Description |
|--------|---------|-------------|
| `features_path` | `lib/features` | Root path of your feature folders |
| `message` | _(built-in)_ | Override the error message |

---

### `no_banned_imports`

Blocks specific import paths. Each entry maps source files to forbidden imports.

```yaml
dart_boundaries:
  no_banned_imports:
    entries:
      # Global deny — no paths means this applies to ALL files
      - deny: ['lib/core/internal/**']
        message: 'Do not import internal core APIs.'

      # Scoped deny with an exemption
      - paths: ['lib/features/**']
        exclude_paths: ['lib/features/auth/**']   # auth folder is exempt
        deny: ['lib/features/home/**']
        message: 'home → auth is banned.'
```

| Option | Description |
|--------|-------------|
| `paths` | Files the rule applies to. Omit to apply to **all files**. |
| `exclude_paths` | Files to exempt from this entry (optional). |
| `deny` | Import paths to block. |
| `message` | Custom error message (optional). |

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

`pattern`, `paths`, `exclude_paths`, and `deny` values support **glob** wildcards, **capture groups**, or **anchored regular expressions**.

| Pattern | Type | Matches |
|---------|------|---------|
| `lib/features/{{ name }}` | capture | Any file under `lib/features/{name}/`, captures the name |
| `lib/features/*` | glob | Any direct subfolder of `lib/features/` (and its files) |
| `lib/features/**` | glob | Any file anywhere under `lib/features/` |
| `lib/features/*/index.dart` | glob | `index.dart` in any direct feature subfolder |
| `lib/features/auth/.*` | regex | Any file under `lib/features/auth/` (legacy) |
| `package:firebase_core/.*` | regex | Any import from `firebase_core` |

> A pattern with `{{ }}` is treated as a capture pattern.  
> A pattern with `*`/`**` (and no `[`) is treated as a glob.  
> Everything else is used as an anchored regular expression — existing patterns continue to work.
