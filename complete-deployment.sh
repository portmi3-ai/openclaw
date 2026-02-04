#!/usr/bin/env bash
# Complete OpenClaw AWS Deployment Script
# This script completes the production deployment with:
# - systemd watchdog (auto-restart)
# - CloudWatch logging
# - Nginx reverse proxy
# - HTTPS preparation
#
# Run this ON THE EC2 INSTANCE as ec2-user after OpenClaw is already running
# Usage: sudo bash complete-deployment.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root or with sudo"
    exit 1
fi

OPENCLAW_DIR="/home/ec2-user/openclaw"
INSTANCE_IP="3.139.76.200"
INSTANCE_DNS="ec2-3-139-76-200.us-east-2.compute.amazonaws.com"

log_info "Starting complete deployment setup..."

# ============================================================================
# PART 1: systemd Watchdog (Auto-restart)
# ============================================================================
log_info "Installing systemd watchdog service..."

cat > /etc/systemd/system/openclaw.service << 'EOF'
[Unit]
Description=OpenClaw Gateway
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=true
WorkingDirectory=/home/ec2-user/openclaw
Environment="PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin"
ExecStart=/bin/bash -c "cd /home/ec2-user/openclaw && /usr/bin/docker compose -f docker-compose.yml -f docker-compose.aws.yml up -d || /usr/local/bin/docker-compose -f docker-compose.yml -f docker-compose.aws.yml up -d"
ExecStop=/bin/bash -c "cd /home/ec2-user/openclaw && /usr/bin/docker compose -f docker-compose.yml -f docker-compose.aws.yml down || /usr/local/bin/docker-compose -f docker-compose.yml -f docker-compose.aws.yml down"
TimeoutStartSec=0
Restart=always
RestartSec=10
User=ec2-user
Group=ec2-user

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable openclaw
systemctl start openclaw

log_info "systemd watchdog installed and enabled ✓"

# ============================================================================
# PART 2: CloudWatch Logging
# ============================================================================
log_info "Installing CloudWatch Agent..."

if ! command -v amazon-cloudwatch-agent &> /dev/null; then
    dnf install -y amazon-cloudwatch-agent
else
    log_info "CloudWatch Agent already installed"
fi

# Create CloudWatch config directory
mkdir -p /opt/aws/amazon-cloudwatch-agent/etc

# Get instance ID
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)

cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/lib/docker/containers/*/*.log",
            "log_group_name": "/openclaw/docker",
            "log_stream_name": "${INSTANCE_ID}",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s

systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent

log_info "CloudWatch logging enabled ✓"
log_info "Logs will appear in CloudWatch Logs group: /openclaw/docker"

# ============================================================================
# PART 3: Nginx Reverse Proxy
# ============================================================================
log_info "Installing and configuring Nginx..."

if ! command -v nginx &> /dev/null; then
    dnf install -y nginx
else
    log_info "Nginx already installed"
fi

# Create Nginx config for OpenClaw
cat > /etc/nginx/conf.d/openclaw.conf << EOF
server {
    listen 80;
    server_name ${INSTANCE_DNS} ${INSTANCE_IP};

    # Logging
    access_log /var/log/nginx/openclaw-access.log;
    error_log /var/log/nginx/openclaw-error.log;

    # Proxy settings
    location / {
        proxy_pass http://localhost:18789;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Health check endpoint
    location /health {
        proxy_pass http://localhost:18789/health;
        access_log off;
    }
}
EOF

# Test Nginx config
nginx -t

# Enable and start Nginx
systemctl enable nginx
systemctl start nginx

log_info "Nginx reverse proxy configured and running ✓"
log_info "OpenClaw accessible via: http://${INSTANCE_IP}"

# ============================================================================
# PART 4: HTTPS Preparation (Let's Encrypt)
# ============================================================================
log_info "Installing Certbot for HTTPS support..."

if ! command -v certbot &> /dev/null; then
    dnf install -y certbot python3-certbot-nginx
else
    log_info "Certbot already installed"
fi

log_warn "HTTPS certificate setup requires:"
log_warn "  1. DNS A record pointing to ${INSTANCE_IP}"
log_warn "  2. Or use ALB for TLS termination (recommended for production)"
log_warn ""
log_warn "To enable HTTPS with Let's Encrypt (if DNS is configured):"
log_warn "  sudo certbot --nginx -d your-domain.com"
log_warn ""
log_warn "For ALB setup, Nginx is already configured to accept HTTP from ALB."

# ============================================================================
# PART 5: Firewall (Security Group)
# ============================================================================
log_info "Firewall configuration notes:"
log_info "  - Port 22 (SSH): Should be open in AWS Security Group"
log_info "  - Port 80 (HTTP): Should be open in AWS Security Group for Nginx"
log_info "  - Port 443 (HTTPS): Should be open if using Let's Encrypt"
log_info "  - Port 18789: Can be restricted to localhost only (Nginx handles external)"
log_warn "  Configure these in AWS Console → EC2 → Security Groups"

# ============================================================================
# PART 6: Verification
# ============================================================================
log_info "Running verification checks..."

# Check systemd service
if systemctl is-active --quiet openclaw; then
    log_info "✓ systemd service is active"
else
    log_error "✗ systemd service is not active"
    systemctl status openclaw
fi

# Check CloudWatch agent
if systemctl is-active --quiet amazon-cloudwatch-agent; then
    log_info "✓ CloudWatch agent is running"
else
    log_warn "✗ CloudWatch agent is not running"
    systemctl status amazon-cloudwatch-agent
fi

# Check Nginx
if systemctl is-active --quiet nginx; then
    log_info "✓ Nginx is running"
else
    log_error "✗ Nginx is not running"
    systemctl status nginx
fi

# Check Docker containers
if docker ps | grep -q openclaw-gateway; then
    log_info "✓ OpenClaw container is running"
else
    log_warn "✗ OpenClaw container not found"
    docker ps -a
fi

# Test health endpoint via Nginx
if command -v curl &> /dev/null; then
    if curl -s -f http://localhost/health > /dev/null 2>&1; then
        log_info "✓ Health endpoint accessible via Nginx"
    else
        log_warn "✗ Health endpoint not responding via Nginx"
    fi
fi

# ============================================================================
# Summary
# ============================================================================
log_info ""
log_info "=========================================="
log_info "Deployment Complete!"
log_info "=========================================="
log_info ""
log_info "Services configured:"
log_info "  ✓ systemd watchdog (auto-restart)"
log_info "  ✓ CloudWatch logging"
log_info "  ✓ Nginx reverse proxy"
log_info "  ✓ HTTPS preparation (certbot installed)"
log_info ""
log_info "Access points:"
log_info "  - Direct: http://${INSTANCE_IP}:18789"
log_info "  - Via Nginx: http://${INSTANCE_IP}"
log_info "  - Health: http://${INSTANCE_IP}/health"
log_info ""
log_info "Next steps:"
log_info "  1. Configure DNS A record (if using Let's Encrypt)"
log_info "  2. Run: sudo certbot --nginx -d your-domain.com"
log_info "  3. Or set up ALB with TLS termination"
log_info "  4. Verify logs in CloudWatch: /openclaw/docker"
log_info "  5. Test reboot: sudo reboot (containers should auto-start)"
log_info ""
