#!/usr/bin/env bash
#
# Build the Flutter web app and deploy it to the "gh-pages" branch so it is
# served by GitHub Pages at https://abasty.github.io/minterm/
#
# Usage: ./deploy-minterm.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

REMOTE="origin"
BRANCH="gh-pages"
BASE_HREF="/minterm/"
WORKTREE_DIR="$(mktemp -d)"

cleanup() {
  git worktree remove --force "$WORKTREE_DIR" >/dev/null 2>&1 || true
  rm -rf "$WORKTREE_DIR"
}
trap cleanup EXIT

echo "==> Building Flutter web app (release, base-href $BASE_HREF)"
flutter build web --release --base-href "$BASE_HREF"

echo "==> Fetching $REMOTE/$BRANCH"
git fetch "$REMOTE" "$BRANCH" >/dev/null 2>&1 || true

if git show-ref --verify --quiet "refs/remotes/$REMOTE/$BRANCH"; then
  echo "==> Checking out existing $BRANCH into worktree"
  git worktree add --force -B "$BRANCH" "$WORKTREE_DIR" "$REMOTE/$BRANCH"
else
  echo "==> $BRANCH does not exist yet, creating orphan branch"
  git worktree add --detach "$WORKTREE_DIR" main
  (cd "$WORKTREE_DIR" && git checkout --orphan "$BRANCH" && git rm -rf . >/dev/null)
fi

echo "==> Syncing build/web into $BRANCH worktree"
find "$WORKTREE_DIR" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +
cp -a build/web/. "$WORKTREE_DIR/"
touch "$WORKTREE_DIR/.nojekyll"

cd "$WORKTREE_DIR"
git add -A
if git diff --cached --quiet; then
  echo "==> Nothing changed, skipping commit/push"
else
  git commit -m "Deploy $(cd "$REPO_ROOT" && git rev-parse --short HEAD)"
  git push "$REMOTE" "$BRANCH"
  echo "==> Deployed to https://abasty.github.io/minterm/"
fi
