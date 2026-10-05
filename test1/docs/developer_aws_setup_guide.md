# Developer AWS Setup & Optimization Guide

This guide is a hands-on walkthrough for you as the developer to provision, configure, and connect the required AWS services (**EC2 ASG, ALB, RDS, Secrets Manager**) from the **AWS Management Console** or **AWS CLI**, including cost optimization (Free-Tier friendly) and recommended improvements.

---

## 1. Quick Summary of Required AWS Services

| AWS Service | Deployment Tier | Free-Tier Friendly Sizing | Role |
| :--- | :--- | :--- | :--- |
| **Amazon RDS** | Database | `db.t3.micro` / `db.t4g.micro` (PostgreSQL 15) | Persistent relational user and matchmaking data. |
| **AWS Secrets Manager** | Security | Standard secret ($0.40/mo) | Zero hardcoded passwords; runtime credential injection. |
| **EC2 Auto Scaling (ASG)** | Compute | `t3.micro` instances (1 to 3 instances) | Dockerized FastAPI application instances. |
| **Application Load Balancer (ALB)** | Networking | 1 Internet-Facing ALB | HTTPS / WSS traffic routing & persistent WebSocket stickiness. |
| **Coturn (EC2)** | NAT Traversal | `t3.micro` on Public Subnet | P2P video relay for Symmetric NAT mobile networks. |

---

## 2. Step-by-Step Developer Setup Instructions

### Step 1: Create AWS Secrets Manager Secret
*Why first?* Your backend compute and database rely on these secrets.
1. Open the **AWS Secrets Manager Console** $\to$ Click **Store a new secret**.
2. Select **Other type of secret**.
3. Add the following Key/Value pairs:
   - `DATABASE_URL`: `postgresql+asyncpg://postgres:YourSecurePassword123@<RDS_ENDPOINT>:5432/langmatcher`
   - `REDIS_URL`: `redis://<REDIS_ENDPOINT>:6379/0`
   - `JWT_SECRET_KEY`: `<Generate a random 64-character hexadecimal string>`
   - `TURN_SECRET`: `<Generate a secure random string>`
4. Name the secret: `langmatcher/production/secrets`.
5. Click **Next** through default rotation settings and click **Store**.

---

### Step 2: Provision Amazon RDS (PostgreSQL)
1. Open the **Amazon RDS Console** $\to$ Click **Create database**.
2. Choose **Standard create** $\to$ **PostgreSQL** (Engine version: 15.x).
3. Under **Templates**, select **Free tier**.
4. **Settings:**
   - DB instance identifier: `langmatcher-db`
   - Master username: `postgres`
   - Master password: `YourSecurePassword123` *(same as in Secrets Manager)*.
5. **Instance configuration:** `db.t3.micro` (or `db.t4g.micro`).
6. **Connectivity:**
   - VPC: Select your custom VPC or Default VPC.
   - Public access: **No** *(Security best practice: keep database in private subnets)*.
   - Security Group: Create a new security group `sg-rds` allowing inbound `TCP 5432` from your EC2 security group `sg-backend`.
7. **Additional configuration:**
   - Initial database name: `langmatcher`.
8. Click **Create database**. Once available, copy the **Endpoint** and update the `DATABASE_URL` in Secrets Manager.

---

### Step 3: Create Application Load Balancer (ALB)
1. Open **Amazon EC2 Console** $\to$ Go to **Target Groups** (under Load Balancing).
   - Click **Create target group**.
   - Target type: **Instances**.
   - Target group name: `tg-fastapi`.
   - Protocol: `HTTP`, Port: `8000`.
   - Health check path: `/api/v1/health` *(Timeout: 5s, Interval: 15s, Healthy threshold: 2)*.
   - Under **Group attributes** $\to$ Enable **Stickiness** (Duration: 1 day).
