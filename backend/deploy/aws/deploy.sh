#!/usr/bin/env bash
# ==============================================================================
# Language Partner Matcher - AWS EC2 One-Click Deployment Script
# Targets: Ubuntu 22.04 / 24.04 LTS (x86_64 or ARM64)
# ==============================================================================

set -e

echo "=========================================================="
echo " Starting Language Partner Matcher AWS Deployment"
echo "=========================================================="

# 1. Update and install prerequisites
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg lsb-release git

# 2. Install Docker & Docker Compose Plugin if missing
if ! command -v docker &> /dev/null; then
    echo " Installing Docker..."
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo usermod -aG docker $USER
    echo "Docker installed successfully."
fi

# 3. Detect Public IP of EC2 Instance
PUBLIC_IP=$(curl -s http://checkip.amazonaws.com || curl -s https://ifconfig.me)
echo " Detected EC2 Public IP: $PUBLIC_IP"

# 4. Generate Production Secrets if .env.prod does not exist
if [ ! -f .env.prod ]; then
    echo " Generating production .env.prod configuration..."
    JWT_SECRET=$(openssl rand -hex 32)
    TURN_SECRET=$(openssl rand -hex 16)
    DB_PASSWORD=$(openssl rand -hex 16)

    cat <<EOF > .env.prod
ENVIRONMENT=production
DATABASE_URL=postgresql+asyncpg://postgres:${DB_PASSWORD}@postgres_db:5432/langmatcher
REDIS_URL=redis://redis_cache:6379/0
JWT_SECRET_KEY=${JWT_SECRET}
TURN_DOMAIN=${PUBLIC_IP}
TURN_SHARED_SECRET=${TURN_SECRET}
TURN_PORT_UDP=3478
TURN_PORT_TLS=5349
EOF
    echo "Created .env.prod with secure random secrets."
fi

# 5. Build and Launch Containers
echo "Starting production Docker containers..."
sudo docker compose -f docker-compose.prod.yml up -d --build

# 6. Verify Health
echo " Waiting for backend health check..."
sleep 8

if curl -s http://localhost:8000/docs > /dev/null; then
    echo "=========================================================="
    echo " SUCCESS! Backend is running live on AWS!"
    echo "=========================================================="
    echo " Public API URL:       http://${PUBLIC_IP}:8000"
    echo " API Docs (Swagger):   http://${PUBLIC_IP}:8000/docs"
    echo " WebSocket Signaling:  ws://${PUBLIC_IP}:8000/ws"
    echo " Coturn TURN Relay:    turn:${PUBLIC_IP}:3478 (UDP)"
    echo "=========================================================="
    echo " Point your Flutter app to: http://${PUBLIC_IP}:8000"
    echo "=========================================================="
else
    echo " Backend did not respond on localhost:8000 yet. Check logs with: sudo docker compose -f docker-compose.prod.yml logs"
fi
