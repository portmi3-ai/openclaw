#!/usr/bin/env bash
# OpenClaw Supervisor Script (Long-Running)
# This script runs as a systemd service to supervise OpenClaw containers.
# It ensures containers are always running and handles restarts.
# Run this ON THE EC2 INSTANCE: curl -fsSL https://raw.githubusercontent.com/portmi3-ai/openclaw/main/DEPLOY_NOW.sh | bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

OPENCLAW_DIR="${OPENCLAW_DIR:-/home/ec2-user/openclaw}"

# Ensure we're in the OpenClaw directory
cd "$OPENCLAW_DIR" || {
    log_error "Cannot access OpenClaw directory: $OPENCLAW_DIR"
    exit 1
}

# ============================================================================
# Install systemd unit from template
# ============================================================================
log_info "Installing OpenClaw systemd unit from template"

# Validate the template before installing
if [ -f "scripts/validate_openclaw_systemd_unit.sh" ]; then
    chmod +x scripts/validate_openclaw_systemd_unit.sh
    if ! ./scripts/validate_openclaw_systemd_unit.sh systemd/openclaw.service.template; then
        log_error "Systemd unit template validation failed!"
        exit 1
    fi
    log_info "Systemd unit template validated ✓"
else
    log_warn "Validator script not found, skipping validation"
fi

# Install the template as the systemd service
if [ -f "systemd/openclaw.service.template" ]; then
    sudo install -m 0644 systemd/openclaw.service.template /etc/systemd/system/openclaw.service
    log_info "Systemd service file installed from template ✓"
else
    log_error "Systemd template not found: systemd/openclaw.service.template"
    exit 1
fi

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable openclaw.service

log_info "Systemd service installed and enabled ✓"

# ============================================================================
# Supervisor Loop (Long-Running)
# ============================================================================
log_info "Entering OpenClaw supervisor loop"

while true; do
    # Check if OpenClaw containers are running
    if ! docker ps --format '{{.Names}}' | grep -q openclaw; then
        log_warn "OpenClaw containers not running, starting..."
        
        # Try to start containers
        if [ -f "docker-compose.yml" ]; then
            if command -v docker &> /dev/null && docker compose version >/dev/null 2>&1; then
                docker compose -f docker-compose.yml -f docker-compose.aws.yml up -d || log_error "Failed to start containers with docker compose"
            elif command -v docker-compose &> /dev/null; then
                docker-compose -f docker-compose.yml -f docker-compose.aws.yml up -d || log_error "Failed to start containers with docker-compose"
            else
                log_error "Neither 'docker compose' nor 'docker-compose' found"
            fi
        else
            log_error "docker-compose.yml not found in $OPENCLAW_DIR"
        fi
        
        # Wait a bit and verify
        sleep 5
        if docker ps --format '{{.Names}}' | grep -q openclaw; then
            log_info "Containers started successfully"
        else
            log_error "Failed to start containers"
        fi
    fi
    
    # Sleep before next check
    sleep 30
done