2. Go to **Load Balancers** $\to$ Click **Create load balancer** $\to$ **Application Load Balancer**.
   - Name: `alb-langmatcher`.
   - Scheme: **Internet-facing**.
   - IP address type: IPv4.
   - Network mapping: Select at least two Availability Zones (Subnets).
   - Security Group: Create `sg-alb` allowing inbound `HTTP (80)` and `HTTPS (443)` from `0.0.0.0/0`.
   - Listeners:
     - `HTTP:80` $\to$ Redirect to `HTTPS:443` (or forward to `tg-fastapi` for initial testing).
     - `HTTPS:443` $\to$ Forward to `tg-fastapi` (attach certificate from AWS Certificate Manager).

---

### Step 4: Configure IAM Role for EC2 Instances
1. Open **IAM Console** $\to$ Click **Roles** $\to$ **Create role**.
2. Select **AWS service** $\to$ Use case: **EC2**.
3. Attach policies:
   - `SecretsManagerReadWrite` (or custom least-privilege policy for `langmatcher/production/secrets`).
   - `AmazonSSMManagedInstanceCore` *(allows secure browser-based terminal access without opening SSH port 22)*.
4. Name the role: `role-fastapi-backend`.

---

### Step 5: Create EC2 Launch Template & Auto Scaling Group (ASG)
1. In EC2 Console, go to **Launch Templates** $\to$ Click **Create launch template**.
   - Name: `lt-langmatcher-backend`.
   - AMI: **Ubuntu Server 22.04 LTS (HVM), SSD Volume Type** (Free-tier eligible).
   - Instance type: `t3.micro`.
   - Security group: `sg-backend` (allows `TCP 8000` from `sg-alb`).
   - Advanced details:
     - IAM instance profile: `role-fastapi-backend`.
     - **User data script** (paste the boot script to auto-pull secrets and launch container):
       ```bash
       #!/bin/bash
       apt-get update -y
       apt-get install -y docker.io awscli jq
       systemctl start docker
       systemctl enable docker

       # Pull Secrets
       SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id langmatcher/production/secrets --query SecretString --output text --region us-east-1)
       export DATABASE_URL=$(echo $SECRET_JSON | jq -r .DATABASE_URL)
       export REDIS_URL=$(echo $SECRET_JSON | jq -r .REDIS_URL)
       export JWT_SECRET_KEY=$(echo $SECRET_JSON | jq -r .JWT_SECRET_KEY)

       # Run Docker Container
       docker run -d --restart always \
         -p 8000:8000 \
         -e DATABASE_URL="$DATABASE_URL" \
         -e REDIS_URL="$REDIS_URL" \
         -e JWT_SECRET_KEY="$JWT_SECRET_KEY" \
         --name fastapi_app \
         your-docker-hub-or-ecr-repo/langmatcher-backend:latest
       ```
2. Go to **Auto Scaling Groups** $\to$ Click **Create Auto Scaling group**.
   - Name: `asg-langmatcher`.
   - Launch template: `lt-langmatcher-backend`.
   - Network: Select VPC and private application subnets.
   - Load balancing: **Attach to an existing load balancer** $\to$ Select `tg-fastapi`.
   - Health checks: Turn on **EC2 and ELB health checks**.
   - Group size:
     - Desired capacity: `1` (or `2`)
     - Minimum capacity: `1`
     - Maximum capacity: `3`
   - Scaling policies: **Target tracking scaling policy** $\to$ Average CPU utilization at `70%`.

---

## 3. Recommended Architectural Improvements

1. **Amazon CloudFront CDN for Flutter Web Client:**
   - If hosting the Flutter Web build (`build/web`), deploy it to an **Amazon S3 bucket** configured as a website behind **Amazon CloudFront**. This provides worldwide low-latency caching and free SSL.
2. **AWS Systems Manager (Session Manager) instead of SSH Port 22:**
   - Keep port 22 closed on all EC2 instances. Use SSM Session Manager to securely open an interactive shell in the AWS Console with full audit logging.
3. **AWS Certificate Manager (ACM) Free SSL:**
   - Request a free public wildcard certificate (`*.yourdomain.com`) in ACM and attach it directly to your ALB listener.
4. **AWS CloudWatch Alarms & Budget Alert:**
   - Set up an **AWS Budget Alert** at $5.00/month to be notified immediately if any resource exceeds the expected Free Tier threshold.
