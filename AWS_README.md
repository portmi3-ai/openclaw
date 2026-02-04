# OpenClaw AWS Deployment Files

This directory contains all the files needed to deploy OpenClaw to AWS EC2 with Discord and OpenAI integration.

## Files Overview

### Documentation
- **AWS_DEPLOYMENT.md** - Comprehensive step-by-step deployment guide
- **AWS_QUICKSTART.md** - Condensed quick start guide (5 steps)
- **AWS_README.md** - This file (overview of all files)

### Configuration Files
- **.env.template** - Environment variable template (copy to `.env` and fill in)
- **docker-compose.aws.yml** - AWS-specific Docker Compose overrides

### Scripts
- **deploy-aws.sh** - Automated deployment script

## Quick Start

1. **Read the Quick Start Guide:**
   ```bash
   cat AWS_QUICKSTART.md
   ```

2. **Set up your environment:**
   ```bash
   cp .env.template .env
   nano .env  # Fill in your Discord token and OpenAI API key
   ```

3. **Run the deployment:**
   ```bash
   chmod +x deploy-aws.sh
   ./deploy-aws.sh
   ```

## File Descriptions

### AWS_DEPLOYMENT.md
Complete deployment guide with:
- Prerequisites and setup
- Step-by-step EC2 configuration
- Discord bot setup instructions
- OpenAI API configuration
- Security best practices
- Troubleshooting guide
- AWS Secrets Manager integration

### AWS_QUICKSTART.md
Condensed guide for experienced users:
- 5-step deployment process
- Essential commands
- Quick troubleshooting tips

### .env.template
Template for environment variables:
- Gateway configuration
- Discord bot token
- OpenAI API key
- GitHub username + token (for kanban + repos)
- Second-brain repo URL + local path
- Optional Claude configuration
- Docker settings

**Important:** Copy this to `.env` and fill in your actual values. Never commit `.env` to git!

### docker-compose.aws.yml
AWS-specific Docker Compose overrides:
- External network binding (0.0.0.0)
- Health checks
- Resource limits
- Logging configuration
- Environment variable passthrough

### deploy-aws.sh
Automated deployment script that:
- Checks dependencies
- Validates configuration
- Builds Docker image
- Runs onboarding
- Configures Discord channel
- Sets up OpenAI model
- Starts the gateway
- Verifies deployment

**Usage:**
```bash
./deploy-aws.sh                    # Full deployment
./deploy-aws.sh --skip-build       # Skip Docker build
./deploy-aws.sh --generate-token   # Just generate token
./deploy-aws.sh --help             # Show help
```

## Deployment Workflow

```
1. Fork repository on GitHub
   ↓
2. Launch AWS EC2 instance
   ↓
3. Install dependencies (Docker, Docker Compose, Git, Node.js)
   ↓
4. Clone your fork
   ↓
5. Copy .env.template to .env and configure
   ↓
6. Run deploy-aws.sh
   ↓
7. Configure AWS Security Group
   ↓
8. Test deployment
```

## Required Credentials

Before deploying, you need:

1. **Discord Bot Token**
   - Create at: https://discord.com/developers/applications
   - Enable MESSAGE CONTENT INTENT
   - Invite bot to your server

2. **OpenAI API Key**
   - Get from: https://platform.openai.com/api-keys
   - Ensure you have credits/quota

3. **GitHub Personal Access Token**
   - Create at: https://github.com/settings/tokens?type=beta
   - Allow repo + Projects access for `portmi3-ai`
   - Keep it private and store it only in `.env`

4. **AWS EC2 Instance**
   - Ubuntu 22.04 LTS recommended
   - t3.medium or larger (2 vCPU, 4GB RAM minimum)
   - Security group allowing port 18789

## Security Notes

- ⚠️ Never commit `.env` file to version control
- ⚠️ Use AWS Secrets Manager for production
- ⚠️ Restrict Security Group to trusted IPs
- ⚠️ Use HTTPS in production (set up nginx reverse proxy)
- ⚠️ Rotate tokens regularly

## Support Resources

- **Full Documentation**: https://docs.openclaw.ai
- **Discord Community**: https://discord.gg/clawd
- **GitHub Issues**: https://github.com/openclaw/openclaw/issues
- **Detailed Guide**: See AWS_DEPLOYMENT.md

## Troubleshooting

If you encounter issues:

1. Check gateway logs:
   ```bash
   docker compose logs -f openclaw-gateway
   ```

2. Verify configuration:
   ```bash
   docker compose run --rm openclaw-cli channels list
   docker compose run --rm openclaw-cli models list
   ```

3. Review the troubleshooting section in AWS_DEPLOYMENT.md

4. Check OpenClaw documentation: https://docs.openclaw.ai

## Next Steps After Deployment

- [ ] Set up nginx reverse proxy with SSL
- [ ] Configure automatic backups
- [ ] Set up CloudWatch monitoring
- [ ] Enable systemd service for auto-restart
- [ ] Configure additional channels (Telegram, WhatsApp, etc.)
- [ ] Set up skills and automation

## Contributing

If you improve these deployment files, consider:
- Opening a PR to the main OpenClaw repository
- Sharing improvements in the Discord community
- Documenting your changes

---

**Happy Deploying! 🦞**
