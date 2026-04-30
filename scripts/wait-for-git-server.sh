#!/usr/bin/env bash
set -euo pipefail

host="${1:-git-server}"
port="${2:-22}"
deadline=$((SECONDS + 60))

while (( SECONDS < deadline )); do
  if ssh -o StrictHostKeyChecking=no -o BatchMode=yes -p "$port" "git@$host" true >/dev/null 2>&1; then
    exit 0
  fi
  sleep 1
done

echo "Timed out waiting for git server at $host:$port" >&2
exit 1
