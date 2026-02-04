#!/usr/bin/env bash
# OpenClaw Supervisor Script (Long-Running)
# This script runs as a systemd service to supervise OpenClaw containers.
# It ensures containers are always running and handles restarts.
# Run this ON THE EC2 INSTANCE: curl -fsSL https://raw.githubusercontent.com/portmi3-ai/openclaw/main/DEPLOY_NOW.sh | bash

set -euo pipefail

#############################################
# OpenClaw Deployment Script
# OS-Aware Bootstrap (AL2023 Compatible)
#############################################

echo "[INFO] =========================================="
echo "[INFO] OpenClaw OS Detection"
echo "[INFO] =========================================="

if [ -f /etc/os-release ]; then
  . /etc/os-release
  echo "[INFO] Detected OS: $PRETTY_NAME"
else
  echo "[WARN] Unable to detect OS via /etc/os-release"
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_step()  { echo -e "${BLUE}[STEP]${NC} $*"; }

INSTANCE_IP="3.139.76.200"
REPO_URL="https://github.com/portmi3-ai/openclaw.git"

log_step "=========================================="
log_step "OpenClaw Complete Deployment"
log_step "=========================================="
echo ""

# Check if running as ec2-user
if [ "$USER" != "ec2-user" ]; then
    log_warn "Running as $USER, expected ec2-user. Continuing anyway..."
fi

# ============================================================================
# STEP 1: Ensure we're in the right directory
# ============================================================================
log_step "Step 1: Setting up repository..."

if [ -d "$HOME/openclaw" ]; then
    cd "$HOME/openclaw"
    log_info "Found existing openclaw directory"
    
    # Point to user's fork
    if git remote get-url origin 2>/dev/null | grep -q "portmi3-ai"; then
        log_info "Repository already pointing to fork"
    else
        log_info "Updating remote to point to fork..."
        git remote set-url origin "$REPO_URL" 2>/dev/null || git remote add origin "$REPO_URL"
    fi
    
    # Pull latest
    log_info "Pulling latest changes..."
    git pull origin main || log_warn "Git pull had issues, continuing..."
else
    log_info "Cloning repository..."
    cd "$HOME"
    git clone "$REPO_URL" openclaw
    cd openclaw
fi

# ============================================================================
# STEP 2: Ensure Docker is running
# ============================================================================
log_step "Step 2: Checking Docker..."

if ! command -v docker >/dev/null 2>&1; then
    log_info "Docker not found. Installing Docker..."

    if grep -q "Amazon Linux 2023" /etc/os-release 2>/dev/null; then
        log_info "Using dnf installer for Amazon Linux 2023"
        sudo dnf update -y
        sudo dnf install -y docker
    else
        log_info "Using Docker convenience script"
        curl -fsSL https://get.docker.com | sh
    fi

    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker ec2-user

    log_info "Docker installation complete."
    log_info "NOTE: You must log out and back in for docker group permissions to apply."
else
    log_info "Docker already installed"
fi

if ! docker compose version >/dev/null 2>&1; then
    if grep -q "Amazon Linux 2023" /etc/os-release 2>/dev/null; then
        log_info "Docker Compose is bundled with Docker on Amazon Linux 2023"
        log_info "Ensure Docker is up to date"
    else
        log_info "Docker Compose plugin missing. Installing..."
        sudo dnf install -y docker-compose-plugin || true
    fi
fi

if ! sudo systemctl is-active --quiet docker; then
    log_info "Starting Docker service..."
    sudo systemctl start docker
fi

# Verify Docker is working
if ! docker ps &> /dev/null; then
    log_warn "Docker may require group membership. Trying with newgrp..."
    newgrp docker << EOF
docker ps
EOF
fi

# ============================================================================
# STEP 3: Build and start OpenClaw (if not already running)
# ============================================================================
log_step "Step 3: Building and starting OpenClaw..."

if docker ps | grep -q openclaw-gateway; then
    log_info "OpenClaw container already running"
else
    log_info "OpenClaw not running. Building and starting..."
    
    # Check if we have docker-setup.sh or deploy-aws.sh
    if [ -f "docker-setup.sh" ]; then
        log_info "Using docker-setup.sh to build and start OpenClaw..."
        chmod +x docker-setup.sh
        ./docker-setup.sh
    elif [ -f "deploy-aws.sh" ]; then
        log_info "Using deploy-aws.sh to build and start OpenClaw..."
        chmod +x deploy-aws.sh
        ./deploy-aws.sh --skip-discord --skip-openai
    else
        log_warn "No build script found. You may need to build OpenClaw manually."
        log_warn "Run: ./docker-setup.sh or ./deploy-aws.sh"
    fi
fi

# ============================================================================
# STEP 4: Run complete deployment script (systemd, CloudWatch, Nginx)
# ============================================================================
log_step "Step 4: Running complete deployment (systemd, CloudWatch, Nginx)..."

