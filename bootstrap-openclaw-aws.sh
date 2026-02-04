#!/usr/bin/env bash
# Bootstrap script to provision an EC2 instance with OpenClaw (Clawdbot),
# wire it to Discord, OpenAI, GitHub (kanban), and a second-brain repo,
# and register Sasha as a known collaborator.
#
# Run this ON THE EC2 INSTANCE (Ubuntu 22.04 recommended), as your normal user
# (e.g., ubuntu) after you've SSHed in.
#
# Optional env overrides (all optional; missing ones will be skipped):
#   export DISCORD_BOT_TOKEN="..."            # if set, Discord channel will be configured
#   export OPENAI_API_KEY="..."               # if set, OpenAI model will be configured
#   export GITHUB_TOKEN="..."                 # if set, used for GitHub integration
#   export SECOND_BRAIN_REPO_URL="https://github.com/portmi3-ai/second-brain.git"
#   export GITHUB_USERNAME="portmi3-ai"
#   export SASHA_EMAIL="sbot2692@gmail.com"
#   export SASHA_NAME="Sasha"
#
# Usage:
#   chmod +x bootstrap-openclaw-aws.sh
#   ./bootstrap-openclaw-aws.sh
#
# After this completes, the gateway should be running and your second-brain
# repo will be cloned and initialized under ~/.openclaw/workspace/second-brain.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

require_env() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    log_error "Required environment variable '$name' is not set."
    exit 1
  fi
}

ensure_package() {
  local pkg="$1"
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"
  fi
}

install_base_dependencies() {
  log_info "Installing base dependencies (Docker, Git, Node.js 22, curl)..."

  sudo apt-get update -y

  # Docker
  if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker "$USER" || true
    log_warn "You may need to log out and back in for Docker group changes to take effect."
  else
    log_info "Docker already installed."
  fi

  # Docker Compose (standalone) if docker compose not available
  if ! docker compose version >/dev/null 2>&1 2>/dev/null; then
    if ! command -v docker-compose >/dev/null 2>&1; then
      log_info "Installing docker-compose..."
      sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
      sudo chmod +x /usr/local/bin/docker-compose
    else
      log_info "docker-compose already installed."
    fi
  fi

  # Git & curl
  ensure_package git
  ensure_package curl

  # Node.js 22
  if ! command -v node >/dev/null 2>&1; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
  fi

  log_info "Base dependencies installed."
}

clone_openclaw_repo() {
  local target_dir="$HOME/openclaw"

  if [ -d "$target_dir/.git" ]; then
    log_info "openclaw repo already present at $target_dir"
  else
    log_info "Cloning openclaw repo into $target_dir..."
    git clone https://github.com/portmi3-ai/openclaw.git "$target_dir"
  fi

  cd "$target_dir"
}

set_or_update_env_var() {
  local file="$1"
  local key="$2"
  local value="$3"

  if grep -qE "^${key}=" "$file"; then
    # Replace existing line
    sed -i "s|^${key}=.*|${key}=${value}|" "$file"
  else
    # Append
    echo "${key}=${value}" >>"$file"
  fi
}

