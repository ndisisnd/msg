#!/usr/bin/env bash
# ship-db-touch.sh — report database / persistence files touched in the diff vs base.
# Usage: ship-db-touch.sh [base-ref]    (default base: origin/main)
# Prints matched file paths (one per line). Empty output = no database files touched.
#
# Forces a ship guardrail pause when non-empty: migrations, schema, ORM
# models/entities, and seed/fixture data all materially affect production.
set -euo pipefail

base="${1:-origin/main}"

# Fall back to a usable base if the requested ref is unknown locally.
if ! git rev-parse --verify --quiet "$base" >/dev/null 2>&1; then
  base="$(git rev-parse --verify --quiet HEAD~1 2>/dev/null || echo HEAD)"
fi

git diff --name-only "$base"...HEAD 2>/dev/null \
  | grep -E '(^|/)(migrations|seeds|fixtures|entities|models)/|\.sql$|(^|/)schema\.prisma$|\.entity\.[A-Za-z0-9]+$|(^|/)seed\.[A-Za-z0-9]+$|supabase/migrations/' \
  || true
