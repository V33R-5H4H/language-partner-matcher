#!/bin/bash
# ============================================================
# EC2 Update Script — called by GitHub Actions on every deploy
# Pulls new Docker image from ECR and restarts containers.
# ============================================================
set -euo pipefail

APP_DIR="/home/ubuntu/app"
AWS_REGION="ap-south-1"
IMAGE_TAG="${1:-latest}"  # Pass specific image tag from GitHub Actions

echo "=== Updating Language Partner Matcher ==="
echo "Image tag: $IMAGE_TAG"

# Pull latest code (for compose file updates)
git -C "$APP_DIR" fetch origin main
git -C "$APP_DIR" reset --hard origin/main

# Re-auth with ECR
ECR_REGISTRY=$(aws ecr describe-repositories \
  --repository-names langmatcher-backend \
  --region $AWS_REGION \
  --query 'repositories[0].repositoryUri' \
  --output text | sed 's|/.*||')
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin "$ECR_REGISTRY"

# Write override with exact image tag
cat > "$APP_DIR/backend/docker-compose.override.yml" << EOF
services:
  fastapi_backend:
    image: ${ECR_REGISTRY}/langmatcher-backend:${IMAGE_TAG}
EOF

# Pull and restart
cd "$APP_DIR/backend"
docker compose -f docker-compose.prod.yml -f docker-compose.override.yml pull
docker compose -f docker-compose.prod.yml -f docker-compose.override.yml up -d --no-build

# Health check
sleep 10
curl -sf http://localhost:8000/api/v1/health && echo "Deploy successful" || \
  (echo "Deploy FAILED" && docker compose logs fastapi_backend --tail=30 && exit 1)

# Cleanup old images
docker image prune -f --filter "until=24h"
echo "Done."
