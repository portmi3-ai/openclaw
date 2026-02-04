#!/usr/bin/env bash
# Quick fix script for merge conflict on EC2
# Run this on EC2 to resolve the conflict and continue deployment

set -euo pipefail

cd ~/openclaw

echo "Stashing local changes..."
git stash

echo "Pulling latest changes..."
git pull origin main

echo "Removing bad systemd service file..."
sudo rm -f /etc/systemd/system/openclaw.service

echo "Re-running deployment..."
sudo bash complete-deployment.sh

echo "Done! Check status with: sudo systemctl status openclaw"
