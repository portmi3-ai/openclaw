#!/usr/bin/env bash
# Add swap space to prevent OOM kills on t2.micro instances
# Run with: sudo bash add-swap.sh

set -euo pipefail

SWAP_SIZE="${1:-2G}"  # Default 2GB swap

echo "Adding ${SWAP_SIZE} swap space..."

# Check if swap already exists
if swapon --show | grep -q .; then
    echo "Swap already exists:"
    swapon --show
    echo "Skipping swap creation"
    exit 0
fi

# Create swap file
SWAP_FILE="/swapfile"
sudo fallocate -l "$SWAP_SIZE" "$SWAP_FILE" || sudo dd if=/dev/zero of="$SWAP_FILE" bs=1M count=$(echo "$SWAP_SIZE" | sed 's/G/*1024/' | bc) 2>/dev/null || {
    echo "Failed to create swap file. Trying alternative method..."
    sudo dd if=/dev/zero of="$SWAP_FILE" bs=1024 count=2097152  # 2GB default
}

# Set correct permissions
sudo chmod 600 "$SWAP_FILE"

# Make it swap
sudo mkswap "$SWAP_FILE"

# Enable swap
sudo swapon "$SWAP_FILE"

# Make it permanent
if ! grep -q "$SWAP_FILE" /etc/fstab; then
    echo "$SWAP_FILE none swap sw 0 0" | sudo tee -a /etc/fstab
fi

echo "Swap added successfully!"
echo ""
free -h
echo ""
echo "Swap will persist across reboots"
