# Execute Complete Deployment on EC2

This guide will complete the OpenClaw deployment with systemd watchdog, CloudWatch logging, and Nginx reverse proxy.

## Prerequisites

- SSH access to EC2 instance (i-0bb62505a8b5e32fb)
- OpenClaw already running via Docker Compose
- Sudo/root access on EC2

## Execution Steps

### 1. Transfer Script to EC2

From your local machine (PowerShell):

```powershell
# Navigate to openclaw directory
cd C:\Users\it2it\openclaw

# Copy script to EC2 (adjust key path and IP)
scp -i C:\path\to\sashaserverkey.pem complete-deployment.sh ec2-user@3.139.76.200:~/
```

### 2. SSH into EC2

```powershell
ssh -i C:\path\to\sashaserverkey.pem ec2-user@3.139.76.200
```

### 3. Run Deployment Script

On EC2 terminal:

```bash
# Make script executable
chmod +x ~/complete-deployment.sh

# Run with sudo (required for systemd, CloudWatch, Nginx)
sudo bash ~/complete-deployment.sh
```

The script will:
- Install and configure systemd watchdog service
- Install and configure CloudWatch logging
- Install and configure Nginx reverse proxy
- Install Certbot for HTTPS (ready for DNS setup)
- Verify all services are running

### 4. Verify Deployment

After script completes, verify:

```bash
# Check systemd service
sudo systemctl status openclaw

# Check CloudWatch agent
sudo systemctl status amazon-cloudwatch-agent

# Check Nginx
sudo systemctl status nginx

# Check containers
docker ps

# Test health endpoint
curl http://localhost/health
```

### 5. Test Auto-Restart (Optional)

```bash
# Reboot instance
sudo reboot
```

After reboot, SSH back in and verify:

```bash
docker ps  # Should show openclaw-gateway running
sudo systemctl status openclaw  # Should show active
```

### 6. Access Points

- **Direct Gateway**: `http://3.139.76.200:18789`
- **Via Nginx**: `http://3.139.76.200`
- **Health Check**: `http://3.139.76.200/health`

### 7. CloudWatch Logs

View logs in AWS Console:
- Go to CloudWatch → Log Groups
- Find: `/openclaw/docker`
- Stream name: Instance ID

### 8. HTTPS Setup (When Ready)

If you have a domain name pointing to the instance:

```bash
sudo certbot --nginx -d your-domain.com
```

Or set up an ALB with TLS termination (recommended for production).

## Troubleshooting

### systemd service fails
```bash
sudo journalctl -u openclaw -f
```

### CloudWatch agent not sending logs
```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -a status
```

### Nginx not proxying
```bash
sudo nginx -t  # Test config
sudo tail -f /var/log/nginx/openclaw-error.log
```

## Security Group Updates Needed

Ensure these ports are open in AWS Security Group:
- Port 22 (SSH) - from your IP
- Port 80 (HTTP) - from 0.0.0.0/0 or specific IPs
- Port 443 (HTTPS) - if using Let's Encrypt
- Port 18789 - can be restricted to localhost only (Nginx handles external)
