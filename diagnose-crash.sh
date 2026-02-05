#!/usr/bin/env bash
# Diagnostic script to identify why EC2 instance is crashing
# Run this on the EC2 instance when it's running

set -euo pipefail

echo "=========================================="
echo "EC2 Instance Crash Diagnostics"
echo "=========================================="
echo ""

# Check memory
echo "=== MEMORY USAGE ==="
free -h
echo ""
echo "Memory details:"
cat /proc/meminfo | grep -E "MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree"
echo ""

# Check disk space
echo "=== DISK SPACE ==="
df -h
echo ""

# Check if swap exists
echo "=== SWAP STATUS ==="
swapon --show
if [ -z "$(swapon --show)" ]; then
    echo "WARNING: No swap configured! This can cause OOM kills."
fi
echo ""

# Check system logs for OOM kills
echo "=== OOM KILLS (Out of Memory) ==="
if dmesg | grep -i "out of memory\|oom\|killed process" | tail -20; then
    echo "Found OOM kills above"
else
    echo "No recent OOM kills found in dmesg"
fi
echo ""

# Check systemd service status
echo "=== SYSTEMD SERVICE STATUS ==="
systemctl status openclaw --no-pager -l || echo "Service not running"
echo ""

# Check Docker status
echo "=== DOCKER STATUS ==="
systemctl status docker --no-pager -l || echo "Docker not running"
echo ""

# Check Docker container status
echo "=== DOCKER CONTAINERS ==="
docker ps -a || echo "Docker not accessible"
echo ""

# Check recent system logs
echo "=== RECENT SYSTEM LOGS ==="
journalctl -n 50 --no-pager | tail -30
echo ""

# Check for kernel panics
echo "=== KERNEL PANICS ==="
dmesg | grep -i "panic\|bug\|error" | tail -10 || echo "No kernel panics found"
echo ""

# Check CPU load
echo "=== CPU LOAD ==="
uptime
echo ""

# Check what's using memory
echo "=== TOP MEMORY CONSUMERS ==="
ps aux --sort=-%mem | head -10
echo ""

# Check Docker build processes
echo "=== DOCKER BUILD PROCESSES ==="
ps aux | grep -E "docker|pnpm|node" | grep -v grep || echo "No Docker/build processes found"
echo ""

echo "=========================================="
echo "Diagnostics complete"
echo "=========================================="
