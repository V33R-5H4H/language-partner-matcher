# 🏛️ Document 1: AWS Enterprise Architecture Proposal
## Multi-Tier Cloud Infrastructure for Language Partner Matcher
**Core Technologies:** AWS EC2 (Auto Scaling Group), Application Load Balancer (ALB), Amazon RDS (PostgreSQL), AWS Secrets Manager, Amazon ElastiCache (Redis), and Coturn TURN Relay.

---

## 1. Executive Summary & Architecture Overview

This architecture proposal details an enterprise-grade, highly available, fault-tolerant, and horizontally scalable cloud deployment on Amazon Web Services (AWS). It separates stateless application compute from stateful managed databases, utilizes automated load balancing with SSL termination, provisions dynamic auto-scaling based on CPU/memory load, and centralizes enterprise secret management.

```
                                    ┌────────────────────────────────────────────────────────┐
                                    │                   INTERNET CLIENTS                     │
                                    │              (Flutter Android & Web Apps)              │
                                    └───────────────┬────────────────────────▲───────────────┘
                                                    │                        │
                          ┌─────────────────────────┴─────────┐              │
                          │ HTTPS / WSS (Port 443/80)         │              │ WebRTC Media
                          │                                   │              │ (UDP 3478, 49152-65535)
                          ▼                                   │              │
             ┌─────────────────────────┐                      │              │
             │   AWS Certificate       │                      │              │
             │   Manager (ACM SSL)     │                      │              │
             └────────────┬────────────┘                      │              │
                          │                                   │              │
                          ▼                                   │              ▼
             ┌─────────────────────────┐                      │   ┌──────────────────────┐
             │   Application Load      │                      │   │  Coturn TURN Relay   │
             │   Balancer (ALB)        │                      │   │  (EC2 Public Subnet) │
             │  - HTTP/HTTPS Listener  │                      │   │  - Elastic IP        │
             │  - WSS WebSocket Proxy  │                      │   │  - Host Networking   │
             │  - Health Checks        │                      │   └──────────────────────┘
             └────────────┬────────────┘                      │
                          │                                   │
      ════════════════════╪═══════════════════════════════════╪════════════════════════════════
      VPC (10.0.0.0/16)   │                                   │
      ────────────────────┼───────────────────────────────────┼────────────────────────────────
      Private Subnets     ▼                                   │
      ┌───────────────────────────────────────────────────────┴───────────────────────────────┐
      │                        Auto Scaling Group (ASG) - Multi-AZ                            │
      │                                                                                       │
      │   ┌───────────────────────────────┐               ┌───────────────────────────────┐   │
      │   │  EC2 Instance (AZ 1 - Primary)│               │  EC2 Instance (AZ 2 - Replica)│   │
      │   │  ┌─────────────────────────┐  │               │  ┌─────────────────────────┐  │   │
      │   │  │ FastAPI Signaling App   │  │               │  │ FastAPI Signaling App   │  │   │
      │   │  │ Docker Container (8000) │  │               │  │ Docker Container (8000) │  │   │
      │   │  └────────────┬────────────┘  │               │  └────────────┬────────────┘  │   │
      │   └───────────────┼───────────────┘               └───────────────┼───────────────┘   │
      └───────────────────┼───────────────────────────────────────────────┼───────────────────┘
                          │                                               │
                          ├───────────────────────┬───────────────────────┤
                          │                       │                       │
                          ▼                       ▼                       ▼
              ┌──────────────────────┐ ┌────────────────────┐ ┌──────────────────────┐
              │ AWS Secrets Manager  │ │  Amazon RDS        │ │ Amazon ElastiCache   │
              │ - JWT_SECRET_KEY     │ │  PostgreSQL 15     │ │ Redis 7 Cluster      │
              │ - DB Credentials     │ │  (Multi-AZ)        │ │ - Matchmaking Radar  │
              │ - TURN Shared Secret │ │  - User Profiles   │ │ - WebSocket Pub/Sub  │
              │ - Auto-Rotation      │ │  - Direct Chats    │ │ - Active Sessions    │
              └──────────────────────┘ └────────────────────┘ └──────────────────────┘
```

---

## 2. Infrastructure Components & Specifications

### 2.1. Network Topology (VPC & Subnets)
- **VPC CIDR:** `10.0.0.0/16` across 2 Availability Zones (`ap-south-1a`, `ap-south-1b`).
- **Public Subnets (2x):**
  - `10.0.1.0/24` (AZ 1) & `10.0.2.0/24` (AZ 2)
  - Hosts the **Application Load Balancer (ALB)**, **NAT Gateways**, and **Coturn TURN Server**.
- **Private Subnets (2x App Layer):**
  - `10.0.10.0/24` & `10.0.20.0/24`
  - Hosts the **EC2 Auto Scaling Group (ASG)** running FastAPI instances.
- **Private Subnets (2x Data Layer):**
  - `10.0.30.0/24` & `10.0.40.0/24`
  - Hosts **Amazon RDS PostgreSQL** and **Amazon ElastiCache Redis**. No direct Internet routing.

---

### 2.2. Application Load Balancer (ALB)
The ALB serves as the single public entry point for all REST API and WebSocket connections.

1. **Listeners & Routing:**
   - **HTTP (Port 80):** Automatic redirect to HTTPS (Port 443).
   - **HTTPS (Port 443):** Terminates TLS using an AWS Certificate Manager (ACM) certificate.
