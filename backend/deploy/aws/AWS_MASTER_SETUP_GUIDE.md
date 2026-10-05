# 🚀 Master AWS Setup & Real-Time WebRTC Testing Guide
## Complete Walkthrough for Mumbai (`ap-south-1`) Deployment

This guide provides the exact commands and step-by-step instructions to connect to your newly created AWS EC2 instance (**`13.235.12.217`**), launch the backend & Coturn TURN relay server, and test live two-way video calls on Web and real Android phones.

---

## 1. Quick Info & Architecture Summary

| Component | Target URL / Port | Role |
| :--- | :--- | :--- |
| **EC2 Public IP** | `13.235.12.217` | AWS Compute Instance (Mumbai `ap-south-1`) |
| **REST API & Swagger Docs** | `http://13.235.12.217:8000/docs` | FastAPI Authentication & Matchmaking |
| **WebSocket Signaling** | `ws://13.235.12.217:8000/ws` | Real-time Radar & Call Handshake |
| **Coturn TURN Relay** | `turn:13.235.12.217:3478` (UDP) | WebRTC Media Relay (4G/5G Cellular NAT Traversal) |
| **TURN Port Range** | `UDP 49152 - 65535` | High-throughput video/audio data stream |

---

## 2. Step 1: Connect to Your AWS EC2 Instance

### A. Fix Private Key Permissions on Windows (Run Once in PowerShell):
```powershell
$KEY_PATH = "C:\V33R\Programming\College\Sem_7\Project\language-partner-matcher\langmatcher-key.pem"

icacls $KEY_PATH /reset
icacls $KEY_PATH /grant:r "$($env:USERNAME):(R)"
icacls $KEY_PATH /inheritance:r
```

### B. SSH into the Instance:
```powershell
ssh -i "C:\V33R\Programming\College\Sem_7\Project\language-partner-matcher\langmatcher-key.pem" ubuntu@13.235.12.217
```

---

## 3. Step 2: Deploy Backend & Coturn on AWS (1-Click Command)

Once connected inside your Ubuntu terminal, run:

```bash
# 1. Clone your project repository
git clone https://github.com/YOUR_GITHUB_USERNAME/YOUR_REPO_NAME.git
cd YOUR_REPO_NAME/backend

# 2. Make the automated deployment script executable
chmod +x deploy/aws/deploy.sh

# 3. Run the deployment script
./deploy/aws/deploy.sh
```

### What happens automatically:
1. Docker & Docker Compose are installed.
2. The server detects public IP `13.235.12.217`.
3. Auto-generates secure random secrets in `.env.prod`.
4. Starts all 4 production containers:
   - `langmatcher_backend_prod` (FastAPI on port `8000`)
   - `langmatcher_postgres_prod` (PostgreSQL 15)
   - `langmatcher_redis_prod` (Redis 7)
   - `langmatcher_coturn_prod` (Coturn TURN Server with host networking on UDP `3478` & `49152-65535`)

---

## 4. Step 3: Verify the Live Cloud Backend

Open these URLs in your web browser:

1. **Interactive Swagger Documentation:**
   ```
   http://13.235.12.217:8000/docs
   ```
2. **Dynamic WebRTC ICE Servers Endpoint:**
   ```
   http://13.235.12.217:8000/api/v1/webrtc/ice-servers
   ```
   *(Should return STUN and TURN server credentials formatted with dynamic HMAC-SHA1 tokens).*

---

## 5. Step 4: Run the Flutter Frontend Against AWS

### Option A: Run Web Client from Laptop (Chrome)
In your local project folder (`test1` or `frontend`), run:
```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://13.235.12.217:8000
```

---

### Option B: Build & Install Android Release APK on Real Phones
1. **Build Release APK**:
   ```powershell
   flutter build apk --release --dart-define=API_BASE_URL=http://13.235.12.217:8000
   ```
2. **Locate the APK file**:
   ```
   build\app\outputs\flutter-apk\app-release.apk
   ```
3. **Install on Your Phone**:
   - Transfer `app-release.apk` to your Android phone via Google Drive, WhatsApp, or USB.
   - Tap the file to install (allow "Install from Unknown Sources").

---

## 6. Step 5: Test Real-Time Cross-Network Video Calling

```
[ Device 1: Physical Phone on 4G/5G ]               [ Device 2: Laptop Chrome on Wi-Fi ]
                  │                                                  │
                  ├───── 1. Register Account A (e.g. English) ───────┤
                  ├───── 2. Register Account B (e.g. Spanish) ───────┤
                  │                                                  │
                  ├───── 3. Tap "Find Partner" on both devices ──────┤
                  │                                                  │
                  ├────────── 4. Matched via AWS WebSocket ──────────┤
                  │                                                  │
                  ├───── 5. Two-Way WebRTC Video & Audio (TURN) ─────┤
                  ├───── 6. Send live in-call chat message ──────────┤
                  └───── 7. Tap End Call (Saved to History) ─────────┘
```

1. **Device 1 (Phone on Mobile Data)**:
   - Turn off Wi-Fi (use **Mobile 4G/5G**).
   - Register user: `Alex` (Native: English, Learning: Spanish).
   - Tap **Find Partner** $\rightarrow$ radar starts pulsing.
2. **Device 2 (Laptop Chrome or second phone on Wi-Fi)**:
   - Register user: `Maria` (Native: Spanish, Learning: English).
   - Tap **Find Partner**.
3. **Instant Discovery:** `Alex` and `Maria` will appear on each other's radar.
4. **Call Handshake:** Tap partner's avatar $\rightarrow$ incoming call dialog rings $\rightarrow$ tap **Accept**.
5. **Live WebRTC:** Crystal-clear video & audio stream connects through your AWS Mumbai TURN server within ~1 second.

---

## 7. Useful Server Management Commands (Inside EC2)

```bash
# View live logs from all containers
sudo docker compose -f docker-compose.prod.yml logs -f

# View only FastAPI backend logs
sudo docker compose -f docker-compose.prod.yml logs -f fastapi_backend

# View Coturn media relay logs
sudo docker compose -f docker-compose.prod.yml logs -f coturn_turn

# Restart all services
sudo docker compose -f docker-compose.prod.yml restart

# Stop all containers
sudo docker compose -f docker-compose.prod.yml down
```

---

## 8. Cost Management (AWS Free Tier / Cost Saving)

When you are done testing for the day:
1. Open the **[AWS EC2 Console](https://console.aws.amazon.com/ec2/)**.
2. Select your `13.235.12.217` instance.
3. Click **Instance State** $\rightarrow$ **Stop Instance**.
4. When you are ready to test again, click **Start Instance** (note: if you did not assign an Elastic IP, the public IP will refresh upon restart).
