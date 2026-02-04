# OpenClaw AWS Deployment - Quick Start

## 🚀 One-Command Deployment

SSH into your EC2 instance and run:

```bash
curl -fsSL https://raw.githubusercontent.com/portmi3-ai/openclaw/main/DEPLOY_NOW.sh | bash
```

## ✅ What This Does

1. Pulls latest code from GitHub
2. Installs Docker (if needed)
3. Deploys systemd watchdog (auto-restart)
4. Configures CloudWatch logging
5. Sets up Nginx reverse proxy
6. Verifies all services

## 📊 Check Status

```bash
curl -fsSL https://raw.githubusercontent.com/portmi3-ai/openclaw/main/check-deployment-status.sh | bash
```

## 🌐 Access Points

- **Direct**: `http://3.139.76.200:18789`
- **Via Nginx**: `http://3.139.76.200`
- **Health**: `http://3.139.76.200/health`

## 📚 Full Documentation

- `EXECUTION_CHECKLIST.md` - Step-by-step checklist
- `DEPLOYMENT_SUMMARY.md` - Complete summary
- `FINAL_DEPLOYMENT_INSTRUCTIONS.md` - Detailed guide
- `AWS_DEPLOYMENT.md` - Comprehensive AWS guide

## 🔧 Quick Commands

```bash
# View logs
sudo journalctl -u openclaw -f

# Restart service
sudo systemctl restart openclaw

# Check containers
docker ps

# Test health
curl http://localhost/health
```

---

**Ready to deploy?** Run the one-command script above!
