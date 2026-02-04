#!/usr/bin/env bash
set -euo pipefail

# Validates the systemd unit content that OpenClaw generates.
# This is enforced in CI + pre-commit + deployment scripts.

UNIT_PATH="${1:-systemd/openclaw.service.template}"

if [[ ! -f "$UNIT_PATH" ]]; then
  echo "[FAIL] Unit template not found: $UNIT_PATH"
  exit 1
fi

UNIT_CONTENT="$(cat "$UNIT_PATH")"

fail() { echo "[FAIL] $1"; exit 1; }
pass() { echo "[PASS] $1"; }

# Invariants
if echo "$UNIT_CONTENT" | grep -Eiq '^\s*Type\s*=\s*oneshot\s*$'; then
  fail "Type=oneshot is forbidden for openclaw.service"
fi

if echo "$UNIT_CONTENT" | grep -Eiq '^\s*RemainAfterExit\s*='; then
  fail "RemainAfterExit is forbidden for openclaw.service"
fi

if ! echo "$UNIT_CONTENT" | grep -Eiq '^\s*ExecStart\s*=.*DEPLOY_NOW\.sh'; then
  fail "ExecStart must invoke DEPLOY_NOW.sh"
fi

if echo "$UNIT_CONTENT" | grep -Eiq 'ExecStart\s*=.*docker(\s+|-)compose.*up\s+-d'; then
  fail "ExecStart must NOT run 'docker compose up -d' directly"
fi

if ! echo "$UNIT_CONTENT" | grep -Eiq '^\s*Restart\s*=\s*(always|on-failure)\s*$'; then
  fail "Restart must be always or on-failure"
fi

if ! echo "$UNIT_CONTENT" | grep -Eiq '^\s*RestartSec\s*='; then
  fail "RestartSec must be set"
fi

pass "openclaw.service invariant satisfied ($UNIT_PATH)"
