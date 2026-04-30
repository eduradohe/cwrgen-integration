#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
readonly REPO_ROOT="$(cd "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd -P)"
readonly KEY_DIR="$REPO_ROOT/fixtures/keys"
readonly KEY_FILE="$KEY_DIR/id_ed25519"

mkdir -p "$KEY_DIR"

if [[ -f "$KEY_FILE" ]]; then
  echo "Test key already exists: $KEY_FILE"
  exit 0
fi

ssh-keygen -t ed25519 -N "" -C "cwgen-integration@example.test" -f "$KEY_FILE"
chmod 600 "$KEY_FILE"
chmod 644 "$KEY_FILE.pub"
