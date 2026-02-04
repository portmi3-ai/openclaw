# OpenClaw AWS Quick Start Guide

This is a condensed guide for deploying OpenClaw to AWS with Discord and OpenAI. For detailed instructions, see [AWS_DEPLOYMENT.md](./AWS_DEPLOYMENT.md).

## Prerequisites Checklist

- [ ] AWS EC2 instance running (Ubuntu 22.04 recommended)
- [ ] Discord bot token from https://discord.com/developers/applications
- [ ] OpenAI API key from https://platform.openai.com/api-keys
- [ ] Forked repository: https://github.com/portmi3-ai/openclaw

## Quick Deployment (5 Steps)

### 1. Connect to Your EC2 Instance

```bash
ssh -i your-key.pem ubuntu@your-ec2-ip
```

### 2. Install Dependencies

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install Git and Node.js
sudo apt update && sudo apt install -y git
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs

# Log out and back in
exit
```

Reconnect via SSH.

### 3. Clone and Configure

```bash
# Clone your fork
git clone https://github.com/portmi3-ai/openclaw.git
cd openclaw

# Create .env file
cp .env.template .env
nano .env
```

**Fill in these required values in `.env`:**
- `OPENCLAW_GATEWAY_TOKEN` - Generate with: `openssl rand -hex 32`
- `DISCORD_BOT_TOKEN` - From Discord Developer Portal
- `OPENAI_API_KEY` - From OpenAI Platform
- `GITHUB_TOKEN` - Fine-grained PAT for `portmi3-ai` (repos + Projects)
- `SECOND_BRAIN_REPO_URL` - URL of your private second-brain repo
- `SASHA_EMAIL` - Sasha's real email address

### 4. Run Deployment Script

```bash
# Make script executable
chmod +x deploy-aws.sh

# Run deployment
./deploy-aws.sh
```

The script will:
- ✅ Check dependencies
- ✅ Validate configuration
- ✅ Build Docker image
- ✅ Run onboarding
- ✅ Add Discord channel
- ✅ Configure OpenAI
- ✅ Start gateway

### 5. Configure AWS Security Group

1. Go to EC2 → Security Groups
2. Add inbound rule:
   - **Type**: Custom TCP
   - **Port**: 18789
   - **Source**: Your IP (or 0.0.0.0/0 for testing)
   - **Description**: OpenClaw Gateway

## Verify Deployment

```bash
# Check gateway status
docker compose ps

# View logs
docker compose logs -f openclaw-gateway

# Test health
curl http://localhost:18789/health
```

## Test Discord Bot

1. Go to your Discord server
2. Send a message mentioning your bot or in a DM
3. Bot should respond!

## Common Commands

```bash
# View logs
docker compose logs -f openclaw-gateway

# Restart gateway
docker compose restart openclaw-gateway

# Stop gateway
docker compose down

# Start gateway
docker compose up -d

# Check channels
docker compose run --rm openclaw-cli channels list

# Check models
docker compose run --rm openclaw-cli models list
```

## Troubleshooting

### Gateway won't start
```bash
docker compose logs openclaw-gateway
```

### Discord bot not responding
```bash
# Verify Discord token
docker compose run --rm openclaw-cli channels list

# Re-add Discord channel
docker compose run --rm openclaw-cli channels add --channel discord --token YOUR_TOKEN
```

### OpenAI not working
```bash
# Verify OpenAI key
docker compose run --rm openclaw-cli models list

# Re-add OpenAI model
docker compose run --rm openclaw-cli models add --provider openai --api-key YOUR_KEY
```

## Next Steps

- Set up HTTPS with nginx reverse proxy
- Configure automatic backups
- Set up CloudWatch monitoring
- Enable auto-restart on system reboot

## Need Help?

- Full guide: [AWS_DEPLOYMENT.md](./AWS_DEPLOYMENT.md)
- OpenClaw docs: https://docs.openclaw.ai
- Discord community: https://discord.gg/clawd
