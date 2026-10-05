# AWS Implementation Step-by-Step Guide

This guide provides a comprehensive, production-ready blueprint for deploying the **Language Partner Matcher** cloud backend on Amazon Web Services (AWS).

---

## 1. AWS Architecture Overview

```mermaid
flowchart TD
    Internet(["Internet and Mobile Clients"]) -->|HTTPS and WSS| ACM["AWS Certificate Manager"]
    ACM --> ALB["Application Load Balancer"]
    
    subgraph VPC ["Custom VPC: 10.0.0.0/16"]
        subgraph Public_Subnets ["Public Subnets (AZ1 and AZ2)"]
            ALB
            NAT["NAT Gateway"]
            Coturn["Coturn TURN Server EC2"]
        end

        subgraph Private_App_Subnets ["Private App Subnets (AZ1 and AZ2)"]
            ASG["Auto Scaling Group - FastAPI Nodes"]
        end

        subgraph Private_DB_Subnets ["Private Data Subnets (AZ1 and AZ2)"]
            RDS[("Amazon RDS PostgreSQL")]
            ElastiCache[("Amazon ElastiCache Redis")]
        end
    end

    Secrets["AWS Secrets Manager"] -.->|Inject DB & JWT Keys| ASG
    ALB -->|HTTP and WS Port 8000| ASG
    ASG -->|Port 5432| RDS
    ASG -->|Port 6379| ElastiCache
    Internet <-->|UDP 3478 and 5349| Coturn
```

---

## 2. Step-by-Step Infrastructure Provisioning

### Step 1: Networking & VPC Setup
1. **Create VPC:**
   - Name: `langmatcher-vpc`
   - IPv4 CIDR Block: `10.0.0.0/16`
2. **Create Subnets:**
   - `public-subnet-1a` (`10.0.1.0/24`, `us-east-1a`)
   - `public-subnet-1b` (`10.0.2.0/24`, `us-east-1b`)
   - `private-app-1a` (`10.0.10.0/24`, `us-east-1a`)
   - `private-app-1b` (`10.0.20.0/24`, `us-east-1b`)
   - `private-db-1a` (`10.0.30.0/24`, `us-east-1a`)
   - `private-db-1b` (`10.0.40.0/24`, `us-east-1b`)
3. **Internet Gateway & NAT Gateway:**
   - Attach an Internet Gateway (`langmatcher-igw`) to the VPC.
   - Provision an Elastic IP and deploy a NAT Gateway (`langmatcher-nat`) in `public-subnet-1a`.
   - Route public subnets `0.0.0.0/0` $\to$ `langmatcher-igw`.
   - Route private subnets `0.0.0.0/0` $\to$ `langmatcher-nat`.

---

### Step 2: Security Groups Configuration

| Security Group | Inbound Rules | Outbound Rules |
| :--- | :--- | :--- |
| **`sg-alb`** | `TCP 80` (HTTP), `TCP 443` (HTTPS) from `0.0.0.0/0` | All traffic to `sg-backend` |
| **`sg-backend`** | `TCP 8000` (FastAPI) from `sg-alb` | `TCP 5432` to `sg-rds`, `TCP 6379` to `sg-redis`, `HTTPS 443` via NAT |
| **`sg-rds`** | `TCP 5432` (PostgreSQL) from `sg-backend` | None |
| **`sg-redis`** | `TCP 6379` from `sg-backend` | None |
| **`sg-coturn`** | `UDP/TCP 3478` (STUN/TURN), `UDP/TCP 5349` (TURNS), `UDP 49152-65535` (Relay Ports) from `0.0.0.0/0` | `0.0.0.0/0` |

---

### Step 3: Database & Caching Provisioning

1. **AWS RDS (PostgreSQL 15):**
   - DB Identifier: `langmatcher-db`
   - Subnet Group: `private-db-1a`, `private-db-1b`
   - Security Group: `sg-rds`
   - Storage: 20 GB gp3 (Autoscaling up to 100 GB)
   - Initial Database Name: `langmatcher`
2. **AWS ElastiCache (Redis 7.x) / Redis EC2:**
   - Provision Redis cluster or standalone node in `private-db` subnets with `sg-redis`.
3. **AWS Secrets Manager:**
   - Secret Name: `langmatcher/production/secrets`
   - Key-Value pairs:
     - `DATABASE_URL`: `postgresql://admin:SecretPassword@langmatcher-db.xxx.rds.amazonaws.com:5432/langmatcher`
     - `REDIS_URL`: `redis://langmatcher-redis.xxx.cache.amazonaws.com:6379/0`
     - `JWT_SECRET_KEY`: `<generated-secure-random-256-bit-key>`
     - `TURN_SECRET`: `<generated-coturn-shared-secret>`

