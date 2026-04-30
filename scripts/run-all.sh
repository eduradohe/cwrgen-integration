#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
readonly REPO_ROOT="$(cd "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd -P)"

cd "$REPO_ROOT"

"$SCRIPT_DIR/generate-test-keys.sh"
mkdir -p artifacts

docker compose build
docker compose up -d git-server
docker compose run --rm developer-machine bash /tests/happy-path.sh
docker compose run --rm installer-edge-alma9 bash /tests/installer-auto-options.sh
