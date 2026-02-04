#!/usr/bin/env bash
# Complete Deployment Execution Script for EC2
# This script downloads and runs the complete deployment setup
# Run this ON THE EC2 INSTANCE

set -euo pipefail

echo "=========================================="
echo "OpenClaw Complete Deployment Setup"
echo "=========================================="
echo ""

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    echo "Error: docker-compose.yml not found. Are you in ~/openclaw?"
    exit 1
fi

# Download the complete deployment script from GitHub
echo "[1/4] Downloading complete-deployment.sh..."
curl -fsSL https://raw.githubusercontent.com/portmi3-ai/openclaw/main/complete-deployment.sh -o /tmp/complete-deployment.sh
chmod +x /tmp/complete-deployment.sh

echo "[2/4] Running complete deployment script (requires sudo)..."
sudo bash /tmp/complete-deployment.sh

echo ""
echo "[3/4] Verifying deployment..."
echo ""

# Check services
echo "Checking systemd service..."
if sudo systemctl is-active --quiet openclaw; then
    echo "  ✓ systemd service is active"
else
    echo "  ✗ systemd service is not active"
fi

echo ""
echo "Checking CloudWatch agent..."
if sudo systemctl is-active --quiet amazon-cloudwatch-agent; then
    echo "  ✓ CloudWatch agent is running"
else
    echo "  ✗ CloudWatch agent is not running"
fi

echo ""
echo "Checking Nginx..."
if sudo systemctl is-active --quiet nginx; then
    echo "  ✓ Nginx is running"
else
    echo "  ✗ Nginx is not running"
fi

echo ""
echo "Checking Docker containers..."
if docker ps | grep -q openclaw-gateway; then
    echo "  ✓ OpenClaw container is running"
    docker ps | grep openclaw
else
    echo "  ✗ OpenClaw container not found"
fi

echo ""
echo "[4/4] Testing endpoints..."
if command -v curl &> /dev/null; then
    echo "  Testing direct gateway:"
    if curl -s -f http://localhost:18789/health > /dev/null 2>&1; then
        echo "    ✓ Direct gateway health check passed"
    else
        echo "    ✗ Direct gateway health check failed"
    fi
    
    echo "  Testing via Nginx:"
    if curl -s -f http://localhost/health > /dev/null 2>&1; then
        echo "    ✓ Nginx proxy health check passed"
    else
        echo "    ✗ Nginx proxy health check failed"
    fi
else
    echo "  curl not available, skipping endpoint tests"
fi

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "Access points:"
echo "  - Direct: http://3.139.76.200:18789"
echo "  - Via Nginx: http://3.139.76.200"
echo "  - Health: http://3.139.76.200/health"
echo ""
echo "CloudWatch logs: /openclaw/docker"
echo ""
echo "To test auto-restart: sudo reboot"
echo ""