prepare_env_file() {
  log_info "Preparing .env from .env.template..."

  if [ ! -f ".env" ]; then
    cp .env.template .env
  fi

  # Optional overrides with defaults
  : "${GITHUB_USERNAME:=portmi3-ai}"
  : "${SASHA_NAME:=Sasha}"
  : "${SASHA_EMAIL:=sbot2692@gmail.com}"

  # Generate gateway token if not provided
  if [ -z "${OPENCLAW_GATEWAY_TOKEN:-}" ]; then
    if command -v openssl >/dev/null 2>&1; then
      OPENCLAW_GATEWAY_TOKEN="$(openssl rand -hex 32)"
    elif command -v python3 >/dev/null 2>&1; then
      OPENCLAW_GATEWAY_TOKEN="$(python3 - <<'PY'
import secrets
print(secrets.token_hex(32))
PY
)"
    else
      log_error "Cannot generate OPENCLAW_GATEWAY_TOKEN (missing openssl and python3)."
      exit 1
    fi
  fi

  # Apply values into .env
  set_or_update_env_var ".env" "OPENCLAW_GATEWAY_TOKEN" "${OPENCLAW_GATEWAY_TOKEN}"

  if [ -n "${DISCORD_BOT_TOKEN:-}" ]; then
    set_or_update_env_var ".env" "DISCORD_BOT_TOKEN" "${DISCORD_BOT_TOKEN}"
  else
    log_warn "DISCORD_BOT_TOKEN not set; Discord setup will be skipped."
  fi

  if [ -n "${OPENAI_API_KEY:-}" ]; then
    set_or_update_env_var ".env" "OPENAI_API_KEY" "${OPENAI_API_KEY}"
  else
    log_warn "OPENAI_API_KEY not set; OpenAI model configuration will be skipped."
  fi

  if [ -n "${GITHUB_USERNAME:-}" ]; then
    set_or_update_env_var ".env" "GITHUB_USERNAME" "${GITHUB_USERNAME}"
  fi

  if [ -n "${GITHUB_TOKEN:-}" ]; then
    set_or_update_env_var ".env" "GITHUB_TOKEN" "${GITHUB_TOKEN}"
  else
    log_warn "GITHUB_TOKEN not set; GitHub integration will be limited until configured."
  fi

  # Second brain
  local second_brain_local_path="${SECOND_BRAIN_LOCAL_PATH:-/home/ubuntu/.openclaw/workspace/second-brain}"
  if [ -n "${SECOND_BRAIN_REPO_URL:-}" ]; then
    set_or_update_env_var ".env" "SECOND_BRAIN_REPO_URL" "${SECOND_BRAIN_REPO_URL}"
  else
    log_warn "SECOND_BRAIN_REPO_URL not set; an empty local second-brain folder will be created."
  fi
  set_or_update_env_var ".env" "SECOND_BRAIN_LOCAL_PATH" "${second_brain_local_path}"

  # Primary contacts
  [ -n "${OWNER_NAME:-}" ] && set_or_update_env_var ".env" "OWNER_NAME" "${OWNER_NAME}"
  [ -n "${OWNER_EMAIL:-}" ] && set_or_update_env_var ".env" "OWNER_EMAIL" "${OWNER_EMAIL}"

  set_or_update_env_var ".env" "SASHA_NAME" "${SASHA_NAME}"
  set_or_update_env_var ".env" "SASHA_EMAIL" "${SASHA_EMAIL}"

  log_info ".env prepared with Discord, OpenAI, GitHub, second-brain, and Sasha configured."
}

run_deploy_script() {
  log_info "Running deploy-aws.sh to build and start OpenClaw..."

  chmod +x deploy-aws.sh

  # Build deploy flags based on which env vars are present
  local args=()
  if [ -z "${DISCORD_BOT_TOKEN:-}" ]; then
    args+=(--skip-discord)
  fi
  if [ -z "${OPENAI_API_KEY:-}" ]; then
    args+=(--skip-openai)
  fi

  ./deploy-aws.sh "${args[@]}"

  log_info "deploy-aws.sh completed."
}

setup_second_brain_filesystem() {
  log_info "Setting up second-brain filesystem..."

  # Read desired local path from .env
  # shellcheck disable=SC2046
  set -a
  # shellcheck source=/dev/null
  source .env
  set +a

  local repo_url="${SECOND_BRAIN_REPO_URL:-}"
  local local_path="${SECOND_BRAIN_LOCAL_PATH:-$HOME/.openclaw/workspace/second-brain}"

  mkdir -p "$(dirname "$local_path")"

  if [ -n "$repo_url" ]; then
    if [ -d "$local_path/.git" ]; then
      log_info "Second-brain repo already present at $local_path"
    else
      log_info "Cloning second-brain repo from $repo_url to $local_path..."
      git clone "$repo_url" "$local_path"
    fi
  else
    log_warn "No SECOND_BRAIN_REPO_URL configured; creating empty second-brain folder at $local_path"
    mkdir -p "$local_path"
  fi

  # Create basic structure if not present
  mkdir -p "$local_path/daily" "$local_path/projects" "$local_path/people"
  touch "$local_path/inbox.md"

  # Create/append Sasha's profile
  local sasha_file="$local_path/people/sasha.md"
  if [ ! -f "$sasha_file" ]; then
    log_info "Creating Sasha profile at $sasha_file"
    cat >"$sasha_file" <<EOF
# Sasha

- Email: ${SASHA_EMAIL}
- Role: collaborator
- Notes: Tasks assigned via kanban/Clawdbot.
EOF
  else
    log_info "Sasha profile already exists at $sasha_file"
  fi

  log_info "Second-brain filesystem initialized."
}

main() {
  log_info "Bootstrapping OpenClaw (Clawdbot) on this AWS instance..."

  install_base_dependencies
  clone_openclaw_repo
  prepare_env_file
  run_deploy_script
  setup_second_brain_filesystem

  log_info "Bootstrap complete."
  log_info "Sasha is configured as: ${SASHA_NAME:-Sasha} <${SASHA_EMAIL:-sbot2692@gmail.com}>"
  log_info "Gateway logs: docker compose -f docker-compose.yml -f docker-compose.aws.yml logs -f openclaw-gateway"
}

main "$@"

