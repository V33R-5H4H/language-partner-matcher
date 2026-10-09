# AWS Separate Services Implementation Guide
**Language Partner Matcher — Production Decoupled Architecture**

> **Objective**: Migrate from a single monolithic instance running everything (FastAPI, SQLite, in-memory queues, and CoTURN) into a clean, modular architecture where each service runs independently on AWS with private VPC communication, managed backups, and optimal performance.

---

## Table of Contents
1. [Target Architecture Overview](#1-target-architecture-overview)
2. [Step 1: VPC & Security Group Rules (Networking Foundation)](#2-step-1-vpc--security-group-rules)
3. [Step 2: Service 1 — AWS RDS PostgreSQL (Managed Database)](#3-step-2-service-1--aws-rds-postgresql)
4. [Step 3: Service 2 — AWS ElastiCache Redis (Matchmaking & State)](#4-step-3-service-2--aws-elasticache-redis)
5. [Step 4: Service 3 — Standalone CoTURN Server (WebRTC Media Relay)](#5-step-4-service-3--standalone-coturn-server)
6. [Step 5: Service 4 — EC2 App Server (FastAPI + Uvicorn)](#6-step-5-service-4--ec2-app-server)
7. [Step 6: Code & Environment Implementation (Connecting the New Structure)](#7-step-6-code--environment-implementation)
8. [Step 7: Verification & Testing Checklist](#8-step-7-verification--testing-checklist)
9. [Troubleshooting & Common Pitfalls](#9-troubleshooting--common-pitfalls)

---

## 1. Target Architecture Overview

```
                          [ Internet / Mobile Clients ]
                                  |            \
       REST API & WebSocket       |             \  WebRTC Media Relay
       (Port 8000 / 443)          |              \ (UDP 3478 / 49152-65535)
                                  v               v
                     +-----------------------+  +-----------------------+
                     |    EC2 App Server     |  |    CoTURN Server      |
                     |   (FastAPI+Uvicorn)   |  |   (Standalone EC2)    |
                     |    13.235.12.217      |  |  Elastic IP (Public)  |
                     +-----------------------+  +-----------------------+
                                 |            |
                    Port 5432    |            |  Port 6379
                   (PostgreSQL)  |            |  (Redis)
                                 v            v
         +-----------------------------+  +-----------------------------+
         |     AWS RDS PostgreSQL      |  |    AWS ElastiCache Redis    |
         |  - User profiles & auth     |  |  - Waiting queue            |
         |  - Languages & timezones    |  |  - Radar active users       |
         |  - Chat history / sessions  |  |  - Distributed Pub/Sub      |
         |    [PRIVATE - No Internet]  |  |    [PRIVATE - No Internet]  |
         +-----------------------------+  +-----------------------------+
```

### Why Decouple Into 4 Separate Services?
| Component | Old Monolithic Approach | New Separated Service | Benefit |
|---|---|---|---|
| **Database** | SQLite local file or Docker container on EC2 disk | **AWS RDS PostgreSQL** | Automated daily backups, zero data loss on server reboot, transactional integrity, connection pooling. |
| **State / Queue** | Python `dict` in memory inside one Uvicorn worker | **AWS ElastiCache / Redis** | State survives backend restarts; enables horizontal scaling of multiple backend workers or instances. |
| **Media Relay** | CoTURN running in Docker on same EC2 host | **Dedicated CoTURN EC2 Instance** | Audio/video packet relay requires heavy UDP bandwidth and thousands of ports. Separating it prevents media streaming from choking API traffic. |
| **Application** | Monolith hosting everything on 1 instance | **Stateless EC2 App Server** | Lightweight, easy to restart, update, or replace at any time without risking user data. |

---

## 2. Step 1: VPC & Security Group Rules

All services reside in the same AWS Region: **`ap-south-1` (Mumbai)** inside the **Default VPC**.

To keep the database and cache completely secure, **only the App Server is allowed to connect to RDS and Redis**.

### Create 4 Dedicated Security Groups in AWS Console
*(AWS Console $\to$ EC2 $\to$ Network & Security $\to$ Security Groups $\to$ Create Security Group)*

#### 1. `langmatcher-app-sg` (FastAPI App Server)
- **Description**: Security group for FastAPI REST and WebSocket app server
- **Inbound Rules**:
  | Type | Protocol | Port Range | Source | Purpose |
  |---|---|---|---|---|
  | Custom TCP | TCP | `8000` | `0.0.0.0/0` | FastAPI direct HTTP/WS port |
  | HTTP | TCP | `80` | `0.0.0.0/0` | Nginx web proxy / certbot |
  | HTTPS | TCP | `443` | `0.0.0.0/0` | Secure SSL API traffic |
  | SSH | TCP | `22` | `My IP` | Secure terminal administration |
- **Outbound Rules**: All traffic (`0.0.0.0/0`)

#### 2. `langmatcher-rds-sg` (PostgreSQL Database)
- **Description**: Access to PostgreSQL strictly from App Server
- **Inbound Rules**:
  | Type | Protocol | Port Range | Source | Purpose |
  |---|---|---|---|---|
  | PostgreSQL | TCP | `5432` | `langmatcher-app-sg` (Security Group ID) | Allows only the App Server |
- **Outbound Rules**: Default

> [!IMPORTANT]
> When configuring the RDS security group rule, type `sg-` in the Source field and select `langmatcher-app-sg`. Do **NOT** use `0.0.0.0/0`.

#### 3. `langmatcher-redis-sg` (ElastiCache Redis)
- **Description**: Access to Redis strictly from App Server
- **Inbound Rules**:
  | Type | Protocol | Port Range | Source | Purpose |
  |---|---|---|---|---|
  | Custom TCP | TCP | `6379` | `langmatcher-app-sg` (Security Group ID) | Allows only the App Server |
- **Outbound Rules**: Default

#### 4. `langmatcher-coturn-sg` (WebRTC Media Relay)
- **Description**: Public WebRTC STUN/TURN traffic
- **Inbound Rules**:
  | Type | Protocol | Port Range | Source | Purpose |
  |---|---|---|---|---|
  | Custom UDP | UDP | `3478` | `0.0.0.0/0` | STUN/TURN signaling |
  | Custom TCP | TCP | `3478` | `0.0.0.0/0` | TURN TCP fallback |
  | Custom TCP | TCP | `5349` | `0.0.0.0/0` | TURNS (TLS) signaling |
  | Custom UDP | UDP | `49152 - 65535` | `0.0.0.0/0` | WebRTC audio/video relay traffic |
  | SSH | TCP | `22` | `My IP` | Server administration |
- **Outbound Rules**: All traffic (`0.0.0.0/0`)

---

## 3. Step 2: Service 1 — AWS RDS PostgreSQL

### Provision via AWS Console
1. Navigate to **RDS** $\to$ **Databases** $\to$ **Create database**.
2. **Database creation method**: *Standard create*.
3. **Engine options**: *PostgreSQL* (Version: `15.x` or `16.x`).
4. **Templates**: Choose **Free tier** (gives `db.t3.micro` or `db.t4g.micro`, 20 GB Storage).
5. **Settings**:
   - DB instance identifier: `langmatcher-db`
   - Master username: `postgres`
   - Master password: `<GenerateAStrongPassword>` (save this for `.env`)
6. **Instance configuration**:
   - DB instance class: `db.t3.micro` (or `db.t4g.micro`)
7. **Storage**:
   - Storage type: `gp3`
   - Allocated storage: `20` GiB
   - Disable storage autoscaling for dev/testing.
8. **Connectivity**:
   - Virtual private cloud (VPC): *Default VPC*
   - Public access: **No** (keeps database protected in private network)
   - Existing VPC security groups: Select **`langmatcher-rds-sg`** (remove `default`)
9. **Additional configuration**:
   - Initial database name: `langmatcher`
10. Click **Create database**.

### Record the Endpoint
Once the status changes from *Creating* to **Available** (typically 5–8 minutes):
- Click on `langmatcher-db`.
- Copy the **Endpoint**: e.g., `langmatcher-db.c123456789.ap-south-1.rds.amazonaws.com`.
- Port: `5432`.

---

## 4. Step 3: Service 2 — AWS ElastiCache Redis

You have two choices for Redis depending on your budget:

### Option A: AWS Managed ElastiCache (Recommended for Production)
1. Navigate to **ElastiCache** $\to$ **Redis clusters** $\to$ **Create Redis cluster**.
2. **Deployment option**: *Cluster mode disabled* (simple single-node).
3. **Node type**: `cache.t3.micro` or `cache.t4g.micro`.
4. **Number of replicas**: `0` (standalone node for development/cost control).
5. **Subnet group**: Default VPC subnets.
6. **Security groups**: Select **`langmatcher-redis-sg`**.
7. Once created, copy the **Primary Endpoint**: e.g., `langmatcher-redis.xxxxxx.0001.aps1.cache.amazonaws.com:6379`.

### Option B: Budget Alternative (Dedicated Micro-Instance)
If you want to save ElastiCache's ~$14/month fee during testing, run a dedicated Redis server on a low-cost `t4g.nano` or `t3.micro` instance:
```bash
sudo apt update && sudo apt install -y redis-server
sudo sed -i 's/bind 127.0.0.1 ::1/bind 0.0.0.0/' /etc/redis/redis.conf
sudo systemctl restart redis-server
```
Attach `langmatcher-redis-sg` to it.

---

## 5. Step 4: Service 3 — Standalone CoTURN Server

WebRTC connections between two phones on cellular 4G/5G or restrictive Wi-Fi (Symmetric NAT) cannot connect peer-to-peer directly; they require a TURN relay server.

### 1. Launch Instance
1. Launch an EC2 instance:
   - Name: `langmatcher-coturn`
   - AMI: Ubuntu 22.04 LTS
   - Instance type: `t3.micro`
   - Security Group: **`langmatcher-coturn-sg`**
2. In EC2 $\to$ **Elastic IPs** $\to$ **Allocate Elastic IP** $\to$ Associate it with the `langmatcher-coturn` instance.
3. Record the Elastic IP: e.g., `13.235.50.100`.

### 2. Install & Configure CoTURN
SSH into the CoTURN server:
```bash
sudo apt update && sudo apt install -y coturn

# Enable coturn daemon
sudo sed -i 's/#TURNSERVER_ENABLED=1/TURNSERVER_ENABLED=1/' /etc/default/coturn

# Generate a strong shared secret
openssl rand -hex 32
# Example output: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
```

Write the configuration to `/etc/turnserver.conf`:
```bash
sudo bash -c 'cat > /etc/turnserver.conf << EOF
listening-port=3478
tls-listening-port=5349
fingerprint
lt-cred-mech
use-auth-secret
static-auth-secret=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
realm=langmatcher.com
external-ip=YOUR_COTURN_ELASTIC_IP
min-port=49152
max-port=65535
verbose
no-cli
no-tls
EOF'
```
*(Replace `YOUR_COTURN_ELASTIC_IP` with the Elastic IP allocated in step 1)*.

Restart CoTURN:
```bash
sudo systemctl restart coturn
sudo systemctl status coturn
```

---

## 6. Step 5: Service 4 — EC2 App Server (FastAPI)

Attach **`langmatcher-app-sg`** to your existing App Server instance (`13.235.12.217`).

Because database and media handling are offloaded, the app server only needs Python dependencies:

```bash
sudo apt update && sudo apt install -y python3-pip python3-venv libpq-dev netcat

cd /home/ubuntu/app/backend
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
pip install asyncpg psycopg2-binary redis
```

---

## 7. Step 6: Code & Environment Implementation

### 1. Update `backend/.env`
On your App Server, edit `/home/ubuntu/app/backend/.env`:

```ini
# Application Settings
PROJECT_NAME="Language Partner Matcher"
API_V1_STR="/api/v1"
ENVIRONMENT="production"
JWT_SECRET_KEY="your_secure_random_jwt_key_here"
ALGORITHM="HS256"
ACCESS_TOKEN_EXPIRE_MINUTES=10080

# -------------------------------------------------------------
# 1. AWS RDS PostgreSQL Database Endpoint
# -------------------------------------------------------------
DATABASE_URL="postgresql+asyncpg://postgres:YOUR_RDS_PASSWORD@langmatcher-db.xxxxxx.ap-south-1.rds.amazonaws.com:5432/langmatcher"

# -------------------------------------------------------------
# 2. AWS ElastiCache / Redis Endpoint
# -------------------------------------------------------------
REDIS_URL="redis://langmatcher-redis.xxxxxx.0001.aps1.cache.amazonaws.com:6379/0"

# -------------------------------------------------------------
# 3. Standalone CoTURN Server Credentials
# -------------------------------------------------------------
TURN_SERVER_IP="YOUR_COTURN_ELASTIC_IP"
TURN_DOMAIN="YOUR_COTURN_ELASTIC_IP"
TURN_SHARED_SECRET="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
```

---

### 2. How the Backend Connects to RDS
In [`backend/app/core/database.py`](file:///c:/V33R/Programming/College/Sem_7/Project/test1.0/backend/app/core/database.py), the engine already uses `settings.DATABASE_URL` with asyncpg:

```python
engine = create_async_engine(
    settings.DATABASE_URL,
    echo=False,
    future=True,
    pool_size=20,
    max_overflow=10,
    pool_pre_ping=True,      # Automatically reconnects if RDS idle connection drops
    pool_recycle=1800,       # Recycles connections every 30 minutes
)
```

When you start FastAPI, the `init_db()` lifecycle function automatically provisions the tables on your RDS instance:
- `users`
- `languages` (seeds English, Spanish, French, German, Japanese, Mandarin, Hindi)
- `timezones` (seeds UTC offsets)
- `sessions` / `match_history`

---

### 3. How the Backend Generates Ephemeral TURN Credentials for Flutter
Your backend generates time-limited HMAC credentials so the Flutter app can authenticate with the standalone CoTURN server without hardcoding static secrets:

```python
import hmac
import hashlib
import time
from app.core.config import settings

def get_turn_credentials(username: str):
    # Valid for 24 hours
    timestamp = int(time.time()) + 86400
    temp_username = f"{timestamp}:{username}"
    
    dig = hmac.new(
        settings.TURN_SHARED_SECRET.encode(),
        temp_username.encode(),
        hashlib.sha1
    ).digest()
    
    import base64
    password = base64.b64encode(dig).decode()
    
    return {
        "iceServers": [
            {"urls": f"stun:{settings.TURN_SERVER_IP}:3478"},
            {
                "urls": [
                    f"turn:{settings.TURN_SERVER_IP}:3478?transport=udp",
                    f"turn:{settings.TURN_SERVER_IP}:3478?transport=tcp",
                ],
                "username": temp_username,
                "credential": password,
            }
        ]
    }
```

The Flutter app queries this endpoint upon login and passes the credentials into `WebRTCService.initialize()`.

---

### 4. Running the App Server via Systemd
To keep FastAPI running permanently in the background without Docker overhead:

Create `/etc/systemd/system/langmatcher.service`:
```ini
[Unit]
Description=FastAPI Language Partner Matcher
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu/app/backend
EnvironmentFile=/home/ubuntu/app/backend/.env
ExecStart=/home/ubuntu/app/backend/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 1
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable langmatcher
sudo systemctl restart langmatcher
```

---

## 8. Step 7: Verification & Testing Checklist

Perform these tests directly from your App Server (`13.235.12.217`):

### 1. Test Connection to RDS PostgreSQL
```bash
nc -zv <YOUR_RDS_ENDPOINT> 5432
```
Expected output:
```text
Connection to langmatcher-db.xxxxxx.ap-south-1.rds.amazonaws.com 5432 port [tcp/postgresql] succeeded!
```

### 2. Test Connection to Redis
```bash
nc -zv <YOUR_REDIS_ENDPOINT> 6379
```
Expected output:
```text
Connection to langmatcher-redis.xxxxxx.ap-south-1.cache.amazonaws.com 6379 port [tcp/redis] succeeded!
```

### 3. Verify Health Endpoint
```bash
curl http://localhost:8000/api/v1/health
```
Expected output:
```json
{"status": "healthy"}
```

### 4. Test CoTURN Server from Client Device
Open the [WebRTC Trickle ICE Tester](https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/) in a browser:
1. Under **STUN or TURN URI**, enter:
   `turn:<YOUR_COTURN_ELASTIC_IP>:3478?transport=udp`
2. Enter the username and password generated by your backend or static test secret.
3. Click **Add Server** $\to$ **Gather candidates**.
4. You should see candidates with Component `rtp` and Type **`relay`**. This proves that firewall traversal and audio/video relaying work.

---

## 9. Troubleshooting & Common Pitfalls

| Symptom | Probable Cause | Fix |
|---|---|---|
| `asyncpg.exceptions.ConnectionDoesNotExistError` | `DATABASE_URL` driver is missing or wrong format. | Ensure the prefix is `postgresql+asyncpg://` and not `postgresql://`. |
| `Connection timed out` connecting to RDS on port 5432 | Security Group rule is missing or incorrect. | Edit `langmatcher-rds-sg` inbound rules. Ensure Type is `PostgreSQL`, Port is `5432`, and Source is set to `langmatcher-app-sg` ID. |
| CoTURN gives `401 Unauthorized` | Shared secret mismatch. | Verify `TURN_SHARED_SECRET` in `backend/.env` exactly matches `static-auth-secret` in `/etc/turnserver.conf`. |
| Calls stuck on "Connecting..." on 4G/LTE | CoTURN `external-ip` missing or UDP port range blocked. | Check that `external-ip` is set to the Elastic IP in `/etc/turnserver.conf`, and that UDP ports `49152-65535` are open in `langmatcher-coturn-sg`. |
| Redis connection refused | Redis bound to `127.0.0.1` only. | If using self-hosted Redis, ensure `bind 0.0.0.0` is configured in `/etc/redis/redis.conf`. |
