# OpenClaw AWS Deployment Guide

This guide will help you deploy OpenClaw to AWS EC2 with Discord and OpenAI API integration.

## Prerequisites

1. **AWS Account** with EC2 access
2. **Discord Bot Token** - Create a bot at https://discord.com/developers/applications
3. **OpenAI API Key** - Get from https://platform.openai.com/api-keys
4. **GitHub Fork** - Fork https://github.com/openclaw/openclaw to your account (portmi3-ai)

## Step 1: Create AWS EC2 Instance

### Launch EC2 Instance

1. Go to AWS Console → EC2 → Launch Instance
2. **Name**: `openclaw-server`
3. **AMI**: Ubuntu 22.04 LTS (or Amazon Linux 2023)
4. **Instance Type**: `t3.medium` or larger (2 vCPU, 4GB RAM minimum)
5. **Key Pair**: Create or select an existing key pair
6. **Network Settings**: 
   - Allow SSH (port 22) from your IP
   - Allow HTTP (port 80) and HTTPS (port 443) if using web interface
   - Allow custom TCP port 18789 (OpenClaw Gateway)
7. **Storage**: 20GB minimum
8. Launch instance

### Connect to Your Instance

```bash
ssh -i your-key.pem ubuntu@your-ec2-ip
```

## Step 2: Install Dependencies on EC2

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install Git
sudo apt install -y git

# Install Node.js 22 (required for OpenClaw)
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs

# Log out and back in for Docker group to take effect
exit
```

Reconnect via SSH after logging out.

## Step 3: Clone Your Fork

```bash
# Clone your forked repository
git clone https://github.com/portmi3-ai/openclaw.git
cd openclaw
```

## Step 4: Configure Environment Variables

Create a `.env` file with your credentials:

```bash
# Copy the example and edit it
cp .env.example .env
nano .env
```

Add the following to your `.env` file (see `.env.template` for full template):

```bash
# Gateway Configuration
OPENCLAW_GATEWAY_TOKEN=your-secure-random-token-here
OPENCLAW_GATEWAY_PORT=18789
OPENCLAW_BRIDGE_PORT=18790
OPENCLAW_GATEWAY_BIND=0.0.0.0

# Discord Bot Configuration
DISCORD_BOT_TOKEN=your-discord-bot-token-here

# OpenAI API Configuration
OPENAI_API_KEY=your-openai-api-key-here

# Optional: Claude Configuration (if using Claude)
CLAUDE_AI_SESSION_KEY=
CLAUDE_WEB_SESSION_KEY=
CLAUDE_WEB_COOKIE=

# Docker Configuration
OPENCLAW_IMAGE=openclaw:aws
OPENCLAW_CONFIG_DIR=/home/ubuntu/.openclaw
OPENCLAW_WORKSPACE_DIR=/home/ubuntu/.openclaw/workspace
```

**Generate a secure gateway token:**
```bash
openssl rand -hex 32
```

## Step 5: Get Discord Bot Token

1. Go to https://discord.com/developers/applications
2. Click "New Application" → Name it (e.g., "OpenClaw")
3. Go to "Bot" section → Click "Add Bot"
4. Under "Token", click "Reset Token" or "Copy" to get your bot token
5. Enable these Privileged Gateway Intents:
   - ✅ MESSAGE CONTENT INTENT (required)
   - ✅ SERVER MEMBERS INTENT (optional, for member info)
   - ✅ PRESENCE INTENT (optional)
6. Save changes
7. Copy the token to your `.env` file as `DISCORD_BOT_TOKEN`

### Invite Bot to Your Discord Server

1. Go to "OAuth2" → "URL Generator"
2. Select scopes:
   - `bot`
   - `applications.commands` (optional, for slash commands)
3. Select bot permissions:
   - Send Messages
   - Read Message History
   - Use External Emojis
   - Attach Files
   - Embed Links
4. Copy the generated URL and open it in your browser
5. Select your Discord server and authorize

## Step 6: Get OpenAI API Key

1. Go to https://platform.openai.com/api-keys
2. Sign in or create an account
3. Click "Create new secret key"
4. Name it (e.g., "OpenClaw AWS")
5. Copy the key immediately (you won't see it again)
6. Add it to your `.env` file as `OPENAI_API_KEY`

## Step 7: Build and Deploy

### Build Docker Image

```bash
# Build the OpenClaw Docker image
docker build -t openclaw:aws -f Dockerfile .
```

### Run Onboarding

```bash
# Run the onboarding wizard
docker compose run --rm openclaw-cli onboard --no-install-daemon
```

When prompted:
- Gateway bind: `0.0.0.0` (to allow external access)
- Gateway auth: `token`
- Gateway token: (use the token from your `.env` file)
- Tailscale exposure: `Off` (unless you're using Tailscale)
- Install Gateway daemon: `No` (we'll use Docker)

### Add Discord Channel

```bash
# Add Discord bot to OpenClaw
docker compose run --rm openclaw-cli channels add --channel discord --token YOUR_DISCORD_BOT_TOKEN
```

Replace `YOUR_DISCORD_BOT_TOKEN` with your actual Discord bot token.

### Configure OpenAI Model

```bash
# Configure OpenAI as your model provider
docker compose run --rm openclaw-cli models add --provider openai --api-key YOUR_OPENAI_API_KEY
```

Replace `YOUR_OPENAI_API_KEY` with your actual OpenAI API key.

### Start the Gateway

```bash
# Start OpenClaw Gateway
docker compose up -d openclaw-gateway

