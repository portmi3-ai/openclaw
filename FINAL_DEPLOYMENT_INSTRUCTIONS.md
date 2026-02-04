# Final Deployment Instructions

## 🚀 One-Command Deployment

SSH into your EC2 instance and run:

```bash
curl -fsSL https://raw.githubusercontent.com/portmi3-ai/openclaw/main/DEPLOY_NOW.sh | bash
```

## 📋 What This Does

1. **Repository Setup**
   - Clones/pulls your fork: `https://github.com/portmi3-ai/openclaw`
   - Ensures latest code is present

2. **Docker Installation** (if needed)
   - Installs Docker using official script
   - Enables and starts Docker service

3. **Complete Deployment**
   - Installs systemd watchdog service (`/etc/systemd/system/openclaw.service`)
   - Configures CloudWatch logging (`/openclaw/docker` log group)
   - Installs and configures Nginx reverse proxy
   - Installs Certbot for HTTPS (ready for DNS setup)
   - Verifies all services are running

4. **Verification**
   - Checks all services status
   - Tests health endpoints
   - Reports final status

## ✅ Expected Results

After execution, you should see:

```
✓ systemd service: ACTIVE
✓ CloudWatch agent: RUNNING
✓ Nginx: RUNNING
✓ OpenClaw container: RUNNING
✓ Direct gateway (port 18789): RESPONDING
✓ Nginx proxy (port 80): RESPONDING
```

## 🌐 Access Points

- **Direct Gateway**: `http://3.139.76.200:18789`
- **Via Nginx**: `http://3.139.76.200`
- **Health Check**: `http://3.139.76.200/health`

## 📊 CloudWatch Logs

View logs in AWS Console:
- **Service**: CloudWatch
- **Log Groups**: `/openclaw/docker`
- **Stream**: Instance ID

## 🔧 Useful Commands

```bash
# View systemd logs
sudo journalctl -u openclaw -f

# Check service status
sudo systemctl status openclaw

# Restart service
sudo systemctl restart openclaw

# View Docker containers
docker ps

# View Nginx logs
sudo tail -f /var/log/nginx/openclaw-error.log

# Test reboot recovery
sudo reboot
```

## 🔒 Security Group Configuration

Ensure these ports are open in AWS Security Group:
- **Port 22** (SSH) - From your IP
- **Port 80** (HTTP) - From 0.0.0.0/0 or specific IPs
- **Port 443** (HTTPS) - If using Let's Encrypt
- **Port 18789** - Can be restricted to localhost (Nginx handles external)

## 🔐 HTTPS Setup (Optional)

If you have a domain name pointing to `3.139.76.200`:

```bash
sudo certbot --nginx -d your-domain.com
```

Or set up an ALB with TLS termination (recommended for production).

## 🐛 Troubleshooting

### Service not starting
```bash
sudo journalctl -u openclaw -n 50
```

### CloudWatch not sending logs
```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -a status
```

### Nginx not proxying
```bash
sudo nginx -t
sudo tail -f /var/log/nginx/openclaw-error.log
```

### Container not running
```bash
docker ps -a
docker logs <container-id>
```

## 📝 Next Steps (After Deployment)

1. **Configure Discord** (when Sasha is ready)
   - Add `DISCORD_BOT_TOKEN` to `.env`
   - Run: `docker compose run --rm openclaw-cli channels add --channel discord --token <token>`

2. **Configure OpenAI** (when Sasha is ready)
   - Add `OPENAI_API_KEY` to `.env`
   - Run: `docker compose run --rm openclaw-cli models add --provider openai --api-key <key>`

3. **Set up GitHub Projects Kanban**
   - Create project board in your GitHub repo
   - Configure GitHub token in `.env`

4. **Test End-to-End**
   - Send message via Discord
   - Verify OpenAI responses
   - Check kanban updates
   - Verify second-brain updates

## ✅ Deployment Complete When

- ✅ Containers start automatically on reboot
- ✅ Gateway is reachable on health endpoint
- ✅ Logs stream to CloudWatch
- ✅ Nginx proxies requests correctly
- ✅ No manual steps required to recover from crashes

---

**Ready to deploy?** Run the one-command script above on your EC2 instance!
