# OpenClaw AWS Deployment - Execution Checklist

## ✅ Pre-Deployment Status

- [x] All deployment scripts created
- [x] All documentation written
- [x] All files committed to Git
- [x] All files pushed to GitHub (`portmi3-ai/openclaw`)
- [x] EC2 instance running (`i-0bb62505a8b5e32fb`)
- [x] SSH access configured
- [x] Repository forked and accessible

## 🚀 Execution Steps

### Step 1: Connect to EC2

```bash
ssh -i /path/to/sashaserverkey.pem ec2-user@3.139.76.200
```

### Step 2: Run Deployment

**One-command deployment:**

```bash
curl -fsSL https://raw.githubusercontent.com/portmi3-ai/openclaw/main/DEPLOY_NOW.sh | bash
```

**Expected output:**
- Repository cloned/pulled
- Docker installed (if needed)
- systemd service configured
- CloudWatch agent installed
- Nginx configured
- All services verified

**Time estimate:** 5-10 minutes

### Step 3: Verify Deployment

**Check status:**

```bash
curl -fsSL https://raw.githubusercontent.com/portmi3-ai/openclaw/main/check-deployment-status.sh | bash
```

**Or manually verify:**

```bash
# Check systemd service
sudo systemctl status openclaw

# Check containers
docker ps

# Test health endpoint
curl http://localhost/health
curl http://3.139.76.200/health
```

### Step 4: Test Auto-Restart (Optional)

```bash
# Reboot instance
sudo reboot

# Wait 2-3 minutes, then SSH back in and verify:
docker ps  # Should show openclaw-gateway running
sudo systemctl status openclaw  # Should show active
```

## ✅ Post-Deployment Checklist

- [ ] systemd service is active
- [ ] CloudWatch agent is running
- [ ] Nginx is running
- [ ] OpenClaw container is running
- [ ] Health endpoint responds: `http://3.139.76.200/health`
- [ ] Nginx proxy works: `http://3.139.76.200`
- [ ] Logs visible in CloudWatch: `/openclaw/docker`
- [ ] Auto-restart works (tested with reboot)

## 📋 What Gets Installed

1. **systemd Service** (`/etc/systemd/system/openclaw.service`)
   - Auto-starts on boot
   - Auto-restarts on crash
   - Runs as `ec2-user`

2. **CloudWatch Agent** (`/opt/aws/amazon-cloudwatch-agent/`)
   - Logs Docker containers to CloudWatch
   - Log group: `/openclaw/docker`

3. **Nginx** (`/etc/nginx/conf.d/openclaw.conf`)
   - Reverse proxy on port 80
   - Proxies to `localhost:18789`
   - Health check at `/health`

4. **Certbot** (for HTTPS)
   - Installed and ready
   - Can be configured with: `sudo certbot --nginx -d your-domain.com`

## 🔧 Troubleshooting

### If deployment fails:

1. **Check logs:**
   ```bash
   sudo journalctl -u openclaw -n 50
   docker logs $(docker ps -q --filter "name=openclaw")
   ```

2. **Check Docker:**
   ```bash
   sudo systemctl status docker
   docker ps -a
   ```

3. **Check Nginx:**
   ```bash
   sudo nginx -t
   sudo tail -f /var/log/nginx/openclaw-error.log
   ```

4. **Re-run deployment:**
   ```bash
   cd ~/openclaw
   sudo bash complete-deployment.sh
   ```

### Common Issues:

- **Docker not running**: `sudo systemctl start docker`
- **Permission denied**: Ensure you're using `sudo` for system commands
- **Port already in use**: Check what's using port 80/18789
- **CloudWatch agent fails**: Check IAM role permissions

## 📊 Monitoring

### View Logs:

**CloudWatch (AWS Console):**
- Service: CloudWatch → Log Groups
- Log Group: `/openclaw/docker`

**Local (SSH):**
```bash
# systemd logs
sudo journalctl -u openclaw -f

# Docker logs
docker logs -f $(docker ps -q --filter "name=openclaw")

# Nginx logs
sudo tail -f /var/log/nginx/openclaw-access.log
sudo tail -f /var/log/nginx/openclaw-error.log
```

## 🎯 Success Criteria

Deployment is successful when:

- ✅ All services are running
- ✅ Health endpoint responds
- ✅ Nginx proxies correctly
- ✅ Logs stream to CloudWatch
- ✅ Services survive reboot
- ✅ No manual intervention needed

## 📝 Next Steps (After Base Deployment)

1. **Configure Discord** (when Sasha is ready)
2. **Configure OpenAI** (when Sasha is ready)
3. **Set up GitHub Projects Kanban**
4. **Enable HTTPS** (optional)
5. **Test end-to-end workflows**

---

**Ready to deploy?** Run the one-command script on your EC2 instance!
