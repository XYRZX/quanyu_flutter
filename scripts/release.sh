#!/usr/bin/env bash
set -euo pipefail

# quanyu_flutter Release Helper
# Usage:
#   ./scripts/release.sh <version>
# Example:
#   ./scripts/release.sh 0.0.6
# This will:
# - Validate version format (SemVer)
# - Update pubspec.yaml version if needed
# - Commit changes
# - Create tag v<version> at HEAD
# - Push current branch and the tag (recreate remote tag to trigger GitHub Actions)

# 执行（在项目根目录）：
# - ./scripts/release.sh 0.0.6

# --- helpers ---
log()  { printf "\033[1;34m[info]\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m[ ok ]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[warn]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[err ]\033[0m %s\n" "$*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  err "Not a git repository. Please run inside the repo root."
  exit 1
fi

if [[ $# -lt 1 ]]; then
  err "Missing version. Usage: ./scripts/release.sh <version>"
  exit 1
fi
VERSION="$1"
TAG="v$VERSION"

# SemVer (allow pre-release and build metadata)
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([\.-][0-9A-Za-z\.-]+)?(\+[0-9A-Za-z\.-]+)?$ ]]; then
  err "Version '$VERSION' is not a valid SemVer (e.g., 1.2.3, 1.2.3-beta.1)."
  exit 1
fi

# Ensure workflow exists on HEAD
WORKFLOW_FILE=".github/workflows/publish.yml"
if [[ ! -f "$WORKFLOW_FILE" ]]; then
  err "Workflow file $WORKFLOW_FILE not found."
  exit 1
fi
ok "Workflow present: $WORKFLOW_FILE"

# Detect current branch
BRANCH="$(git branch --show-current 2>/dev/null || true)"
if [[ -z "$BRANCH" ]]; then BRANCH="master"; fi
ok "Current branch: $BRANCH"

# Ensure origin exists
if ! git remote get-url origin >/dev/null 2>&1; then
  err "Remote 'origin' not configured. Please add your GitHub repo as origin."
  exit 1
fi
ORIGIN_URL="$(git remote get-url origin)"
ok "Origin: $ORIGIN_URL"

# Update pubspec.yaml version if needed
PUBSPEC="pubspec.yaml"
if [[ ! -f "$PUBSPEC" ]]; then
  err "$PUBSPEC not found at repo root."
  exit 1
fi

CURRENT_VER_LINE="$(grep -E '^version:' "$PUBSPEC" || true)"
CURRENT_VER="${CURRENT_VER_LINE#version: }"
CURRENT_VER="${CURRENT_VER## }"
if [[ -z "$CURRENT_VER" ]]; then
  warn "No version line found in $PUBSPEC; will insert one."
fi

if [[ "$CURRENT_VER" != "$VERSION" ]]; then
  log "Updating $PUBSPEC version: $CURRENT_VER -> $VERSION"
  awk -v ver="$VERSION" '
    BEGIN{done=0}
    {
      if(done==0 && $0 ~ /^version:[[:space:]]*/){
        print "version: " ver; done=1;
      } else {
        print $0;
      }
    }
    END{
      if(done==0){ print "version: " ver }
    }
  ' "$PUBSPEC" > "$PUBSPEC.tmp" && mv "$PUBSPEC.tmp" "$PUBSPEC"
  git add "$PUBSPEC"
else
  ok "pubspec.yaml already at version $VERSION"
fi

# Commit if there are staged changes
if ! git diff --staged --quiet; then
  git commit -m "chore: release $VERSION (pub.dev automated publishing)"
  ok "Committed version bump."
else
  log "No changes to commit."
fi

# Ensure tag points to HEAD and contains workflow
HEAD_SHA="$(git rev-parse HEAD)"
log "Creating/Updating tag $TAG at $HEAD_SHA"
if git rev-parse "$TAG" >/dev/null 2>&1; then
  git tag -f "$TAG" "$HEAD_SHA"
else
  git tag "$TAG" "$HEAD_SHA"
fi

# Push branch first
log "Pushing branch $BRANCH ..."
git push -u origin "$BRANCH"

# Delete remote tag if exists, then push anew (ensures GH Actions picks up)
log "Refreshing remote tag $TAG ..."
(git push origin ":refs/tags/$TAG" >/dev/null 2>&1 || true)
git push origin "$TAG"

# Derive Actions URL from origin
OWNER_REPO=""
if [[ "$ORIGIN_URL" =~ ^git@github.com:([^/]+)/([^\.]+)(\.git)?$ ]]; then
  OWNER_REPO="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
elif [[ "$ORIGIN_URL" =~ ^https://github.com/([^/]+)/([^\.]+)(\.git)?$ ]]; then
  OWNER_REPO="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
fi

ACTIONS_URL=""
if [[ -n "$OWNER_REPO" ]]; then
  ACTIONS_URL="https://github.com/${OWNER_REPO}/actions"
fi

ok "Done."
if [[ -n "$ACTIONS_URL" ]]; then
  echo "Open Actions: $ACTIONS_URL"
else
  echo "Open your repository Actions page to monitor the workflow run."
fi