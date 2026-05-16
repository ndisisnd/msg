#!/usr/bin/env bash
# plan-em-eng-scan.sh — codebase scan for plan-em Step 1
#
# Searches the codebase for API routes, schema/migration files, auth patterns,
# webhooks/hooks, and feature flags. Outputs structured markdown for plan-em
# to interpret during pre-flight.
#
# Usage:  plan-em-eng-scan.sh [search-root]
#         search-root defaults to . (project root)
# Output: markdown to stdout; truncated per section to stay readable
#
# Run from the project root.

set -euo pipefail

ROOT="${1:-.}"

EXCL_DIRS=(
  --exclude-dir=node_modules
  --exclude-dir=.git
  --exclude-dir=dist
  --exclude-dir=build
  --exclude-dir=.next
  --exclude-dir=.nuxt
  --exclude-dir=vendor
  --exclude-dir=__pycache__
  --exclude-dir=coverage
  --exclude-dir=.cache
  --exclude-dir=.turbo
)

EXCL_FIND='/(node_modules|\.git|dist|build|\.next|\.nuxt|vendor|__pycache__|coverage|\.cache|\.turbo)/'

CODE_INCLUDES=(
  --include="*.ts" --include="*.tsx"
  --include="*.js" --include="*.jsx"
  --include="*.py" --include="*.rb"
  --include="*.go" --include="*.java"
  --include="*.kt" --include="*.swift"
  --include="*.cs" --include="*.php"
)

CONFIG_INCLUDES=(
  --include="*.yaml" --include="*.yml"
  --include="*.json" --include="*.toml"
  --include="*.graphql" --include="*.gql"
  --include="*.prisma"
)

# --- helpers ---

section()    { printf '\n## %s\n\n' "$1"; }
subsection() { printf '### %s\n\n' "$1"; }

grep_code() {
  local pattern="$1" limit="${2:-40}"
  grep -rn "${EXCL_DIRS[@]}" "${CODE_INCLUDES[@]}" -E "$pattern" "$ROOT" \
    2>/dev/null | head -"$limit" || true
}

grep_config() {
  local pattern="$1" limit="${2:-20}"
  grep -rn "${EXCL_DIRS[@]}" "${CONFIG_INCLUDES[@]}" -E "$pattern" "$ROOT" \
    2>/dev/null | head -"$limit" || true
}

find_named() {
  find "$ROOT" -type f -name "$1" \
    | grep -vE "$EXCL_FIND" \
    | head -15 \
    || true
}

find_dirs() {
  find "$ROOT" -type d -name "$1" \
    | grep -vE "$EXCL_FIND" \
    | head -10 \
    || true
}

emit() {
  if [[ -n "$1" ]]; then
    printf '```\n%s\n```\n\n' "$1"
  else
    printf '_No matches._\n\n'
  fi
}

# --- report ---

printf '# Codebase Scan — plan-em pre-flight\n\n'
printf 'Root: `%s`\n\n' "$(cd "$ROOT" && pwd)"
printf '---\n\n'

# =============================================================
section "1. API Routes and Endpoints"

subsection "Express / Koa / Hapi route registrations"
emit "$(grep_code '\b(app|router|Route)\.(get|post|put|patch|delete|use|all)\s*\(')"

subsection "Decorator-based routes (NestJS, FastAPI, Spring, ASP.NET)"
emit "$(grep_code '@(Get|Post|Put|Patch|Delete|GetMapping|PostMapping|PutMapping|DeleteMapping|PatchMapping|RequestMapping|app\.route|Controller)\b')"

subsection "Named route / URL config files"
emit "$(
  find_named 'routes.rb'
  find_named 'urls.py'
  find_named 'router.ts'
  find_named 'router.js'
  find_named 'routes.ts'
  find_named 'routes.js'
)"

subsection "OpenAPI / GraphQL schema files"
emit "$(
  find_named 'openapi.yaml'
  find_named 'openapi.yml'
  find_named 'swagger.yaml'
  find_named 'swagger.yml'
  find_named '*.graphql'
  find_named '*.gql'
)"

# =============================================================
section "2. Database Schemas and Migrations"

subsection "Migration directories"
emit "$(find_dirs 'migrations'; find_dirs 'migrate'; find_dirs 'db')"

subsection "Schema definition files"
emit "$(
  find_named 'schema.prisma'
  find_named 'schema.rb'
  find_named '*.migration.ts'
  find_named '*.migration.js'
)"

subsection "ORM model / entity decorators"
emit "$(grep_code '@(Entity|Table|Column|PrimaryColumn|PrimaryGeneratedColumn|ManyToOne|OneToMany|OneToOne|Model)\b')"

subsection "Schema constructor calls (Mongoose, Sequelize)"
emit "$(grep_code 'new Schema\s*\(|Model\.define\s*\(|sequelize\.define\s*\(|DataTypes\.\w+')"

# =============================================================
section "3. Authentication Patterns"

subsection "Middleware and guards"
emit "$(grep_code '\b(authenticate|authorize|AuthGuard|requireAuth|isAuthenticated|verifyToken|checkAuth|authMiddleware|UseGuards)\b')"

subsection "JWT handling"
emit "$(grep_code '\b(jwt\.sign|jwt\.verify|jsonwebtoken|JwtStrategy|JwtModule|JwtService|decode_jwt|verify_jwt)\b')"

subsection "Session and OAuth"
emit "$(grep_code '\b(passport\.authenticate|express-session|session\.cookie|OAuth2|oauth2|refresh_token|access_token|OAuthProvider)\b')"

# =============================================================
section "4. Webhooks and Event Hooks"

subsection "Webhook dispatch"
emit "$(grep_code '\b(webhook|sendWebhook|dispatchWebhook|triggerWebhook|notifyWebhook|webhookUrl)\b')"

subsection "Event emitters and bus"
emit "$(grep_code '\b(EventEmitter|eventBus|EventBus|\.emit\s*\(|\.on\s*\(|\.subscribe\s*\(|\.publish\s*\()\b')"

subsection "Lifecycle and platform hooks"
emit "$(grep_code '\b(beforeCreate|afterCreate|beforeSave|afterSave|beforeUpdate|afterUpdate|beforeDestroy|afterDestroy|onMount|componentDidMount|useEffect)\b')"

# =============================================================
section "5. Feature Flags and Remote Config"

subsection "Generic flag checks"
emit "$(grep_code '\b(featureFlag|feature_flag|isFeatureEnabled|isFlagEnabled|isEnabled|FeatureToggle|flagEnabled|getFlag)\b')"

subsection "Known flag platforms (LaunchDarkly, Unleash, Statsig, PostHog, Flipper)"
emit "$(grep_code '\b(ldClient|LDClient|launchDarkly|LaunchDarkly|unleash|Unleash|statsig|Statsig|posthog\.isFeatureEnabled|Flipper|flipper)\b')"

subsection "SCREAMING_SNAKE_CASE flag keys"
emit "$(grep_code 'FEATURE_[A-Z_]{2,}|FLAG_[A-Z_]{2,}')"