---

### Step 4: Application Load Balancer (ALB) & SSL Setup

1. **Target Group (`tg-fastapi`):**
   - Protocol: `HTTP`, Port: `8000`
   - Health Check Path: `/api/v1/health`
   - Health Check Interval: 15 seconds, Threshold: 2 healthy
   - **Attributes:** Stickiness enabled (Duration: 1 day, Type: Load balancer generated cookie).
2. **Application Load Balancer (`alb-langmatcher`):**
   - Scheme: Internet-facing
   - Subnets: `public-subnet-1a`, `public-subnet-1b`
   - Security Group: `sg-alb`
3. **Listeners & Routing:**
   - **Port 80 Listener:** HTTP to HTTPS (Port 443) redirect rule.
   - **Port 443 Listener:** Default action $\to$ Forward to `tg-fastapi`.
   - Attach SSL Certificate from **AWS Certificate Manager (ACM)**.

---

### Step 5: EC2 Launch Template & Auto Scaling Group (ASG)

1. **IAM Role (`role-fastapi-backend`):**
   - Policies: `SecretsManagerReadWrite`, `CloudWatchAgentServerPolicy`, `AmazonEC2ContainerRegistryReadOnly`.
2. **Launch Template (`lt-langmatcher-backend`):**
   - AMI: Ubuntu Server 22.04 LTS (or Amazon Linux 2023)
   - Instance Type: `t3.micro` / `t3.small`
   - Security Group: `sg-backend`
   - IAM Instance Profile: `role-fastapi-backend`
   - **User Data Script (`user_data.sh`):**
     ```bash
     #!/bin/bash
     apt-get update -y
     apt-get install -y docker.io awscli jq
     systemctl start docker
     systemctl enable docker

     # Fetch Secrets from AWS Secrets Manager
     SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id langmatcher/production/secrets --query SecretString --output text --region us-east-1)
     export DATABASE_URL=$(echo $SECRET_JSON | jq -r .DATABASE_URL)
     export REDIS_URL=$(echo $SECRET_JSON | jq -r .REDIS_URL)
     export JWT_SECRET_KEY=$(echo $SECRET_JSON | jq -r .JWT_SECRET_KEY)

     # Pull and run container
     docker run -d --restart always \
       -p 8000:8000 \
       -e DATABASE_URL="$DATABASE_URL" \
       -e REDIS_URL="$REDIS_URL" \
       -e JWT_SECRET_KEY="$JWT_SECRET_KEY" \
       --name fastapi_app \
       your-docker-registry/langmatcher-backend:latest
     ```
3. **Auto Scaling Group (`asg-langmatcher`):**
   - Desired Capacity: 2
   - Minimum Capacity: 1
   - Maximum Capacity: 4
   - Target Group: `tg-fastapi`
   - Scaling Policy: Target Tracking (Average CPU Utilization at 70%).

---

### Step 6: Coturn TURN Server Deployment (EC2 in Public Subnet)

1. Launch a `t3.micro` Ubuntu instance in `public-subnet-1a` with `sg-coturn` and an Elastic IP (`EIP_COTURN`).
2. Install & Configure Coturn:
   ```bash
   sudo apt-get update && sudo apt-get install -y coturn
   ```
3. Edit `/etc/turnserver.conf`:
   ```ini
   listening-port=3478
   tls-listening-port=5349
   fingerprint
   lt-cred-mech
   use-auth-secret
   static-auth-secret=<YOUR_SHARED_TURN_SECRET>
   realm=turn.yourdomain.com
   external-ip=<EIP_COTURN>
   min-port=49152
   max-port=65535
   verbose
   ```
4. Enable service: `sudo systemctl restart coturn && sudo systemctl enable coturn`.

---

## 3. Verification & Troubleshooting Checklist

- [ ] **Health Check:** `curl -i https://api.yourdomain.com/api/v1/health` returns `HTTP 200 OK {"status": "healthy"}`.
- [ ] **WebSocket Handshake:** Test connection to `wss://api.yourdomain.com/ws/signaling/{user_id}` with valid JWT token.
- [ ] **Database Connectivity:** Verify Alembic migration executed successfully during initial deployment.
- [ ] **TURN Server Reachability:** Test with `trickle-ice` online tool with `turn:<EIP_COTURN>:3478`.
