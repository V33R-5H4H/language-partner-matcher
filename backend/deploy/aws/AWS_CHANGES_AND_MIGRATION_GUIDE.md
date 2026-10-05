# 🛠️ Document 2: AWS Changes & Migration Guide
## Implementation Blueprint: Migrating from Single-Docker to EC2 (ASG), ALB, RDS & Secrets Manager

This document details every specific code modification, dependency update, configuration change, and infrastructure deployment step required to migrate the **Language Partner Matcher** from the single-server Docker setup to the enterprise AWS stack.

---

## 1. Summary of Changes Required

| Area | What Needs to Change | Why It is Needed |
| :--- | :--- | :--- |
| **Backend Code** | Add AWS Secrets Manager client in `app/core/config.py` | Automatically fetches DB credentials, JWT secrets, and TURN keys from AWS Secrets Manager without `.env` files. |
| **Backend Code** | Add `/health` endpoint in `app/main.py` | Allows ALB Target Group to perform health checks and prune unhealthy EC2 instances. |
| **Backend Dependencies** | Add `boto3` to `backend/requirements.txt` | Official AWS SDK for Python to communicate with Secrets Manager. |
| **Database** | Switch `DATABASE_URL` from local container to **Amazon RDS endpoint** | Offloads state to managed Multi-AZ PostgreSQL with automated daily snapshots. |
| **EC2 Launch Template** | Add `user_data.sh` startup script | Automatically pulls code/Docker image, starts the backend container, and registers with the ALB on instance spawn. |
| **Frontend Config** | Set `baseUrl` to ALB domain (`https://...` and `wss://...`) | Connects Flutter clients to the load-balanced, SSL-terminated AWS endpoint. |

---

## 2. Specific Code Modifications

### 2.1. Backend: Update `backend/requirements.txt`
Add `boto3` to enable AWS SDK access:

```diff
  fastapi==0.110.0
  uvicorn[standard]==0.28.0
  sqlalchemy[asyncio]==2.0.28
  asyncpg==0.29.0
  redis[hiredis]==5.0.3
  pydantic-settings==2.2.1
  python-jose[cryptography]==3.3.0
  passlib[bcrypt]==1.7.4
+ boto3==1.34.84
```

---

### 2.2. Backend: Add AWS Secrets Manager Fetcher to `app/core/config.py`
Modify `config.py` so it reads from **AWS Secrets Manager** when running in AWS, while keeping a seamless fallback to `.env` for local development:

```python
import json
import os
import boto3
from botocore.exceptions import ClientError
from pydantic_settings import BaseSettings

def fetch_aws_secrets(secret_name: str, region_name: str = "ap-south-1") -> dict:
    """Fetch JSON secrets from AWS Secrets Manager using IAM Instance Profile credentials."""
    session = boto3.session.Session()
    client = session.client(service_name="secretsmanager", region_name=region_name)
    try:
        response = client.get_secret_value(SecretId=secret_name)
        if "SecretString" in response:
            return json.loads(response["SecretString"])
    except ClientError as e:
        print(f"⚠️ AWS Secrets Manager fallback: {e}")
    return {}

class Settings(BaseSettings):
    # Core Application
    PROJECT_NAME: str = "Language Partner Matcher"
    ENVIRONMENT: str = os.getenv("ENVIRONMENT", "development")
    API_V1_STR: str = "/api/v1"
    
    # Database & Cache (Defaults or populated from Secrets Manager)
    DATABASE_URL: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/langmatcher"
    REDIS_URL: str = "redis://localhost:6379/0"
    
    # Security & Tokens
    JWT_SECRET_KEY: str = "development_secret_key_change_in_production_12345"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7 # 7 days
    
    # Coturn TURN Server
    TURN_DOMAIN: str = "127.0.0.1"
    TURN_SHARED_SECRET: str = "development_turn_secret_xyz789"
    TURN_PORT_UDP: int = 3478
    TURN_PORT_TLS: int = 5349

    class Config:
        env_file = ".env"
        extra = "allow"

    @classmethod
    def load_settings(cls):
        # If running in AWS production, fetch from Secrets Manager
        secret_name = os.getenv("AWS_SECRET_NAME", "langmatcher/production/secrets")
        aws_region = os.getenv("AWS_DEFAULT_REGION", "ap-south-1")
        
        aws_secrets = fetch_aws_secrets(secret_name, aws_region)
        if aws_secrets:
            return cls(**aws_secrets)
        return cls()

settings = Settings.load_settings()
```

---

### 2.3. Backend: Add `/health` Endpoint in `app/main.py`
The ALB Target Group sends periodic health checks to ensure instances are responsive before routing traffic:

```python
@app.get("/health", tags=["System"])
async def health_check():
    """Health check endpoint utilized by AWS Application Load Balancer."""
    return {
        "status": "healthy",
        "service": "langmatcher_backend",
        "timestamp": datetime.utcnow().isoformat()
    }
```

---

## 3. Infrastructure Setup Steps (AWS Console & CLI)

### Step 1: Create the Amazon RDS PostgreSQL Instance
1. Go to **AWS RDS** $\rightarrow$ **Create Database**.
2. **Engine:** PostgreSQL 15.5
3. **Template:** Free Tier or Production.
4. **DB Instance Identifier:** `langmatcher-rds-prod`
5. **Master Username:** `postgres_admin`
6. **Master Password:** Auto-generate or set a secure password (store in Secrets Manager).
7. **Virtual Private Cloud (VPC):** Select your app VPC $\rightarrow$ choose **Private DB Subnets**.
8. **Public Access:** **No** (accessible only within VPC).
9. **VPC Security Group:** Create `sg_rds` $\rightarrow$ Allow Inbound TCP `5432` from `sg_backend_ec2`.

