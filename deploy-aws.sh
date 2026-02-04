#!/usr/bin/env bash
# OpenClaw AWS Deployment Script
# This script automates the deployment of OpenClaw to AWS EC2

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
COMPOSE_OVERRIDE_FILE="$SCRIPT_DIR/docker-compose.aws.yml"

# Build docker compose arguments (base + optional AWS override)
build_compose_args() {
    local -n _out=$1
    _out=( -f "$COMPOSE_FILE" )

    if [ -f "$COMPOSE_OVERRIDE_FILE" ]; then
        _out+=( -f "$COMPOSE_OVERRIDE_FILE" )
    fi
}

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_dependencies() {
    log_info "Checking dependencies..."
    
    local missing_deps=()
    
    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        missing_deps+=("docker-compose")
    fi
    
    if ! command -v git &> /dev/null; then
        missing_deps+=("git")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "Please install them first:"
        log_info "  sudo apt update && sudo apt install -y docker.io docker-compose git"
        exit 1
    fi
    
    log_info "All dependencies installed ✓"
}

check_env_file() {
    log_info "Checking environment file..."
    
    if [ ! -f "$ENV_FILE" ]; then
        log_error ".env file not found!"
        log_info "Please copy .env.template to .env and fill in your values:"
        log_info "  cp .env.template .env"
        log_info "  nano .env"
        exit 1
    fi
    
    # Source the .env file to check for required variables
    set -a
    source "$ENV_FILE"
    set +a
    
    local missing_vars=()

    # Gateway token is always required
    if [ -z "${OPENCLAW_GATEWAY_TOKEN:-}" ] || [ "$OPENCLAW_GATEWAY_TOKEN" = "your-secure-random-token-here-generate-with-openssl-rand-hex-32" ]; then
        missing_vars+=("OPENCLAW_GATEWAY_TOKEN")
    fi

    # Discord/OpenAI are only required if their steps are enabled
    if [ "${skip_discord:-false}" = false ]; then
        if [ -z "${DISCORD_BOT_TOKEN:-}" ] || [ "$DISCORD_BOT_TOKEN" = "your-discord-bot-token-here" ]; then
            missing_vars+=("DISCORD_BOT_TOKEN")
        fi
    fi

    if [ "${skip_openai:-false}" = false ]; then
        if [ -z "${OPENAI_API_KEY:-}" ] || [ "$OPENAI_API_KEY" = "your-openai-api-key-here" ]; then
            missing_vars+=("OPENAI_API_KEY")
        fi
    fi

    if [ ${#missing_vars[@]} -ne 0 ]; then
        log_error "Missing or unset required environment variables: ${missing_vars[*]}"
        log_info "You can either set these in .env or rerun with the matching --skip-* flags."
        exit 1
    fi

    log_info "Environment file validated ✓"
}

generate_gateway_token() {
    log_info "Generating gateway token..."
    
    if command -v openssl &> /dev/null; then
        OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 32)
    elif command -v python3 &> /dev/null; then
        OPENCLAW_GATEWAY_TOKEN=$(python3 -c "import secrets; print(secrets.token_hex(32))")
    else
        log_error "Cannot generate token: openssl or python3 not found"
        exit 1
    fi
    
    # Update .env file
    if grep -q "^OPENCLAW_GATEWAY_TOKEN=" "$ENV_FILE"; then
        sed -i "s/^OPENCLAW_GATEWAY_TOKEN=.*/OPENCLAW_GATEWAY_TOKEN=$OPENCLAW_GATEWAY_TOKEN/" "$ENV_FILE"
    else
        echo "OPENCLAW_GATEWAY_TOKEN=$OPENCLAW_GATEWAY_TOKEN" >> "$ENV_FILE"
    fi
    
    log_info "Gateway token generated and saved to .env"
}

build_image() {
    log_info "Building Docker image..."
    
    docker build \
        -t "${OPENCLAW_IMAGE:-openclaw:aws}" \
        -f "$SCRIPT_DIR/Dockerfile" \
        "$SCRIPT_DIR"
    
    log_info "Docker image built successfully ✓"
}

setup_directories() {
    log_info "Setting up directories..."
    
    mkdir -p "${OPENCLAW_CONFIG_DIR:-$HOME/.openclaw}"
    mkdir -p "${OPENCLAW_WORKSPACE_DIR:-$HOME/.openclaw/workspace}"
    
    log_info "Directories created ✓"
}

run_onboarding() {
    log_info "Running OpenClaw onboarding..."

    local compose_args=()
    build_compose_args compose_args

    docker compose "${compose_args[@]}" run --rm openclaw-cli onboard --no-install-daemon <<EOF
0.0.0.0
token
${OPENCLAW_GATEWAY_TOKEN}
n
n
EOF
    
    log_info "Onboarding completed ✓"
}

add_discord_channel() {
    log_info "Adding Discord channel..."

    local compose_args=()
    build_compose_args compose_args

    docker compose "${compose_args[@]}" run --rm openclaw-cli channels add \
        --channel discord \
        --token "$DISCORD_BOT_TOKEN"
    
    log_info "Discord channel added ✓"
}

configure_openai() {
    log_info "Configuring OpenAI model..."

    local compose_args=()
    build_compose_args compose_args

    docker compose "${compose_args[@]}" run --rm openclaw-cli models add \
        --provider openai \
        --api-key "$OPENAI_API_KEY"
    
    log_info "OpenAI model configured ✓"
}

start_gateway() {
    log_info "Starting OpenClaw Gateway..."

    local compose_args=()
    build_compose_args compose_args

    docker compose "${compose_args[@]}" up -d openclaw-gateway
    
    log_info "Gateway started ✓"
}

show_status() {
    log_info "Checking gateway status..."
    
    sleep 5  # Wait for gateway to start
    
    local compose_args=()
    build_compose_args compose_args

    if docker compose "${compose_args[@]}" ps | grep -q "openclaw-gateway.*Up"; then
        log_info "Gateway is running ✓"
        
        # Get gateway port
        local port="${OPENCLAW_GATEWAY_PORT:-18789}"
        log_info "Gateway accessible at: http://$(hostname -I | awk '{print $1}'):$port"
        log_info "Gateway token: $OPENCLAW_GATEWAY_TOKEN"
        
        # Test health endpoint
        if command -v curl &> /dev/null; then
            if curl -s -f "http://localhost:$port/health" > /dev/null 2>&1; then
                log_info "Health check passed ✓"
            else
                log_warn "Health check failed - gateway may still be starting"
            fi
        fi
    else
        log_error "Gateway failed to start"
        log_info "Check logs with: docker compose logs openclaw-gateway"
        exit 1
    fi
}

show_help() {
    cat <<EOF
OpenClaw AWS Deployment Script

Usage: $0 [OPTIONS]

Options:
    --skip-build          Skip Docker image build
    --skip-onboarding     Skip onboarding wizard
    --skip-discord        Skip Discord channel setup
    --skip-openai         Skip OpenAI configuration
    --generate-token      Generate and save gateway token
    --help                Show this help message

Examples:
    $0                    # Full deployment
    $0 --skip-build       # Skip build (use existing image)
    $0 --generate-token   # Just generate token

EOF
}

# Main execution
main() {
    log_info "Starting OpenClaw AWS deployment..."

    # Flags are global so check_env_file can see them
    skip_build=false
    skip_onboarding=false
    skip_discord=false
    skip_openai=false
    generate_token=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-build)
                skip_build=true
                shift
                ;;
            --skip-onboarding)
                skip_onboarding=true
                shift
                ;;
            --skip-discord)
                skip_discord=true
                shift
                ;;
            --skip-openai)
                skip_openai=true
                shift
                ;;
            --generate-token)
                generate_token=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    if [ "$generate_token" = true ]; then
        generate_gateway_token
        exit 0
    fi
    
    check_dependencies
    check_env_file
    setup_directories
    
    if [ "$skip_build" = false ]; then
        build_image
    fi
    
    if [ "$skip_onboarding" = false ]; then
        run_onboarding
    fi
    
    if [ "$skip_discord" = false ]; then
        add_discord_channel
    fi
    
    if [ "$skip_openai" = false ]; then
        configure_openai
    fi
    
    start_gateway
    show_status
    
    log_info "Deployment complete! 🎉"
    log_info ""
    log_info "Next steps:"
    log_info "  1. Configure AWS Security Group to allow port ${OPENCLAW_GATEWAY_PORT:-18789}"
    log_info "  2. Test Discord bot in your server"
    log_info "  3. View logs: docker compose logs -f openclaw-gateway"
    log_info "  4. Check status: docker compose ps"
}

# Run main function
main "$@"
