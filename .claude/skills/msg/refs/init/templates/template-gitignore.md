---
name: gitignore Template
description: .gitignore content keyed by platform/stack. Universal section is always included; per-stack section is appended based on Q2 answer.
type: reference
---

# .gitignore Template

The skill writes `.gitignore` by concatenating the **Universal** section with one **Stack** section selected from the Q2 answer.

## Universal section (always included)

```
# OS files
.DS_Store
Thumbs.db
desktop.ini

# Editor and IDE
.vscode/
.idea/
*.swp
*.swo
*~

# Environment and secrets
.env
.env.local
.env.*.local
*.pem
*.key
secrets/

# Logs
*.log
logs/

# Build output
dist/
build/
out/

# msg skill artifacts
.pre-merge/
INTAKE.md
INTAKE-UPDATE.md
```

## Stack sections

### Web (frontend) — Node/TypeScript

```
node_modules/
.next/
.nuxt/
.cache/
.parcel-cache/
.svelte-kit/
coverage/
*.tsbuildinfo
.eslintcache
```

### Dart / Flutter (Mobile)

```
# Flutter / Dart
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.packages
pubspec.lock

# Build artifacts
*.dill

# iOS
ios/Pods/
ios/Flutter/Flutter.framework
ios/Flutter/Flutter.podspec
*.xcworkspace
DerivedData/
*.ipa
*.dSYM.zip

# Android
android/.gradle/
android/local.properties
android/captures/
*.apk
*.aab
*.keystore

# Coverage
coverage/
```

### Mobile (iOS/Android)

```
# iOS
Pods/
*.xcworkspace
DerivedData/
*.ipa
*.dSYM.zip

# Android
.gradle/
local.properties
captures/
*.apk
*.aab
*.keystore
```

### Backend API

```
node_modules/
__pycache__/
*.pyc
.venv/
venv/
target/
vendor/
coverage/
.pytest_cache/
.mypy_cache/
```

### CLI

```
target/
bin/
*.exe
*.out
node_modules/
__pycache__/
*.pyc
```

### Other / unknown

If Q2 returns "Other" or no stack hint matched, include only the Universal section. The user fills in stack-specific patterns later.

## Selection rule

Language-specific sections take priority over platform sections in `init.sh`.

| Q2b (LANGUAGE) answer | Q2 (PLATFORM) answer | Section to append |
|-----------------------|---------------------|-------------------|
| Flutter / Dart | any | Dart / Flutter |
| (any other) | Web (frontend) | Web |
| (any other) | Mobile (iOS/Android) | Mobile |
| (any other) | Backend API | Backend API |
| (any other) | CLI | CLI |
| (any other) | Other | none |