if [ -f "complete-deployment.sh" ]; then
    chmod +x complete-deployment.sh
    sudo bash complete-deployment.sh
else
    log_info "Downloading complete-deployment.sh from GitHub..."
    curl -fsSL https://raw.githubusercontent.com/portmi3-ai/openclaw/main/complete-deployment.sh -o /tmp/complete-deployment.sh
    chmod +x /tmp/complete-deployment.sh
    sudo bash /tmp/complete-deployment.sh
fi

# ============================================================================
# STEP 5: Final verification
# ============================================================================
log_step "Step 5: Final verification..."
echo ""

# Check all services
SERVICES_OK=true

if sudo systemctl is-active --quiet openclaw; then
    log_info "✓ systemd service: ACTIVE"
else
    log_error "✗ systemd service: INACTIVE"
    SERVICES_OK=false
fi

if sudo systemctl is-active --quiet amazon-cloudwatch-agent; then
    log_info "✓ CloudWatch agent: RUNNING"
else
    log_warn "✗ CloudWatch agent: NOT RUNNING"
fi

if sudo systemctl is-active --quiet nginx; then
    log_info "✓ Nginx: RUNNING"
else
    log_error "✗ Nginx: NOT RUNNING"
    SERVICES_OK=false
fi

if docker ps | grep -q openclaw-gateway; then
    log_info "✓ OpenClaw container: RUNNING"
    echo ""
    docker ps | grep openclaw
else
    log_error "✗ OpenClaw container: NOT FOUND"
    SERVICES_OK=false
    echo ""
    docker ps -a | head -5
fi

echo ""

# Test endpoints
if command -v curl &> /dev/null; then
    log_info "Testing endpoints..."
    
    if curl -s -f http://localhost:18789/health > /dev/null 2>&1; then
        log_info "✓ Direct gateway (port 18789): RESPONDING"
    else
        log_warn "✗ Direct gateway: NOT RESPONDING"
    fi
    
    if curl -s -f http://localhost/health > /dev/null 2>&1; then
        log_info "✓ Nginx proxy (port 80): RESPONDING"
    else
        log_warn "✗ Nginx proxy: NOT RESPONDING"
    fi
else
    log_warn "curl not available, skipping endpoint tests"
fi

echo ""
log_step "=========================================="
if [ "$SERVICES_OK" = true ]; then
    log_info "DEPLOYMENT SUCCESSFUL!"
else
    log_warn "DEPLOYMENT COMPLETE WITH WARNINGS"
fi
log_step "=========================================="
echo ""

log_info "Access Points:"
echo "  • Direct Gateway: http://${INSTANCE_IP}:18789"
echo "  • Via Nginx:      http://${INSTANCE_IP}"
echo "  • Health Check:   http://${INSTANCE_IP}/health"
echo ""

log_info "CloudWatch Logs:"
echo "  • Log Group: /openclaw/docker"
echo "  • View in: AWS Console → CloudWatch → Log Groups"
echo ""

log_info "Useful Commands:"
echo "  • View logs: sudo journalctl -u openclaw -f"
echo "  • Check status: sudo systemctl status openclaw"
echo "  • Restart: sudo systemctl restart openclaw"
echo "  • Test reboot: sudo reboot"
echo ""

if [ "$SERVICES_OK" = false ]; then
    log_warn "Some services are not running. Check logs above for details."
    exit 1
fi

log_info "All systems operational! 🎉"

# ============================================================================
# Supervisor Loop (Long-Running)
# ============================================================================
# This script runs as a systemd service, so we need to keep it alive
# and monitor the containers. Systemd will restart this script if it exits.
log_info ""
log_info "Entering supervisor mode (monitoring containers)..."
log_info "Press Ctrl+C or stop systemd service to exit"

# Supervisor loop: check containers every 30 seconds
while true; do
    sleep 30
    
    # Check if containers are still running
    if ! docker ps | grep -q openclaw-gateway; then
        log_warn "OpenClaw container stopped! Attempting restart..."
        
        # Try to restart containers
        cd "$OPENCLAW_DIR" || cd /home/ec2-user/openclaw || exit 1
        
        if [ -f "docker-compose.yml" ]; then
            if command -v docker &> /dev/null && docker compose version >/dev/null 2>&1; then
                docker compose -f docker-compose.yml -f docker-compose.aws.yml up -d || true
            elif command -v docker-compose &> /dev/null; then
                docker-compose -f docker-compose.yml -f docker-compose.aws.yml up -d || true
            fi
        fi
        
        # Wait a bit and check again
        sleep 10
        if docker ps | grep -q openclaw-gateway; then
            log_info "Container restarted successfully"
        else
            log_error "Failed to restart container"
        fi
    fi
done