# Check logs
docker compose logs -f openclaw-gateway
```

## Step 8: Configure AWS Security Group

1. Go to EC2 → Security Groups → Select your instance's security group
2. Add inbound rules:
   - **Type**: Custom TCP
   - **Port**: 18789
   - **Source**: Your IP or 0.0.0.0/0 (less secure, only for testing)
   - **Description**: OpenClaw Gateway

## Step 9: Test Your Deployment

### Test Gateway Health

```bash
# From your local machine or EC2 instance
curl http://YOUR_EC2_IP:18789/health
```

### Test Discord Integration

1. Go to your Discord server
2. Send a message mentioning your bot or in a DM
3. The bot should respond

### Test OpenAI Integration

```bash
# Send a test message via CLI
docker compose run --rm openclaw-cli agent --message "Hello, test OpenAI integration"
```

## Step 10: Set Up as System Service (Optional)

Create a systemd service to keep OpenClaw running:

```bash
sudo nano /etc/systemd/system/openclaw.service
```

Add:

```ini
[Unit]
Description=OpenClaw Gateway
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/ubuntu/openclaw
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
User=ubuntu
Group=ubuntu

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable openclaw
sudo systemctl start openclaw
```

## Troubleshooting

### Check Gateway Logs

```bash
docker compose logs -f openclaw-gateway
```

### Check Discord Connection

```bash
docker compose run --rm openclaw-cli channels list
```

### Verify OpenAI API Key

```bash
docker compose run --rm openclaw-cli models list
```

### Restart Services

```bash
docker compose restart openclaw-gateway
```

### View Configuration

```bash
cat ~/.openclaw/config.json
```

## Security Best Practices

1. **Never commit `.env` file** - It contains sensitive credentials
2. **Use AWS Secrets Manager** for production (see below)
3. **Restrict Security Group** - Only allow port 18789 from trusted IPs
4. **Use HTTPS** - Set up a reverse proxy (nginx) with SSL
5. **Regular Updates** - Keep Docker and system packages updated

## Using AWS Secrets Manager (Production)

For production, store secrets in AWS Secrets Manager:

```bash
# Store secrets
aws secretsmanager create-secret \
  --name openclaw/discord-token \
  --secret-string "your-discord-token"

aws secretsmanager create-secret \
  --name openclaw/openai-key \
  --secret-string "your-openai-key"

aws secretsmanager create-secret \
  --name openclaw/gateway-token \
  --secret-string "your-gateway-token"
