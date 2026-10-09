# AWS Decoupled Architecture, GitHub Releases CI/CD & Remote Browser Access Guide
**Language Partner Matcher — Production Deployment & Operations Manual**

---

## Table of Contents
1. [Current Context & Architecture Transition](#1-current-context--architecture-transition)
2. [Step-by-Step AWS Setup Guide (Every Console Click & Command)](#2-step-by-step-aws-setup-guide)
   - [Phase 1: VPC Security Groups (The Security Glue)](#phase-1-vpc-security-groups)
   - [Phase 2: Service 1 — AWS RDS PostgreSQL (Managed Database)](#phase-2-service-1--aws-rds-postgresql)
   - [Phase 3: Service 2 — AWS ElastiCache / Redis (Matchmaking State)](#phase-3-service-2--aws-elasticache--redis)
   - [Phase 4: Service 3 — Standalone CoTURN Server (WebRTC Media Relay)](#phase-4-service-3--standalone-coturn-server)
   - [Phase 5: Service 4 — EC2 App Server (Stateless FastAPI)](#phase-5-service-4--ec2-app-server)
3. [Future Steps & Scaling Roadmap](#3-future-steps--scaling-roadmap)
   - [Custom Domain & DNS (Route 53)](#custom-domain--dns-route-53)
   - [Free SSL/TLS (ACM & Let's Encrypt)](#free-ssltls-acm--lets-encrypt)
   - [Application Load Balancer (ALB) with Sticky WebSockets](#application-load-balancer-alb)
   - [Auto Scaling & CloudWatch Monitoring](#auto-scaling--cloudwatch-monitoring)
4. [GitHub Actions CI/CD: Routing APKs Directly to GitHub Releases](#4-github-actions-cicd-routing-apks-directly-to-github-releases)
   - [How Releases Work Now](#how-releases-work-now)
   - [Workflow Files Overview](#workflow-files-overview)
5. [How to Access the App Remotely in a Browser (4 Methods)](#5-how-to-access-the-app-remotely-in-a-browser-4-methods)
   - [Method 1: Flutter Web (Native Browser App)](#method-1-flutter-web-native-browser-app)
   - [Method 2: Appetize.io (Run Android APK in Browser)](#method-2-appetizeio-run-android-apk-in-browser)
   - [Method 3: BrowserStack / Sauce Labs Real Device Cloud](#method-3-browserstack--sauce-labs-real-device-cloud)
   - [Method 4: Web-Based Screen Mirroring (ws-scrcpy)](#method-4-web-based-screen-mirroring-ws-scrcpy)

---

## 1. Current Context & Architecture Transition

### Project Status:
- **AWS Region**: `ap-south-1` (Mumbai)
- **Current App Server**: EC2 IP `13.235.12.217:8000` (Ubuntu)
- **Git Branch**: `main` tracking `origin/main`
- **Frontend**: Flutter (Android + Web support enabled)
- **Backend**: FastAPI + Async SQLAlchemy + WebSockets

### The Architectural Shift:
```
           OLD MONOLITH (Single EC2)               NEW DECOUPLED ARCHITECTURE (4 Services)
      +--------------------------------+      +------------------+     +------------------+
      |  EC2 (13.235.12.217)           |      |  EC2 App Server  |     |  CoTURN Server   |
      |  - FastAPI (Port 8000)         |      |  (Stateless API) |     |  (Standalone EC2)|
      |  - SQLite file on disk         |  --> |  13.235.12.217   |     |  Elastic IP      |
      |  - In-memory Python queue      |      +--------+---------+     +------------------+
      |  - CoTURN container (choking)  |               |        \
      +--------------------------------+               |         \
                                           Port 5432   |          | Port 6379
                                                       v          v
                                              +-------------+  +---------------+
                                              |   AWS RDS   |  |  ElastiCache  |
                                              | PostgreSQL  |  |     Redis     |
                                              +-------------+  +---------------+
```

---

## 2. Step-by-Step AWS Setup Guide

### Phase 1: VPC Security Groups

To ensure maximum security, **RDS and Redis must NEVER be accessible from the public internet**. Only your App Server security group will have permission to query them.

#### 1. Open AWS Console:
Go to **AWS Console** $\to$ select Region **Asia Pacific (Mumbai) `ap-south-1`** $\to$ Search **EC2** $\to$ **Security Groups** $\to$ **Create security group**.

#### 2. Create `langmatcher-app-sg` (App Server):
- **Name**: `langmatcher-app-sg`
- **Description**: FastAPI REST API and WebSocket signaling
- **VPC**: Default VPC
- **Inbound rules**:
  | Type | Protocol | Port range | Source | Description |
  |---|---|---|---|---|
  | Custom TCP | TCP | `8000` | `0.0.0.0/0` | FastAPI direct port |
  | HTTP | TCP | `80` | `0.0.0.0/0` | Web HTTP traffic / Certbot |
  | HTTPS | TCP | `443` | `0.0.0.0/0` | Secure SSL API traffic |
  | SSH | TCP | `22` | `My IP` | Secure terminal access |
- Click **Create security group**. Note its Group ID (e.g., `sg-01111111111111111`).

#### 3. Create `langmatcher-rds-sg` (PostgreSQL Database):
- **Name**: `langmatcher-rds-sg`
- **Description**: Private PostgreSQL access for app server
- **VPC**: Default VPC
- **Inbound rules**:
  | Type | Protocol | Port range | Source | Description |
  |---|---|---|---|---|
  | PostgreSQL | TCP | `5432` | `sg-01111111111111111` (`langmatcher-app-sg`) | Only App Server |
- Click **Create security group**.

#### 4. Create `langmatcher-redis-sg` (Redis Store):
- **Name**: `langmatcher-redis-sg`
- **Description**: Private Redis cache for matchmaking queue
- **VPC**: Default VPC
- **Inbound rules**:
  | Type | Protocol | Port range | Source | Description |
  |---|---|---|---|---|
  | Custom TCP | TCP | `6379` | `sg-01111111111111111` (`langmatcher-app-sg`) | Only App Server |
- Click **Create security group**.

#### 5. Create `langmatcher-coturn-sg` (WebRTC Media Relay):
- **Name**: `langmatcher-coturn-sg`
- **Description**: CoTURN STUN/TURN media relay
- **VPC**: Default VPC
- **Inbound rules**:
  | Type | Protocol | Port range | Source | Description |
  |---|---|---|---|---|
  | Custom UDP | UDP | `3478` | `0.0.0.0/0` | STUN/TURN UDP |
  | Custom TCP | TCP | `3478` | `0.0.0.0/0` | TURN TCP fallback |
  | Custom TCP | TCP | `5349` | `0.0.0.0/0` | TURNS (TLS) |
  | Custom UDP | UDP | `49152 - 65535` | `0.0.0.0/0` | WebRTC Media Relay ports |
  | SSH | TCP | `22` | `My IP` | Administration |
- Click **Create security group**.

---

### Phase 2: Service 1 — AWS RDS PostgreSQL

1. In AWS Console, search for **RDS** $\to$ click **Create database**.
2. **Choose a database creation method**: *Standard create*.
3. **Engine options**: *PostgreSQL*.
   - Version: `PostgreSQL 15.7-R1` or latest `16.x`.
4. **Templates**: Select **Free tier** (this configures a single DB instance with 20 GB gp3 storage).
5. **Settings**:
   - **DB instance identifier**: `langmatcher-db`
   - **Master username**: `postgres`
   - **Master password**: Enter a secure password (e.g. `LangMatcherSecure2026!`). Record this for your `.env`.
6. **Instance configuration**:
   - DB instance class: `db.t3.micro` or `db.t4g.micro` (Free tier eligible).
7. **Storage**:
   - Storage type: `gp3`.
   - Allocated storage: `20 GiB`.
   - Uncheck *Enable storage autoscaling* to avoid unexpected charges during dev.
8. **Connectivity**:
   - Virtual private cloud (VPC): *Default VPC*.
   - Public access: **No** *(PostgreSQL remains private)*.
   - VPC security group (firewall): Choose **Select existing** $\to$ select **`langmatcher-rds-sg`** $\to$ remove `default`.
9. **Additional configuration**:
   - Initial database name: `langmatcher`.
   - Enable automated backups: Check (7 days retention).
10. Click **Create database**.
11. Wait ~5–10 minutes until status becomes **Available**.
12. Click `langmatcher-db` $\to$ copy the **Endpoint**:
    - Example: `langmatcher-db.xxxxxxxxx.ap-south-1.rds.amazonaws.com`
    - Port: `5432`.

---

### Phase 3: Service 2 — AWS ElastiCache / Redis

#### Option A: AWS Managed ElastiCache (Zero maintenance)
1. In AWS Console, search for **ElastiCache** $\to$ **Redis clusters** $\to$ **Create Redis cluster**.
2. **Cluster mode**: *Disabled*.
3. **Cluster settings**:
   - Name: `langmatcher-redis`
   - Node type: `cache.t3.micro` or `cache.t4g.micro`
   - Replicas per shard: `0` (Standalone for cost saving)
4. **Connectivity**:
   - Subnet group: Default
   - Selected security groups: Select **`langmatcher-redis-sg`**
5. Click **Create**.
6. Once status is *Available*, copy the **Primary Endpoint**:
   - Example: `langmatcher-redis.xxxxxx.0001.aps1.cache.amazonaws.com:6379`.

#### Option B: Budget Alternative (Dedicated Redis Instance)
If you wish to avoid ElastiCache's ~$14/month during early testing:
Launch an EC2 `t4g.nano` or `t3.micro` with Ubuntu, attach `langmatcher-redis-sg`, and run:
```bash
sudo apt update && sudo apt install -y redis-server
sudo sed -i 's/bind 127.0.0.1 ::1/bind 0.0.0.0/' /etc/redis/redis.conf
sudo systemctl restart redis-server
```
Its Private IP will serve as your Redis host.

---

### Phase 4: Service 3 — Standalone CoTURN Server

1. **Launch CoTURN EC2 Instance**:
   - EC2 Console $\to$ **Launch instances**.
   - Name: `langmatcher-coturn`.
   - AMI: **Ubuntu 22.04 LTS**.
   - Instance type: `t3.micro`.
   - Key pair: Select your existing `.pem` key.
   - Network settings: Select **`langmatcher-coturn-sg`**.
   - Click **Launch instance**.
2. **Allocate Elastic IP**:
   - EC2 $\to$ **Elastic IPs** $\to$ **Allocate Elastic IP**.
   - Select the allocated IP $\to$ Actions $\to$ **Associate Elastic IP** $\to$ pick `langmatcher-coturn`.
   - Record this Elastic IP: e.g., `13.235.100.50`.
3. **Configure CoTURN**:
   SSH into the CoTURN server:
   ```bash
   ssh -i your-key.pem ubuntu@13.235.100.50
   ```
   Install and configure:
   ```bash
   sudo apt update && sudo apt install -y coturn

   # Enable daemon
   sudo sed -i 's/#TURNSERVER_ENABLED=1/TURNSERVER_ENABLED=1/' /etc/default/coturn

   # Generate strong secret
   openssl rand -hex 32
   # Example: a8f4b23c91d8e47f2019485720194857a8f4b23c91d8e47f2019485720194857
   ```
   Write configuration to `/etc/turnserver.conf`:
   ```bash
   sudo bash -c 'cat > /etc/turnserver.conf << EOF
   listening-port=3478
   tls-listening-port=5349
   fingerprint
   lt-cred-mech
   use-auth-secret
   static-auth-secret=a8f4b23c91d8e47f2019485720194857a8f4b23c91d8e47f2019485720194857
   realm=langmatcher.com
   external-ip=13.235.100.50
   min-port=49152
   max-port=65535
   verbose
   no-cli
   no-tls
   EOF'
   ```
   Restart service:
   ```bash
   sudo systemctl restart coturn
   sudo systemctl enable coturn
   sudo systemctl status coturn
   ```

---

### Phase 5: Service 4 — EC2 App Server (Stateless FastAPI)

1. Attach **`langmatcher-app-sg`** to your existing App Server instance (`13.235.12.217`) in AWS Console (EC2 $\to$ Instances $\to$ Actions $\to$ Security $\to$ Change security groups).
2. SSH into your App Server:
   ```bash
   ssh -i your-key.pem ubuntu@13.235.12.217
   ```
3. Update `/home/ubuntu/app/backend/.env`:
   ```ini
   PROJECT_NAME="Language Partner Matcher"
   API_V1_STR="/api/v1"
   ENVIRONMENT="production"
   JWT_SECRET_KEY="your_production_secret_key"
   ALGORITHM="HS256"
   ACCESS_TOKEN_EXPIRE_MINUTES=10080

   # 1. Connected to AWS RDS PostgreSQL
   DATABASE_URL="postgresql+asyncpg://postgres:LangMatcherSecure2026!@langmatcher-db.xxxxxxxxx.ap-south-1.rds.amazonaws.com:5432/langmatcher"

   # 2. Connected to ElastiCache / Redis
   REDIS_URL="redis://langmatcher-redis.xxxxxx.0001.aps1.cache.amazonaws.com:6379/0"

   # 3. Connected to Standalone CoTURN
   TURN_SERVER_IP="13.235.100.50"
   TURN_DOMAIN="13.235.100.50"
   TURN_SHARED_SECRET="a8f4b23c91d8e47f2019485720194857a8f4b23c91d8e47f2019485720194857"
   ```
4. Verify connections from EC2:
   ```bash
   # Test RDS
   nc -zv langmatcher-db.xxxxxxxxx.ap-south-1.rds.amazonaws.com 5432
   # Test Redis
   nc -zv langmatcher-redis.xxxxxx.0001.aps1.cache.amazonaws.com 6379
   ```
5. Start backend using `docker-compose.decoupled.yml` or systemd:
   ```bash
   cd /home/ubuntu/app/backend
   docker compose -f docker-compose.decoupled.yml up -d --build
   ```
6. Check health check endpoint:
   ```bash
   curl http://localhost:8000/api/v1/health
   # Returns: {"status": "healthy"}
   ```

---

## 3. Future Steps & Scaling Roadmap

### Custom Domain & DNS (Route 53)
1. Purchase domain or create Hosted Zone in **Route 53** (e.g. `langmatcher.com`).
2. Add DNS Records:
   - `api.langmatcher.com` $\to$ `A` record pointing to App Server Elastic IP (`13.235.12.217`) or ALB.
   - `turn.langmatcher.com` $\to$ `A` record pointing to CoTURN Elastic IP (`13.235.100.50`).

### Free SSL/TLS (ACM & Let's Encrypt)
- **If using ALB**: Request a free SSL certificate in **AWS Certificate Manager (ACM)** for `*.langmatcher.com` with 1-click DNS validation.
- **If using Nginx directly**: Run Certbot:
  ```bash
  sudo apt install -y certbot python3-certbot-nginx
  sudo certbot --nginx -d api.langmatcher.com
  ```

### Application Load Balancer (ALB)
- Deploy an AWS Application Load Balancer in public subnets.
- Forward HTTP (`80`) $\to$ HTTPS (`443`).
- **Target Groups**:
  - `/api/*` $\to$ Port 8000 (Round Robin)
  - `/ws/*` $\to$ Port 8000 (Enable **Sticky Sessions** for persistent WebSockets)

### Auto Scaling & CloudWatch Monitoring
- Create an AMI of your stateless EC2 App Server.
- Create an Auto Scaling Group (min: 1, max: 4 instances).
- Set CloudWatch Alarm: Trigger scale-out when CPU exceeds 70% for 3 minutes.

---

## 4. GitHub Actions CI/CD: Routing APKs Directly to GitHub Releases

We have fully upgraded `.github/workflows/flutter-build.yml` and `.github/workflows/backend-deploy.yml`.

### How Releases Work Now:
1. **Pushing code to `main`**:
   - Analyzes Flutter code (`dart format`, `flutter analyze`).
   - Builds **Split-per-ABI APKs** (`arm64-v8a`, `armeabi-v7a`, `x86_64`) AND the **Universal APK** (`app-release.apk`).
   - Automatically publishes or updates the **`latest` Continuous Release** under the GitHub repository's **Releases** tab.
   - Compiles **Flutter Web** assets for remote browser execution.
2. **Pushing a Version Tag** (e.g., `git tag v1.0.0 && git push origin v1.0.0`):
   - Automatically creates an official versioned **GitHub Release `v1.0.0`** with changelog notes and direct APK download links.
3. **Manual Trigger (`workflow_dispatch`)**:
   - You can trigger builds and releases on demand from the **Actions** tab in GitHub at any time.

---

## 5. How to Access the App Remotely in a Browser (4 Methods)

If you or a client/reviewer wants to access the app in a web browser without having an Android device, here are the 4 practical methods:

---

### Method 1: Flutter Web (Native Browser App) ⭐ [Recommended]
Flutter can compile the entire application to HTML, CSS, JavaScript, and WebAssembly. Modern WebRTC and WebSockets work natively in desktop and mobile browsers!

#### How to Build Locally:
```bash
cd test1
flutter build web --release \
  --dart-define=API_BASE_URL="http://13.235.12.217:8000" \
  --dart-define=WS_BASE_URL="ws://13.235.12.217:8000"
```
The output is generated in `test1/build/web/`.

#### How to Host & Access It:
- **Option A: Serve directly from your EC2 Backend**
  FastAPI can mount the `build/web` static directory:
  ```python
  from fastapi.staticfiles import StaticFiles
  app.mount("/web", StaticFiles(directory="web_build", html=True), name="web")
  ```
  Users simply open: `http://13.235.12.217:8000/web` in any browser!
- **Option B: GitHub Pages (100% Free)**
  Your updated CI/CD workflow already builds the web artifact (`flutter-web-build`). You can activate GitHub Pages under **Repository Settings $\to$ Pages** to host it at `https://v33r-5h4h.github.io/language-partner-matcher/`.

---

### Method 2: Appetize.io (Run the Real Android APK in Browser) ⭐ [Instant & Zero Code]
Appetize.io is an online streaming simulator for Android apps. It runs the real APK inside an interactive phone iframe directly in your browser tab.

#### Step-by-Step:
1. Go to your GitHub repository $\to$ **Releases** tab.
2. Download `app-release.apk` (Universal) or `app-arm64-v8a-release.apk`.
3. Go to **[Appetize.io/upload](https://appetize.io/upload)**.
4. Drag & drop the `.apk` file.
5. Appetize generates a private interactive URL (e.g., `https://appetize.io/app/xxxxxx`).
6. Open the link: You will see a virtual Android phone on your screen. You can click buttons, type text, turn on your laptop camera/microphone for video calls, and test the app as if holding a real phone!

---

### Method 3: BrowserStack Real Device Cloud (Professional Multi-Device QA)
If you need to test the APK across different physical devices (Samsung Galaxy, Google Pixel, OnePlus):
1. Sign up on **[BrowserStack App Live](https://www.browserstack.com/app-live)**.
2. Upload `app-release.apk`.
3. Choose any real Android device from the browser dashboard.
4. BrowserStack streams the real device screen into your browser with touch, camera, and microphone input support.

---

### Method 4: Web-Based Screen Mirroring (`ws-scrcpy` / Browser VNC)
If you have an Android device or local emulator running on your development PC and want to share remote access through a web browser:
1. Install `ws-scrcpy`:
   ```bash
   npm install -g ws-scrcpy
   ws-scrcpy
   ```
2. Open `http://localhost:8000` in Chrome.
3. You get full control of the Android device inside the browser tab with ultra-low latency WebRTC streaming.
