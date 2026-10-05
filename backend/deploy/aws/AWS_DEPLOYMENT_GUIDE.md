# 🚀 Comprehensive AWS Deployment & Real-Time WebRTC Testing Guide

This guide provides step-by-step instructions to deploy the **Language Partner Matcher** backend and **Coturn TURN Relay Server** onto an **AWS EC2** instance, and connect your Flutter app (Android APK & Web) to test live, real-time video & voice calls across real networks (4G/5G mobile carriers and home Wi-Fi).

---

## 1. Why Cloud Deployment is Essential for WebRTC

In local development (`localhost` / `10.0.2.2`), devices share the same virtual network. However, in the real world:
- **Symmetric NATs & Carrier Firewalls:** Mobile carriers (4G/5G) and enterprise routers block direct peer-to-peer (P2P) UDP connections.
- **Coturn TURN Relay:** Acts as an intermediate media relay server with a public IP so audio and video packets can flow between devices even when direct P2P is blocked.
- **Central Signaling:** The FastAPI WebSocket signaling server orchestrates match discovery, call ringing, SDP offers/answers, and ICE candidate exchange.

```
                    ┌─────────────────────────────────────────┐
                    │               AWS EC2                   │
                    │   ┌─────────────────────────────────┐   │
                    │   │  FastAPI Backend (Port 8000)    │   │
                    │   │  - Auth & Profile Management    │   │
                    │   │  - WebSocket Signaling Server   │   │
                    │   │  - Dynamic TURN Token Generator │   │
                    │   └────────────────┬────────────────┘   │
                    │                    │                    │
                    │   ┌────────────────┴────────────────┐   │
                    │   │  Coturn TURN Server (Port 3478) │   │
                    │   │  - UDP/TCP Media Relay Server   │   │
                    │   │  - Ports 49152 - 65535          │   │
                    │   └─────────────────────────────────┘   │
                    └────────────────────▲────────────────────┘
                                         │
                    ┌────────────────────┴────────────────────┐
                    │                                         │
                    ▼                                         ▼
         📱 Android Phone (4G/5G)                  💻 Laptop / Web (Wi-Fi)
```

---

## 2. Prerequisites