```

Retrieve in your deployment script:

```bash
DISCORD_TOKEN=$(aws secretsmanager get-secret-value --secret-id openclaw/discord-token --query SecretString --output text)
OPENAI_KEY=$(aws secretsmanager get-secret-value --secret-id openclaw/openai-key --query SecretString --output text)
```

## GitHub Integration & Kanban (GitHub Projects)

You chose **GitHub Projects** as your kanban system and your **portmi3-ai** account as the owner.

### 1. Create a Personal Access Token (PAT)

1. Go to `https://github.com/settings/tokens?type=beta` (fine-grained tokens recommended)
2. Create a new token with:\n
   - Access to the `portmi3-ai` account\n
   - Repository access for the repos you want Clawdbot to touch (read/write)\n
   - Access to **Projects** (read/write)\n
3. Copy the token and add it to your `.env`:\n

```bash
GITHUB_USERNAME=portmi3-ai
GITHUB_TOKEN=ghp_your_fine_grained_token_here
```

> Never commit this token. Treat it like a password.

### 2. Create a Kanban Board (GitHub Project)

1. Go to your main repo (for example, `https://github.com/portmi3-ai/openclaw`)\n
2. Click the **Projects** tab → **New project**\n
3. Choose **Board** view (kanban)\n
4. Create columns like:\n
   - `Inbox`\n
   - `Doing`\n
   - `Blocked`\n
   - `Done`\n
5. Optionally define labels (e.g., `priority:high`, `area:aws`, `owner:sasha`) so the assistant can categorize work.

### 3. Let OpenClaw Work with GitHub

Once the PAT is present in `.env` and Docker is restarted, you can start using GitHub from the CLI/agents:

- Use a convention like: \"create a GitHub task in Inbox\" and have tools/skills map that to creating an issue + adding it to the Project board.\n
- Store any helper scripts or skills for this in the workspace (for example under `~/.openclaw/workspace/projects/`).

You can later add a dedicated script or skill that reads `GITHUB_USERNAME` / `GITHUB_TOKEN` and manages cards/issues automatically.

## Second Brain & Filesystem Layout

You chose a **Markdown Git repo** as your second brain.

### 1. Create a Second-Brain Repository

1. In GitHub, create a **private** repo under your account, for example: `second-brain`.\n
2. Clone it onto your EC2 instance under the OpenClaw workspace:

```bash
cd /home/ubuntu
mkdir -p .openclaw/workspace
cd .openclaw/workspace

git clone https://github.com/portmi3-ai/second-brain.git second-brain
```

3. Set these values in your `.env` (if not already set):

```bash
SECOND_BRAIN_REPO_URL=https://github.com/portmi3-ai/second-brain.git
SECOND_BRAIN_LOCAL_PATH=/home/ubuntu/.openclaw/workspace/second-brain
```

### 2. Recommended Folder Structure

Inside `second-brain`, a simple structure works well:

```text
second-brain/
  daily/
    2026-02-03.md
    2026-02-04.md
  projects/
    openclaw-aws.md
    github-kanban.md
  people/
    sasha.md
    owner.md
  inbox.md
```

This makes it easy for OpenClaw to:\n
- Append notes to `daily/` or `inbox.md`\n
- Maintain project docs in `projects/`\n
- Track people (like Sasha) in `people/`.\n

### 3. Representing Sasha

You asked to add **Sasha** as a contact. Fill these in your `.env`:

```bash
SASHA_NAME=Sasha
SASHA_EMAIL=sasha@example.com   # replace with Sasha's real email
```

You can also create a note for her:

```bash
echo "- Contact: Sasha\n- Email: \$SASHA_EMAIL\n- Role: collaborator" >> /home/ubuntu/.openclaw/workspace/second-brain/people/sasha.md
```

Later, OpenClaw skills can use these values to:\n
- Assign GitHub tasks to Sasha (via labels or assignee)\n
- Mention her in issue descriptions\n
- Log notes about her in the `people/sasha.md` file.

## Next Steps

- Set up reverse proxy with nginx for HTTPS
- Configure automatic backups
- Set up monitoring and alerts
- Configure auto-scaling if needed
- Set up CloudWatch logging

## Support

- Documentation: https://docs.openclaw.ai
- Discord Community: https://discord.gg/clawd
- GitHub Issues: https://github.com/openclaw/openclaw/issues
