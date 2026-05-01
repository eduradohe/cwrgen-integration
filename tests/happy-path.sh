#!/usr/bin/env bash
set -euo pipefail

export HOME=/root
export CWGEN_SOURCE="${CWGEN_SOURCE:-/workspace/cwgen}"
export REPORT_TARGET="202604"
export WORK_ROOT="/workspace/work"
export OUTPUT_ROOT="/workspace/artifacts/output"
export REPOS_FILE="/workspace/repos.properties"
export CONFIG_FILE="/workspace/cwgen.properties"

setup_ssh() {
  local attempt
  local host="${CWR_GIT_HOST:-git-server}"
  local port="${CWR_GIT_PORT:-22}"

  mkdir -p "$HOME/.ssh"
  cp /tmp/client_key "$HOME/.ssh/id_ed25519"
  cp /tmp/client_key.pub "$HOME/.ssh/id_ed25519.pub"
  chmod 700 "$HOME/.ssh"
  chmod 600 "$HOME/.ssh/id_ed25519"
  chmod 644 "$HOME/.ssh/id_ed25519.pub"

  for attempt in {1..30}; do
    if ssh-keyscan -p "$port" "$host" >>"$HOME/.ssh/known_hosts" 2>/dev/null; then
      return
    fi
    sleep 1
  done

  echo "Timed out waiting for SSH test server at $host:$port" >&2
  exit 1
}

write_config() {
  cat >"$CONFIG_FILE" <<EOF
repo_base_url=ssh://${CWR_GIT_USER:-git}@${CWR_GIT_HOST:-git-server}:${CWR_GIT_PORT:-22}/srv/git
repos_file=$REPOS_FILE
workspace_dir=$WORK_ROOT/repos
evidence_dir=$WORK_ROOT/evidence
output_root=$OUTPUT_ROOT
replace_output=true
EOF

  cat >"$REPOS_FILE" <<'EOF'
example-api=example-api.git
example-ui=example-ui.git
EOF
}

assert_file_exists() {
  local path="$1"
  [[ -f "$path" ]] || {
    echo "Expected file to exist: $path" >&2
    exit 1
  }
}

assert_file_not_empty() {
  local path="$1"
  [[ -s "$path" ]] || {
    echo "Expected file to be non-empty: $path" >&2
    exit 1
  }
}

setup_ssh
write_config

"$CWGEN_SOURCE/install" \
  --prefix /opt/cwgen \
  --setup-environment \
  --non-interactive \
  --setup-package-manager dnf \
  --setup-git-user-name "Fixture Developer" \
  --setup-git-user-email dev@example.test \
  --setup-ssh-private-key "$HOME/.ssh/id_ed25519" \
  --setup-ssh-public-key "$HOME/.ssh/id_ed25519.pub" \
  --force-config \
  --no-update-profile

/opt/cwgen/bin/cwrgen \
  --config "$CONFIG_FILE" \
  --author dev@example.test \
  --start-date 2026-04-01 \
  --target "$REPORT_TARGET"

assert_file_not_empty "$OUTPUT_ROOT/$REPORT_TARGET/evidence/example-api-evidence.diff"
assert_file_not_empty "$OUTPUT_ROOT/$REPORT_TARGET/evidence/example-ui-evidence.diff"
assert_file_exists "$OUTPUT_ROOT/$REPORT_TARGET/evidence/example-api-evidence.tar.gz"
assert_file_exists "$OUTPUT_ROOT/$REPORT_TARGET/evidence/example-ui-evidence.tar.gz"
grep -q "Add reportable work" "$OUTPUT_ROOT/$REPORT_TARGET/evidence/example-api-evidence.diff"
