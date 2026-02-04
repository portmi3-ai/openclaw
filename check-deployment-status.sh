#!/usr/bin/env bash
# Deployment Status Checker
# Run this on EC2 to verify deployment status
# Usage: bash check-deployment-status.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[✓]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
log_error() { echo -e "${RED}[✗]${NC} $*"; }
log_header() { echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

INSTANCE_IP="3.139.76.200"
STATUS_OK=true

echo ""
log_header
echo "  OpenClaw Deployment Status Check"
log_header
echo ""

# Check systemd service
echo "1. systemd Service:"
if sudo systemctl is-active --quiet openclaw 2>/dev/null; then
    log_info "Service is ACTIVE"
    sudo systemctl status openclaw --no-pager -l | head -5
else
    log_error "Service is NOT ACTIVE"
    STATUS_OK=false
fi
echo ""

# Check CloudWatch agent
echo "2. CloudWatch Agent:"
if sudo systemctl is-active --quiet amazon-cloudwatch-agent 2>/dev/null; then
    log_info "Agent is RUNNING"
else
    log_warn "Agent is NOT RUNNING (optional)"
fi
echo ""

# Check Nginx
echo "3. Nginx Reverse Proxy:"
if sudo systemctl is-active --quiet nginx 2>/dev/null; then
    log_info "Nginx is RUNNING"
    if sudo nginx -t 2>&1 | grep -q "successful"; then
        log_info "Configuration is valid"
    else
        log_warn "Configuration may have issues"
    fi
else
    log_error "Nginx is NOT RUNNING"
    STATUS_OK=false
fi
echo ""

# Check Docker
echo "4. Docker Service:"
if sudo systemctl is-active --quiet docker 2>/dev/null; then
    log_info "Docker is RUNNING"
else
    log_error "Docker is NOT RUNNING"
    STATUS_OK=false
fi
echo ""

# Check OpenClaw container
echo "5. OpenClaw Container:"
if docker ps 2>/dev/null | grep -q openclaw-gateway; then
    log_info "Container is RUNNING"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep openclaw
else
    log_error "Container is NOT RUNNING"
    if docker ps -a 2>/dev/null | grep -q openclaw; then
        log_warn "Container exists but is stopped:"
        docker ps -a --format "table {{.Names}}\t{{.Status}}" | grep openclaw
    fi
    STATUS_OK=false
fi
echo ""

# Test endpoints
echo "6. Endpoint Health Checks:"
if command -v curl &> /dev/null; then
    # Direct gateway
    if curl -s -f -m 5 http://localhost:18789/health > /dev/null 2>&1; then
        log_info "Direct gateway (18789): RESPONDING"
    else
        log_error "Direct gateway (18789): NOT RESPONDING"
        STATUS_OK=false
    fi
    
    # Nginx proxy
    if curl -s -f -m 5 http://localhost/health > /dev/null 2>&1; then
        log_info "Nginx proxy (80): RESPONDING"
    else
        log_warn "Nginx proxy (80): NOT RESPONDING"
    fi
    
    # External access test
    if curl -s -f -m 5 http://${INSTANCE_IP}/health > /dev/null 2>&1; then
        log_info "External access (${INSTANCE_IP}): RESPONDING"
    else
        log_warn "External access (${INSTANCE_IP}): NOT RESPONDING (check security group)"
    fi
else
    log_warn "curl not available, skipping endpoint tests"
fi
echo ""

# Check file system
echo "7. File System:"
if [ -d "$HOME/.openclaw" ]; then
    log_info "Config directory exists: $HOME/.openclaw"
else
    log_warn "Config directory not found"
fi

if [ -d "$HOME/.openclaw/workspace" ]; then
    log_info "Workspace directory exists: $HOME/.openclaw/workspace"
else
    log_warn "Workspace directory not found"
fi
echo ""

# Check repository
echo "8. Repository:"
if [ -d "$HOME/openclaw/.git" ]; then
    log_info "Repository exists: $HOME/openclaw"
    cd "$HOME/openclaw" 2>/dev/null && git remote -v | head -2
else
    log_warn "Repository not found at $HOME/openclaw"
fi
echo ""

# Summary
log_header
if [ "$STATUS_OK" = true ]; then
    log_info "DEPLOYMENT STATUS: OPERATIONAL"
    echo ""
    echo "Access Points:"
    echo "  • Direct: http://${INSTANCE_IP}:18789"
    echo "  • Via Nginx: http://${INSTANCE_IP}"
    echo "  • Health: http://${INSTANCE_IP}/health"
else
    log_error "DEPLOYMENT STATUS: ISSUES DETECTED"
    echo ""
    echo "Some services are not running correctly."
    echo "Review the errors above and check logs:"
    echo "  • systemd: sudo journalctl -u openclaw -f"
    echo "  • Docker: docker logs <container-id>"
    echo "  • Nginx: sudo tail -f /var/log/nginx/openclaw-error.log"
fi
log_header
echo ""