1. An active **[AWS Account](https://aws.amazon.com)** (Free Tier eligible).
2. An SSH Key Pair (`.pem` file) created in the AWS EC2 Console.
3. SSH Client (built into Windows PowerShell, macOS Terminal, and Linux).

---

## 3. Step-by-Step EC2 Instance Setup

### Step 3.1: Launch the EC2 Instance
1. Open the **[AWS EC2 Management Console](https://console.aws.amazon.com/ec2/)**.
2. Click **Launch Instance** (orange button).
3. Configure the settings:
   - **Name:** `langmatcher-cloud-server`
   - **Application and OS Images:** **Ubuntu Server 22.04 LTS (HVM)** or **Ubuntu Server 24.04 LTS**.
   - **Architecture:** `64-bit (x86)`
   - **Instance Type:**
     - `t3.small` (2 vCPU, 2 GB RAM — **Recommended** for running FastAPI + Redis + Postgres + Coturn, ~\$0.02/hr).
     - Or `t2.micro` / `t3.micro` (AWS Free Tier eligible).
   - **Key pair (login):** Select an existing key pair or click **Create new key pair** (e.g. `langmatcher-key.pem`).
   - **Storage:** 20 GiB gp3 (General Purpose SSD).

---

### Step 3.2: Configure the Security Group (Firewall Rules)
Under **Network Settings**, click **Edit** and configure the **Inbound Security Group Rules**:

| Type | Protocol | Port Range | Source | Description |
| :--- | :--- | :--- | :--- | :--- |
| **SSH** | TCP | `22` | `0.0.0.0/0` (or My IP) | Remote terminal access |
| **Custom TCP** | TCP | `8000` | `0.0.0.0/0` | FastAPI REST API & WebSocket Signaling |
| **Custom TCP** | TCP | `3478` | `0.0.0.0/0` | Coturn STUN/TURN (TCP) |
| **Custom UDP** | UDP | `3478` | `0.0.0.0/0` | Coturn STUN/TURN (UDP) |
| **Custom UDP** | UDP | `49152 - 65535` | `0.0.0.0/0` | WebRTC Media Relay UDP Port Range |

> [!IMPORTANT]
> The **UDP 49152 - 65535** range is mandatory for Coturn to relay video and audio streams when direct peer-to-peer connection is restricted by cellular firewalls.

4. Click **Launch Instance**.

---

### Step 3.3: (Optional but Recommended) Assign an Elastic IP
1. In the EC2 sidebar, go to **Network & Security** $\rightarrow$ **Elastic IPs**.
2. Click **Allocate Elastic IP address** $\rightarrow$ **Allocate**.
3. Select the new Elastic IP $\rightarrow$ **Actions** $\rightarrow$ **Associate Elastic IP address**.
4. Choose your `langmatcher-cloud-server` instance and click **Associate**.
5. Note down your public IP address (e.g. `13.233.100.200`).

---

## 4. Deploying the Backend on AWS

### Step 4.1: Connect to Your EC2 Instance via SSH
Open your terminal (PowerShell on Windows) and run:
```powershell
# Set key permissions (if on Linux/macOS run: chmod 400 your-key.pem)
ssh -i "path/to/your-key.pem" ubuntu@YOUR_EC2_PUBLIC_IP
```

---

### Step 4.2: Clone Repository & Run One-Click Deployment
Once connected inside the EC2 instance:

```bash
# 1. Clone your project repository
git clone https://github.com/your-username/your-repo-name.git
cd your-repo-name/backend

# 2. Make the deployment script executable
chmod +x deploy/aws/deploy.sh

# 3. Run the automated deployment script
./deploy/aws/deploy.sh
```

#### What this script does automatically:
1. Installs **Docker Engine** & **Docker Compose**.
2. Automatically detects your instance's **Public IP**.
3. Generates secure random credentials in `.env.prod` (`JWT_SECRET_KEY`, `TURN_SHARED_SECRET`, `POSTGRES_PASSWORD`).
4. Builds and launches all 4 production containers:
   - `langmatcher_backend_prod` (FastAPI on port 8000)
   - `langmatcher_postgres_prod` (PostgreSQL 15)
   - `langmatcher_redis_prod` (Redis 7)
   - `langmatcher_coturn_prod` (Coturn TURN Server with host networking)

---

### Step 4.3: Verify Deployment Health

1. Check running containers:
   ```bash
   sudo docker compose -f docker-compose.prod.yml ps
   ```
   All services (`fastapi_backend`, `postgres_db`, `redis_cache`, `coturn_turn`) should show **Up** or **healthy**.

2. Test the API Swagger Docs from your web browser:
   Open in your browser:
   ```
   http://YOUR_EC2_PUBLIC_IP:8000/docs
   ```
   You should see the interactive FastAPI Swagger documentation.

3. Verify dynamic TURN ICE server token generation:
   Open:
   ```
   http://YOUR_EC2_PUBLIC_IP:8000/api/v1/webrtc/ice-servers
   ```
   It should return a JSON response containing STUN and TURN server credentials:
   ```json
   {
     "ice_servers": [
       {"urls": "stun:YOUR_EC2_PUBLIC_IP:3478"},
       {
         "urls": "turn:YOUR_EC2_PUBLIC_IP:3478?transport=udp",
         "username": "1728148800:guest",
         "credential": "..."
       }
     ]
   }
   ```

---

## 5. Connecting the Flutter Frontend to AWS

### Option 1: Run Web Client from Laptop
Open a terminal in `test1/` and launch Chrome pointing to your AWS instance:
```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://YOUR_EC2_PUBLIC_IP:8000
```

---

### Option 2: Build and Install Android APK on Real Phones
To test real-time calling on physical Android phones connected to 4G/5G:

1. **Build Release APK**:
   ```powershell
   flutter build apk --release --dart-define=API_BASE_URL=http://YOUR_EC2_PUBLIC_IP:8000
   ```
   The built APK will be located at:
   `test1/build/app/outputs/flutter-apk/app-release.apk`

2. **Install on Android Device**:
   - Connect your phone via USB with USB Debugging enabled:
     ```powershell
     flutter install
     ```
   - Or transfer `app-release.apk` via Google Drive / WhatsApp / direct USB transfer and tap to install.

---

## 6. Real-Time End-to-End Test Procedure

```
[Device A: Android Phone on 4G Mobile Data]          [Device B: Laptop Chrome on Home Wi-Fi]
                      │                                                │
                      ├─── 1. Register Account A (English -> Spanish) ─┤
                      ├─── 2. Register Account B (Spanish -> English) ─┤
                      │                                                │
                      ├─── 3. Tap "Find Partner" on both devices ─────┤
                      │                                                │
                      ├────────── 4. Matched via AWS WebSocket ────────┤
                      │                                                │
                      ├─── 5. Audio & Video Call Connected (TURN) ─────┤
                      ├─── 6. Send in-call chat message & reaction ────┤
                      └─── 7. Hang up and verify call record in History┤
```

1. **Device A (Android Phone)**:
   - Disconnect from Wi-Fi (use **Mobile 4G/5G**).
   - Open the app, register as `User_Alex` (Native: English, Learning: Spanish).
   - Go to Practice tab and tap **Find Partner** (Radar starts pulsing).

2. **Device B (Chrome / Second Phone)**:
   - Connect on Wi-Fi.
   - Open the app, register as `User_Maria` (Native: Spanish, Learning: English).
   - Go to Practice tab and tap **Find Partner**.

3. **Validation Points**:
   - ✅ **Instant Radar Discovery:** User avatars appear on the stardust radar within 1–2 seconds.
   - ✅ **Handshake:** Tap on the avatar $\rightarrow$ Incoming call dialog rings on the partner device.
   - ✅ **Two-Way Video/Audio:** Tap **Accept** $\rightarrow$ WebRTC stream establishes via AWS TURN server within ~1 second.
   - ✅ **In-Call Chat:** Tap the chat button during the call $\rightarrow$ send a message $\rightarrow$ verify message delivery indicator (`#00E676`) and unread badge.
   - ✅ **Call Teardown:** Tap the red end-call button $\rightarrow$ both devices cleanly disconnect and save session to Call History.

---

## 7. Troubleshooting & Useful Commands

### Check Backend Logs on AWS
```bash
# View live logs from all containers
sudo docker compose -f docker-compose.prod.yml logs -f

# View only FastAPI backend logs
sudo docker compose -f docker-compose.prod.yml logs -f fastapi_backend

# View Coturn media relay logs
sudo docker compose -f docker-compose.prod.yml logs -f coturn_turn
```

### Restart Backend Services
```bash
sudo docker compose -f docker-compose.prod.yml restart
```

### Stop Instance When Not in Use (Cost Optimization)
When you finish testing for the day, you can stop your EC2 instance from the AWS Console (**Instance State** $\rightarrow$ **Stop Instance**) to avoid incurring unnecessary compute charges. Start it again whenever you want to test!
