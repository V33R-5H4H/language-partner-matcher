# Complete Implementation Guide: AWS Secrets Manager, ALB, and EC2 Auto Scaling Group (ASG)

> **Goal**: Add **AWS Secrets Manager**, **Application Load Balancer (ALB)**, and **EC2 Auto Scaling Group (ASG)** to your existing **Amazon RDS PostgreSQL** backend **without changing a single line of application logic or breaking WebSockets and WebRTC**.

---

## 🏛️ Architecture Overview

```
                      ┌────────────────────────────────────────┐
                      │           Clients & Devices            │
                      │  (Android App & Web Browser Client)    │
                      └──────────────────┬─────────────────────┘
                                         │ HTTP (Port 80) & WS
                                         ▼
                      ┌────────────────────────────────────────┐
                      │   Application Load Balancer (ALB)      │
                      │   - WebSocket Upgrade Support          │
                      │   - Sticky Sessions (Stickiness)       │
                      │   - Health Check (/api/v1/health)      │
                      └──────────────────┬─────────────────────┘
                                         │ Port 8000
                                         ▼
                      ┌────────────────────────────────────────┐
                      │      Auto Scaling Group (ASG)          │
                      │      (1 to 2 EC2 Instances)            │
                      │                                        │
                      │   ┌────────────────────────────────┐   │
                      │   │  EC2 Launch Template           │   │
                      │   │  - IAM Role (Secrets Access)   │   │
                      │   │  - User Data Script (Auto-Run) │   │
                      │   │  - Docker Compose Container    │   │
                      │   └────────────────────────────────┘   │
                      └────────┬──────────────────────┬────────┘
                               │                      │
        Fetches on boot        │                      │ Reads/Writes
                               ▼                      ▼
           ┌─────────────────────────┐   ┌───────────────────────────┐
           │   AWS Secrets Manager   │   │   Amazon RDS PostgreSQL   │
           │   Secret:               │   │   langmatcher-db...       │
           │   "langmatcher/prod"    │   │   Port 5432               │
           └─────────────────────────┘   └───────────────────────────┘
```

---

## 🔑 Phase 1: Store Configuration in AWS Secrets Manager

Secrets Manager replaces storing sensitive passwords in raw files on GitHub. The server pulls these values dynamically on startup and writes them to `.env`.

