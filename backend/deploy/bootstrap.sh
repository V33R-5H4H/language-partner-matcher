#!/bin/bash
# ============================================================
# EC2 Bootstrap Script — Language Partner Matcher
# Run once on a fresh Ubuntu 22.04 instance.
# Called by GitHub Actions on first-time setup, or run manually.
# ============================================================
set -euo pipefail

APP_DIR="/home/ubuntu/app"
COMPOSE_FILE="$APP_DIR/backend/docker-compose.prod.yml"
AWS_REGION="ap-south-1"

echo "=== [1/6] Installing system packages ==="
apt-get update -y
apt-get install -y \
  curl git unzip awscli \
  docker.io docker-compose-plugin \
  nginx certbot python3-certbot-nginx \
  htop jq

# Start and enable Docker
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

echo "=== [2/6] Cloning repository ==="
# Uses a GitHub Deploy Key (read-only) added in EC2 user-data
if [ ! -d "$APP_DIR" ]; then
  git clone git@github.com:V33R-5H4H/language-partner-matcher.git "$APP_DIR"
else
  echo "Repo already exists at $APP_DIR — pulling latest"
  git -C "$APP_DIR" pull origin main
fi

echo "=== [3/6] Writing .env from AWS Secrets Manager ==="
# Secrets stored in AWS Secrets Manager: langmatcher/prod
aws secretsmanager get-secret-value \
  --secret-id langmatcher/prod \
  --region $AWS_REGION \
  --query SecretString \
  --output text | python3 -c "
import json, sys
s = json.load(sys.stdin)
for k, v in s.items():
    print(f'{k}={v}')
" > "$APP_DIR/backend/.env"
chmod 600 "$APP_DIR/backend/.env"
echo ".env written from Secrets Manager"

echo "=== [4/6] Authenticating Docker with ECR ==="
ECR_REGISTRY=$(aws ecr describe-repositories \
  --repository-names langmatcher-backend \
  --region $AWS_REGION \
  --query 'repositories[0].repositoryUri' \
  --output text | sed 's|/.*||')
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin "$ECR_REGISTRY"

echo "=== [5/6] Starting services with Docker Compose ==="
cd "$APP_DIR/backend"
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d

echo "=== [6/6] Health check ==="
sleep 15
curl -sf http://localhost:8000/api/v1/health && echo "API healthy!" || \
  (echo "Health check FAILED" && docker compose logs --tail=50 && exit 1)

echo ""
echo "============================================"
echo " Bootstrap complete!"
echo " API running at http://$(curl -s ifconfig.me):8000"
echo " Check logs: docker compose -f $COMPOSE_FILE logs -f"
echo "============================================"
