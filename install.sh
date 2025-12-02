#!/bin/bash

HOSTNAME=$(hostname)
DOMAIN="${HOSTNAME}.devstech.web.id" # Set domain here
WEBHOOK_URL="https://rachel.devstech.web.id/api/v1/compute-webhooks/installation-progress"

PROGRESS=0
CURRENT_STEP="install_docker"

# Helper send progress
send_progress() {
  local status="$1"
  local message="${2:-}"
  local error="${3:-0}"
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local subdomains='["n8n"]'

  # send json webhook
  curl -s -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "{
      \"hostname\":\"$HOSTNAME\",
      \"step\":\"$CURRENT_STEP\",
      \"status\":\"$status\",
      \"progress\":\"$PROGRESS\",
      \"message\":\"$message\",
      \"timestamp\":\"$timestamp\",
      \"subdomains\": $subdomains
    }" >/dev/null 2>&1
}

trap '
  LINE=$LINENO
  CMD=$(sed -n ${LINENO}p $0 | sed "s/\"/\\\"/g")
  send_progress "failed" "Installation failed during $LINE: $CMD" 1
  exit 1
' ERR

set -e

# --- Installation steps ---

PROGRESS=10
CURRENT_STEP="setup"
send_progress "running" "Running installation..."

PROGRESS=30
CURRENT_STEP="install_docker"
send_progress "running" "Preparing environment..."

# Add Docker's official GPG key:
# sudo apt-get update
# sudo apt-get install -y ca-certificates curl
# sudo install -m 0755 -d /etc/apt/keyrings
# sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
# sudo chmod a+r /etc/apt/keyrings/docker.asc

# # Add the repository to Apt sources:
# echo \
#   "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
#   $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
#   sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
# sudo apt-get update

# # Install docker packages
# sudo apt-get install -y docker-ce=5:28.5.2-1~ubuntu.22.04~jammy docker-ce-cli=5:28.5.2-1~ubuntu.22.04~jammy containerd.io docker-buildx-plugin docker-compose-plugin
# # Mark Docker packages as hold to keep version 28.x — newer versions (>=29) are not yet fully supported by Traefik
# sudo apt-mark hold docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# # Start docker
# sudo systemctl enable docker
# sudo systemctl start docker

PROGRESS=50
CURRENT_STEP="install_docker"
send_progress "success" "Docker installed."

# Setup compose
COMPOSE_DIR="/n8n"
mkdir -p "$COMPOSE_DIR"

# Clone compose if repo doesn't exist
if [ -d "$COMPOSE_DIR/.git" ]; then
  cd "$COMPOSE_DIR"
  git pull
else
  git clone https://github.com/AlpinTriMCI/initial-n8n-tools.git "$COMPOSE_DIR" # Set git url
  cd "$COMPOSE_DIR"
fi

# Create .env file for docker compose
cat <<EOF > .env
# DOMAIN_NAME and SUBDOMAIN together determine where n8n will be reachable from
# The top level domain to serve from
DOMAIN_NAME=${DOMAIN}

# The subdomain to serve from
SUBDOMAIN=n8n

# The above example serve n8n at: https://n8n.example.com

# Optional timezone to set which gets used by Cron and other scheduling nodes
# New York is the default value if not set
# GENERIC_TIMEZONE=Europe/Berlin

# The email address to use for the TLS/SSL certificate creation
SSL_EMAIL=user@${DOMAIN}
EOF

# Run docker compose
PROGRESS=90
CURRENT_STEP="build_compose"
send_progress "running" "Deploying containers..."

sudo docker compose up -d

PROGRESS=100
CURRENT_STEP="build_compose"
send_progress "success" "Installation completed successfully."

# Disable trap before cleanup
trap - ERR

# --- Cleanup ---
cd /
sudo apt clean
sudo rm -rf /var/lib/apt/lists/*

sudo sh -c ': > /var/log/cloud-init.log'
sudo sh -c ': > /var/log/cloud-init-output.log'

sudo rm -rf /n8n/.git

( sleep 2 && rm -- "$0" ) &