2. **Target Group Configuration:**
   - **Protocol/Port:** HTTP / `8000`
   - **Target Type:** Instance (targets managed by ASG).
   - **Health Check Path:** `/health` (Interval: 15s, Timeout: 5s, Healthy Threshold: 2).
   - **Stickiness / WebSocket Support:** Native HTTP/1.1 Upgrade header support for `/ws/signaling/*` with target group stickiness enabled (duration: 1 day).

---

### 2.3. EC2 Auto Scaling Group (ASG) & Launch Template
The compute tier runs stateless FastAPI containers that auto-scale dynamically based on concurrent connections and CPU utilization.

1. **Launch Template Configuration:**
   - **AMI:** Ubuntu Server 22.04 LTS (x86_64 or ARM64 Graviton).
   - **Instance Type:** `t3.small` (or `t4g.small` for 20% better price/performance).
   - **IAM Instance Profile:** Attached role with `SecretsManagerReadWrite` and `CloudWatchLogsFullAccess`.
   - **Security Group (`sg_backend_ec2`):** Inbound allowed ONLY from `sg_alb` on port `8000`.
2. **Auto Scaling Policy:**
   - **Minimum Capacity:** 1 instance.
   - **Desired Capacity:** 2 instances (distributed across AZ 1 & AZ 2 for High Availability).
   - **Maximum Capacity:** 6 instances.
   - **Scaling Metric:** Target Tracking on Average CPU Utilization ($\ge 70\%$) or ALB Request Count Per Target ($\ge 1000\text{ req/min}$).

---

### 2.4. Amazon RDS (PostgreSQL 15)
Managed, stateful relational database for persistent user profiles, match ratings, and direct chat messages.

1. **Instance Configuration:**
   - **Engine:** PostgreSQL 15.5
   - **DB Instance Class:** `db.t4g.micro` (Dev/Test) or `db.t4g.small` (Production).
   - **Storage:** 20 GiB GP3 with storage autoscaling up to 100 GiB.
   - **Multi-AZ Deployment:** Enabled for zero-downtime automated failover.
   - **Security Group (`sg_rds`):** Inbound TCP `5432` allowed ONLY from `sg_backend_ec2`.

---

### 2.5. AWS Secrets Manager
Eliminates hardcoded passwords and `.env` files from source control and builds.

1. **Managed Secret:** `langmatcher/production/secrets`
2. **Stored Key-Value Pairs:**
   ```json
   {
     "DATABASE_URL": "postgresql+asyncpg://dbadmin:SECURE_PWD@langmatcher-rds.cluster.ap-south-1.rds.amazonaws.com:5432/langmatcher",
     "REDIS_URL": "redis://langmatcher-redis.cache.ap-south-1.amazonaws.com:6379/0",
     "JWT_SECRET_KEY": "a8f9c2d7e4b1...64_hex_string...",
     "TURN_DOMAIN": "turn.yourdomain.com",
     "TURN_SHARED_SECRET": "coturn_production_shared_secret_789xyz",
     "ENVIRONMENT": "production"
   }
   ```
3. **Retrieval Workflow:** During application startup (`app/core/config.py`), the backend makes an authenticated API call via AWS SDK (`boto3`) using the EC2 instance's IAM role, retrieving and decrypting secrets into memory without writing them to disk.

---

### 2.6. Coturn TURN Relay Placement & WebRTC Specialization
> [!IMPORTANT]
> **Why Coturn is separated from ALB:**
> ALBs only balance HTTP, HTTPS, gRPC, and WebSockets (TCP). WebRTC media transmission operates over high-speed, dynamic **UDP ranges (49152–65535)**. Therefore, Coturn runs on a dedicated EC2 instance in the **Public Subnet** with an **Elastic IP** and host networking, while the ASG backend generates ephemeral, HMAC-SHA1 authenticated TURN tokens for clients.

---

## 3. End-to-End Operational Workflow

1. **Client Connection:**
   - Flutter App connects to `https://api.yourdomain.com` $\rightarrow$ ALB terminates SSL $\rightarrow$ routes to an active EC2 instance in the ASG on port `8000`.
2. **WebSocket Signaling & Radar Matchmaking:**
   - Client establishes WebSocket connection `wss://api.yourdomain.com/ws/signaling/{user_id}`.
   - ALB upgrades protocol to WebSocket.
   - Because multiple ASG backend instances exist, **Amazon ElastiCache (Redis Pub/Sub)** synchronizes signaling messages and radar state across all backend instances seamlessly.
3. **WebRTC Media Negotiation:**
   - Backend queries AWS Secrets Manager for `TURN_SHARED_SECRET` and generates temporary credentials (`/api/v1/webrtc/ice-servers`).
   - Clients exchange SDP offers/answers over WebSocket and establish encrypted peer-to-peer or Coturn-relayed audio/video streams.
4. **Data Persistence:**
   - User profiles, chat history, and ratings are committed asynchronously to **Amazon RDS PostgreSQL Multi-AZ**.
5. **Auto-Scaling Action:**
   - If traffic spikes during peak evening hours, CloudWatch triggers ASG to spin up additional EC2 instances. New instances initialize, fetch secrets from Secrets Manager, join the target group, and begin serving traffic in under 60 seconds.
