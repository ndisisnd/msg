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

| Q2 answer | Section to append |
|-----------|-------------------|
| Web (frontend) | Web |
| Mobile (iOS/Android) | Mobile |
| Backend API | Backend |
| CLI | CLI |
| Other | none |
