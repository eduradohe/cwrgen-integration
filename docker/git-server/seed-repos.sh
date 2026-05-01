#!/usr/bin/env bash
set -euo pipefail

readonly GIT_ROOT="/srv/git"
readonly WORK_ROOT="/tmp/seed-work"

create_repo() {
  local repo_name="$1"
  local author_email="$2"
  local repo_dir="$WORK_ROOT/$repo_name"
  local bare_repo="$GIT_ROOT/$repo_name.git"

  rm -rf "$repo_dir" "$bare_repo"
  mkdir -p "$repo_dir"

  git init --initial-branch=main "$repo_dir" >/dev/null
  git -C "$repo_dir" config user.name "Fixture Developer"
  git -C "$repo_dir" config user.email "$author_email"

  cat >"$repo_dir/README.md" <<EOF
# $repo_name
EOF
  git -C "$repo_dir" add README.md
  GIT_AUTHOR_DATE="2026-03-15T09:00:00Z" \
    GIT_COMMITTER_DATE="2026-03-15T09:00:00Z" \
    git -C "$repo_dir" commit -m "Initial commit outside report range" >/dev/null

  mkdir -p "$repo_dir/src"
  cat >"$repo_dir/src/reportable.txt" <<EOF
Reportable content for $repo_name.
EOF
  git -C "$repo_dir" add src/reportable.txt
  GIT_AUTHOR_DATE="2026-04-10T10:00:00Z" \
    GIT_COMMITTER_DATE="2026-04-10T10:00:00Z" \
    git -C "$repo_dir" commit -m "Add reportable work" >/dev/null

  cat >"$repo_dir/src/other-author.txt" <<EOF
This file should not appear for the main test author.
EOF
  git -C "$repo_dir" add src/other-author.txt
  GIT_AUTHOR_NAME="Other Developer" \
    GIT_AUTHOR_EMAIL="other@example.test" \
    GIT_COMMITTER_NAME="Other Developer" \
    GIT_COMMITTER_EMAIL="other@example.test" \
    GIT_AUTHOR_DATE="2026-04-12T10:00:00Z" \
    GIT_COMMITTER_DATE="2026-04-12T10:00:00Z" \
    git -C "$repo_dir" commit -m "Add unrelated author work" >/dev/null

  git init --bare --initial-branch=main "$bare_repo" >/dev/null
  git -C "$repo_dir" remote add origin "$bare_repo"
  git -C "$repo_dir" push -u origin HEAD:main >/dev/null
  git --git-dir="$bare_repo" symbolic-ref HEAD refs/heads/main
}

mkdir -p "$GIT_ROOT" "$WORK_ROOT"
create_repo example-api dev@example.test
create_repo example-ui dev@example.test