---

### Step 2: Store Credentials in AWS Secrets Manager
1. Go to **AWS Secrets Manager** $\rightarrow$ **Store a new secret**.
2. **Secret Type:** *Other type of secret* (Key/value pairs).
3. Add the following keys:
   - `DATABASE_URL`: `postgresql+asyncpg://postgres_admin:YOUR_RDS_PWD@YOUR_RDS_ENDPOINT:5432/langmatcher`
   - `REDIS_URL`: `redis://YOUR_ELASTICACHE_ENDPOINT:6379/0`
   - `JWT_SECRET_KEY`: `<Generate a random 64-character hex key>`
   - `TURN_DOMAIN`: `<Elastic IP of your Coturn EC2 server>`
   - `TURN_SHARED_SECRET`: `<Generate a strong random secret>`
   - `ENVIRONMENT`: `production`
4. **Secret Name:** `langmatcher/production/secrets`
5. Click **Store Secret**.

---

### Step 3: Create ALB & Target Group
1. Go to **EC2** $\rightarrow$ **Target Groups** $\rightarrow$ **Create Target Group**:
   - **Target Type:** Instances
   - **Name:** `tg-langmatcher-backend`
   - **Protocol/Port:** HTTP / `8000`
   - **Health check path:** `/health`
   - Under **Attributes**, enable **Stickiness** (type: Load balancer generated cookie, duration: 1 day).
2. Go to **EC2** $\rightarrow$ **Load Balancers** $\rightarrow$ **Create Application Load Balancer**:
   - **Name:** `alb-langmatcher-prod`
   - **Scheme:** Internet-facing (IPv4)
   - **VPC / Subnets:** Select your VPC and both **Public Subnets**.
   - **Security Group (`sg_alb`):** Allow Inbound TCP `80` and `443` from `0.0.0.0/0`.
   - **Listener:** Forward HTTP:80 and HTTPS:443 to `tg-langmatcher-backend`.

---

### Step 4: Create Launch Template & Auto Scaling Group (ASG)

1. **Create IAM Role (`role-langmatcher-ec2`):**
   - Attach policy: `SecretsManagerReadWrite`, `CloudWatchAgentServerPolicy`.
2. **Create Launch Template (`lt-langmatcher-backend`):**
   - **AMI:** Ubuntu 22.04 LTS
   - **Instance Type:** `t3.small`
   - **IAM Instance Profile:** `role-langmatcher-ec2`
   - **Security Group (`sg_backend_ec2`):** Allow TCP `8000` from `sg_alb`.
   - **Advanced Details $\rightarrow$ User Data:**
     ```bash
     #!/bin/bash
     apt-get update -y
     apt-get install -y docker.io git
     systemctl start docker
     systemctl enable docker

     # Clone and start application container
     git clone https://github.com/your-username/language-partner-matcher.git /opt/app
     cd /opt/app/backend
     
     docker build -t langmatcher_backend .
     docker run -d --restart always --name backend \
       -p 8000:8000 \
       -e AWS_SECRET_NAME="langmatcher/production/secrets" \
       -e AWS_DEFAULT_REGION="ap-south-1" \
       langmatcher_backend
     ```
3. **Create Auto Scaling Group (`asg-langmatcher-prod`):**
   - Attach Launch Template `lt-langmatcher-backend`.
   - Subnets: Select **Private App Subnets**.
   - Attach to existing Load Balancer Target Group: `tg-langmatcher-backend`.
   - **Capacity:** Min: 1, Desired: 2, Max: 6.
   - **Scaling Policy:** Target tracking on CPU ($70\%$).

---

## 4. Frontend Configuration

In your Flutter app (`lib/core/constants/api_endpoints.dart`), point `baseUrl` to the ALB DNS name or custom domain:

```dart
class ApiEndpoints {
  static String get baseUrl {
    const custom = String.fromEnvironment('API_BASE_URL');
    if (custom.isNotEmpty) return custom;
    
    // AWS Application Load Balancer domain (with SSL)
    return 'https://api.yourdomain.com'; // or http://alb-langmatcher-prod-12345.ap-south-1.elb.amazonaws.com
  }

  static String get wsUrl {
    final base = baseUrl;
    if (base.startsWith('https://')) {
      return base.replaceFirst('https://', 'wss://');
    }
    return base.replaceFirst('http://', 'ws://');
  }
}
```

Run with:
```powershell
flutter run -d chrome --dart-define=API_BASE_URL=https://api.yourdomain.com
```

---

## 5. Verification Checklist

- [ ] **RDS Connectivity:** Backend containers connect to PostgreSQL via Private Subnet on port 5432.
- [ ] **Secrets Manager Integration:** Backend logs show zero missing environment variables; secrets retrieved via IAM role.
- [ ] **ALB Health Checks:** Target Group shows registered EC2 targets with health status `healthy` on `/health`.
- [ ] **WebSocket Upgrades:** Flutter client establishes `wss://` signaling connection through ALB without disconnection.
- [ ] **ASG Auto-Scaling:** Stress test on EC2 triggers ASG scale-out from 2 to 4 instances automatically.
- [ ] **Coturn TURN Traversal:** Mobile 4G clients successfully negotiate WebRTC calls through the Coturn TURN server.