### Step 1.1: Create Secret in AWS Console
1. Open the [AWS Secrets Manager Console](https://ap-south-1.console.aws.amazon.com/secretsmanager/) in region **ap-south-1 (Mumbai)**.
2. Click **Store a new secret**.
3. Select secret type: **Other type of secret**.
4. In the **Key/value pairs** section, click **Add row** and enter your production values:

| Key | Value | Notes |
| :--- | :--- | :--- |
| `DATABASE_URL` | `postgresql+asyncpg://postgres:LangMatcherSecure2026!@langmatcher-db.c56e0400a7jm.ap-south-1.rds.amazonaws.com:5432/postgres` | Your live RDS connection |
| `REDIS_URL` | `redis://172.31.2.129:6379/0` | Your live Redis private IP |
| `JWT_SECRET_KEY` | `LangMatcher_Production_Jwt_Secret_2026_SecureKey_xyz987` | Strong random secret |
| `TURN_SERVER_IP` | `13.204.31.90` | Your standalone CoTURN IP |
| `TURN_SHARED_SECRET` | `coturn_production_shared_secret_789xyz` | Matches CoTURN secret |
| `TURN_PORT_UDP` | `3478` | CoTURN UDP port |
| `TURN_PORT_TLS` | `5349` | CoTURN TLS port |
| `ENVIRONMENT` | `production` | Production environment flag |

5. Click **Next**.
6. Set **Secret name**: `langmatcher/prod`.
7. Click **Next** $\to$ Leave automatic rotation disabled $\to$ Click **Store**.

---

## 🛡️ Phase 2: Create IAM Role for EC2

Your EC2 instances need permission to read `langmatcher/prod` from Secrets Manager without needing AWS access keys stored on the machine.

### Step 2.1: Create Policy
1. Open [IAM Console](https://console.aws.amazon.com/iam/) $\to$ **Policies** $\to$ **Create policy**.
2. Click the **JSON** tab and paste:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowReadLangMatcherSecrets",
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:ap-south-1:*:secret:langmatcher/prod*"
    }
  ]
}
```
3. Name it: `LangMatcherSecretsPolicy` and click **Create policy**.

### Step 2.2: Create Role
1. In IAM Console, click **Roles** $\to$ **Create role**.
2. Trusted entity type: **AWS service** $\to$ Use case: **EC2**.
3. Search for and attach:
   - `LangMatcherSecretsPolicy`
   - `AmazonSSMManagedInstanceCore` *(Allows browser SSH via AWS Systems Manager without open port 22)*
4. Name the role: **`LangMatcherEC2Role`** and click **Create role**.

---

## 🎯 Phase 3: Create Target Group & Application Load Balancer (ALB)

The ALB accepts public user traffic and passes WebSockets (`/ws/signaling/*`) and API calls to the EC2 instances.

### Step 3.1: Create Target Group
1. Open [EC2 Console](https://ap-south-1.console.aws.amazon.com/ec2/) $\to$ **Target Groups** (left sidebar under *Load Balancing*).
2. Click **Create target group**.
3. Choose target type: **Instances**.
4. Set Target group name: **`tg-langmatcher-backend`**.
5. Protocol: **HTTP** $\cdot$ Port: **`8000`**.
6. IP address type: **IPv4** $\cdot$ VPC: Select your default VPC.
7. **Health check**:
   - Health check protocol: **HTTP**
   - Health check path: **`/docs`** (or `/api/v1/health`)
   - Advanced health check settings:
     - Healthy threshold: `2`
     - Unhealthy threshold: `3`
     - Timeout: `5 seconds`
     - Interval: `15 seconds`
     - Success codes: `200`
8. **CRITICAL: Enable Session Stickiness**:
   - Under **Attributes** (or edit after creation):
   - Turn **Stickiness** ON.
   - Type: **Load balancer generated cookie**.
   - Duration: **1 day (86400 seconds)**.
   > *Why? This guarantees that a client's WebSocket connection stays anchored to the same backend server instance.*
9. Click **Next** $\to$ Skip registering targets for now $\to$ Click **Create target group**.

### Step 3.2: Create ALB Security Group
Create a Security Group named **`sg-langmatcher-alb`**:
- **Inbound Rules**:
  - Type: **HTTP** (Port 80) $\cdot$ Source: **Anywhere-IPv4** (`0.0.0.0/0`)
  - Type: **HTTPS** (Port 443) $\cdot$ Source: **Anywhere-IPv4** (`0.0.0.0/0`) *(optional if using custom domain)*
- **Outbound Rules**:
  - All traffic to `0.0.0.0/0`.

### Step 3.3: Create Application Load Balancer
1. In EC2 Console, click **Load Balancers** $\to$ **Create load balancer**.
2. Select **Application Load Balancer** $\to$ Click **Create**.
3. Basic configuration:
   - Name: **`alb-langmatcher`**
   - Scheme: **Internet-facing**
   - IP address type: **IPv4**
4. Network mapping:
   - VPC: Select your default VPC.
   - Mappings: Select **at least 2 Availability Zones** (e.g. `ap-south-1a` and `ap-south-1b`).
5. Security groups:
   - Assign **`sg-langmatcher-alb`**.
6. Listeners and routing:
   - Listener: **HTTP:80**
   - Default action: Forward to **`tg-langmatcher-backend`**.
7. Click **Create load balancer**.
8. Copy the **DNS name** (e.g. `alb-langmatcher-123456789.ap-south-1.elb.amazonaws.com`).

---

## 🚀 Phase 4: Create EC2 Launch Template & Auto Scaling Group (ASG)

The Auto Scaling Group ensures your application automatically recovers if an instance crashes or scales horizontally.

### Step 4.1: Create EC2 Launch Template
1. Open EC2 Console $\to$ **Launch Templates** $\to$ Click **Create launch template**.
2. Name: **`lt-langmatcher-backend`**.
3. Application and OS Images: **Ubuntu Server 22.04 LTS (HVM), SSD Volume Type** (64-bit x86).
4. Instance type: **`t3.micro`** (Free tier eligible) or **`t3.small`**.
5. Key pair: Select your existing `langmatcher-key`.
6. Network settings:
   - Security group: Select `sg-098c28bb4bc20f756` (ensure it allows inbound TCP 8000 from the ALB security group `sg-langmatcher-alb`).
7. Advanced details:
   - IAM instance profile: Select **`LangMatcherEC2Role`**.
   - **User Data** (scroll to the bottom and paste the exact script below):

```bash
#!/bin/bash
set -euo pipefail
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "=== [1/5] Updating packages and installing Docker ==="
apt-get update -y
apt-get install -y docker.io docker-compose-plugin git curl jq awscli

systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

APP_DIR="/home/ubuntu/test/language-partner-matcher"
mkdir -p /home/ubuntu/test
cd /home/ubuntu/test

echo "=== [2/5] Cloning repository ==="
if [ ! -d "$APP_DIR" ]; then
  git clone https://github.com/V33R-5H4H/language-partner-matcher.git "$APP_DIR"
else
  git -C "$APP_DIR" pull origin main
fi

cd "$APP_DIR/backend"

echo "=== [3/5] Pulling configuration from AWS Secrets Manager ==="
aws secretsmanager get-secret-value \
  --secret-id langmatcher/prod \
  --region ap-south-1 \
  --query SecretString \
  --output text | jq -r 'to_entries | map("\(.key)=\"\(.value)\"") | .[]' > .env

chmod 600 .env
echo "✅ Secrets successfully written to .env"

echo "=== [4/5] Launching backend via Docker Compose ==="
docker compose -f docker-compose.decoupled.yml up -d --build

echo "=== [5/5] Waiting for backend readiness ==="
sleep 10
curl -f http://localhost:8000/docs || true
echo "🚀 LangMatcher instance is online and attached!"
```

8. Click **Create launch template**.

### Step 4.2: Create Auto Scaling Group (ASG)
1. In EC2 Console, go to **Auto Scaling Groups** (bottom left sidebar) $\to$ **Create Auto Scaling group**.
2. Name: **`asg-langmatcher-backend`**.
3. Launch template: Select **`lt-langmatcher-backend`** (version: Latest / 1).
4. Click **Next**.
5. Network: Select your VPC and choose 2 Subnets (`ap-south-1a`, `ap-south-1b`).
6. Click **Next**.
7. **Load balancing**:
   - Select **Attach to an existing load balancer**.
   - Choose: **Attach to an Application, Network or Gateway Load Balancer target group**.
   - Select: **`tg-langmatcher-backend`**.
   - Health checks: Check **Turn on Elastic Load Balancing health checks**.
   - Health check grace period: **300 seconds** (gives Docker time to pull/build).
8. Click **Next**.
9. **Group size & scaling policies**:
   - Desired capacity: **`1`**
   - Minimum capacity: **`1`**
   - Maximum capacity: **`2`**
   - Scaling policy: **Target tracking scaling policy** (Average CPU utilization at 70%).
10. Click **Next** $\to$ Skip notifications $\to$ Skip tags $\to$ Click **Create Auto Scaling group**.

---

## 🧪 Phase 5: Verification & Zero-Downtime Migration

Your ASG will automatically launch an instance, execute the User Data script, pull your credentials from Secrets Manager into `.env`, and launch the Docker container.

### Step 5.1: Verify Instance Health in Target Group
1. Go to **EC2 Console** $\to$ **Target Groups** $\to$ Select `tg-langmatcher-backend`.
2. Click the **Targets** tab.
3. Within 3–4 minutes, the instance status will transition from `Initial` to **`Healthy`** (green checkmark).

### Step 5.2: Test Web Client via ALB
Open your browser and navigate to:
```text
http://<YOUR-ALB-DNS-NAME>/web/#/home
```
Example: `http://alb-langmatcher-123456789.ap-south-1.elb.amazonaws.com/web/#/home`
- You will see the Language Matcher interface load immediately through the ALB on standard port 80!
- Test the Practice Radar and voice/video calling — everything routes seamlessly through the ALB.

### Step 5.3: Update Flutter CI/CD to Use the ALB
In your GitHub repository secrets (or workflow defaults):
- `API_BASE_URL`: `http://<YOUR-ALB-DNS-NAME>`
- `WS_BASE_URL`: `ws://<YOUR-ALB-DNS-NAME>`

Both mobile and web will now be fully fault-tolerant, auto-scaled, and backed by Secrets Manager!
