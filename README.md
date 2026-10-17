# 🌐 Language Partner Matcher

> **A real-time, reciprocal language exchange platform with automated matchmaking, WebSocket signaling, and low-latency peer-to-peer WebRTC video/audio calls.**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.100+-009688?logo=fastapi)](https://fastapi.tiangolo.com)
[![Python](https://img.shields.io/badge/Python-3.11+-3776AB?logo=python)](https://python.org)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-4169E1?logo=postgresql)](https://www.postgresql.org)
[![Redis](https://img.shields.io/badge/Redis-7-DC382D?logo=redis)](https://redis.io)
[![WebRTC](https://img.shields.io/badge/WebRTC-Peer--to--Peer-333333?logo=webrtc)](https://webrtc.org)
[![Docker](https://img.shields.io/badge/Docker-Enabled-2496ED?logo=docker)](https://www.docker.com)
[![Web App](https://img.shields.io/badge/Live_Web_App-Browser_Access-brightgreen?logo=googlechrome)](http://13.235.12.217:8000/web/)

> 🚀 **Live Web Application**: **[Launch in Browser (Live AWS Server)](http://13.235.12.217:8000/web/)**  
> *(Runs directly in your browser — connected to the live AWS EC2 signaling backend)*

---

## 📌 Overview

**Language Partner Matcher** connects language learners across the world for reciprocal 1-on-1 language practice. A native English speaker learning Mandarin is paired with a native Mandarin speaker learning English, initiating a direct WebRTC peer-to-peer video conversation.

### Key Capabilities
- **Tandem Reciprocal Matchmaking**: Enforces strict bidirectional language pairing ($\text{My Native} = \text{Partner's Target} \land \text{My Target} = \text{Partner's Native}$) using in-memory or Redis-backed matchmaking queues.
- **Low-Latency Signaling**: Real-time bi-directional WebSocket signaling server for SDP offer/answer exchange and ICE candidate trickle.
- **Enterprise NAT & Firewall Traversal**: Dynamic ephemeral HMAC-SHA1 credentials generated for CoTURN (STUN/TURN/TURNS) servers to enable calls across symmetric cellular NATs (4G/5G).
- **Cross-Platform Client**: Built with Flutter for Android, Web (Chrome), iOS, and Desktop.
- **Decoupled Cloud Architecture**: Scalable production layout separating the Stateless App Server, AWS RDS PostgreSQL, Dedicated Redis EC2, and Standalone CoTURN Relay.

---

## 🏗️ System Architecture

```mermaid
graph TD
    subgraph Clients ["Clients (Flutter Cross-Platform)"]
        A1[Android App]
        A2[Web Browser]
        A3[Desktop / iOS]
    end

    subgraph AWS_Cloud ["AWS Cloud Infrastructure (ap-south-1)"]
        subgraph App_Server ["Stateless App Server (EC2)"]
            API[FastAPI REST API :8000]
            WS[WebSocket Signaling :8000]
        end

        subgraph Managed_Data ["Persistence Layer"]
            RDS[(AWS RDS PostgreSQL)]
            REDIS[(Dedicated Redis 7)]
        end

        subgraph Media_Relay ["TURN / STUN EC2"]
            COTURN[CoTURN Server :3478 / :5349]
        end
    end

    A1 -->|REST & JWT Auth| API
    A1 -->|WebSocket Handshake| WS
    A2 -->|REST & JWT Auth| API
    A2 -->|WebSocket Handshake| WS

    API -->|Async ORM Queries| RDS
    WS -->|Match Queues & Pub/Sub| REDIS
    API -->|HMAC-SHA1 Ephemeral Tokens| COTURN
    A1 <==>|Encrypted P2P WebRTC Audio/Video| A2
    A1 -.->|Relay Fallback via TURN| COTURN
    A2 -.->|Relay Fallback via TURN| COTURN
```

---

## 📂 Repository Structure

```
.
├── backend/                        # FastAPI Application & Signaling Server
│   ├── app/
│   │   ├── api/v1/                 # REST endpoints (auth, matchmaking, WebRTC)
│   │   ├── core/                   # Configuration, security, database session
│   │   ├── models/                 # SQLAlchemy ORM models (User, Match)
│   │   ├── schemas/                # Pydantic request/response validation
│   │   ├── services/               # Matchmaking engine & business logic
│   │   └── websocket/              # Signaling manager & real-time router
│   ├── coturn/                     # CoTURN Dockerfile and configuration
│   ├── deploy/                     # EC2 bootstrap & deployment scripts
│   ├── tests/                      # Pytest async test suite
│   ├── Dockerfile                  # Production container definition
│   ├── docker-compose.yml          # Local full-stack development orchestration
│   ├── docker-compose.decoupled.yml# EC2 production deployment compose
│   ├── .env.example                # Template for environment variables
│   └── requirements.txt            # Python dependencies
│
├── test1/                          # Flutter Client Application
│   ├── lib/
│   │   ├── core/                   # Themes, routing, constants (ApiEndpoints)
│   │   ├── data/                   # SQLite & SharedPreferences local storage
│   │   ├── models/                 # Dart domain models
│   │   ├── providers/              # State management (Provider pattern)
│   │   ├── services/               # WebRTC, WebSocket, Audio & Push notifications
│   │   └── views/                  # UI Screens (Login, Register, Radar, VideoCall)
│   └── pubspec.yaml                # Flutter dependencies
│
├── docs/                           # Architecture, AWS guides & documentation
└── .github/workflows/              # GitHub Actions CI/CD pipelines
```

---

## 🚀 Quick Start Guide

### 1. Prerequisites
- [Docker](https://www.docker.com/) & Docker Compose
- [Python 3.11+](https://www.python.org/)
- [Flutter 3.x](https://flutter.dev/) & Dart SDK

### 2. Local Backend Setup

1. **Navigate to the backend directory**:
   ```bash
   cd backend
   ```

2. **Configure your environment**:
   ```bash
   cp .env.example .env
   ```
   *(The default values in `.env` are pre-configured to work out-of-the-box with local Docker Compose)*.

3. **Start backend services (FastAPI + PostgreSQL + Redis)**:
   ```bash
   docker compose up --build
   ```

4. **Verify the server**:
   - Interactive Swagger API Documentation: [http://localhost:8000/docs](http://localhost:8000/docs)
   - Health Check: [http://localhost:8000/api/v1/health](http://localhost:8000/api/v1/health)

---

### 3. Running the Flutter App

Navigate to the `test1` directory:
```bash
cd test1
flutter pub get
```

#### Run in Web Browser (Chrome):
```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
```

#### Run on Android Emulator:
*(Note: Android emulators use `10.0.2.2` to access host `localhost`)*:
```bash
flutter run -d <emulator-id> --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

#### Run targeting Live AWS EC2 Backend:
```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://<YOUR_EC2_IP>:8000
```

---

## 🔒 Environment Variables & Secrets Reference

All secrets and sensitive infrastructure values must be placed in `backend/.env` (or configured via CI/CD secrets). **Never commit `.env` or private keys to source control.**

| Variable | Description | Example / Default |
|:---|:---|:---|
| `DATABASE_URL` | Async PostgreSQL connection string | `postgresql+asyncpg://user:pass@host:5432/db` |
| `REDIS_URL` | Redis cache and queue endpoint | `redis://redis_host:6379/0` |
| `JWT_SECRET_KEY` | Secret key for signing authentication tokens | *Generate via `openssl rand -hex 32`* |
| `TURN_DOMAIN` | Public domain or IP for WebRTC TURN relay | `turn.yourdomain.com` |
| `TURN_SERVER_IP` | Elastic IP of standalone CoTURN EC2 | `13.xxx.xxx.xxx` |
| `TURN_SHARED_SECRET`| Shared HMAC-SHA1 secret between backend and CoTURN | *Generate via `openssl rand -hex 32`* |
| `WEB_APP_URL` | *(Optional CI Secret)* Direct URL to the live web interface | `http://13.235.12.217:8000/web` |
| `EC2_HOST` | *(CI Secret for Auto-Deploy)* Public IP of your EC2 server | `13.235.12.217` |
| `EC2_SSH_PRIVATE_KEY` | *(CI Secret for Auto-Deploy)* Contents of your `.pem` key file | `-----BEGIN RSA PRIVATE KEY-----...` |

---

## 📦 Building for Production

### Android APK:
```bash
cd test1
flutter build apk --release --split-per-abi --dart-define=API_BASE_URL=https://api.yourdomain.com
```

### Flutter Web:
```bash
cd test1
flutter build web --release --dart-define=API_BASE_URL=https://api.yourdomain.com
```

---

## 📚 Documentation Center

Deep-dive architecture specifications and deployment guides are available in [`docs/`](file:///c:/V33R/Programming/College/Sem_7/Project/test1.0/docs/):
- **[System Design & Architecture](file:///c:/V33R/Programming/College/Sem_7/Project/test1.0/docs/system_design.md)**
- **[Decoupled AWS Production Guide](file:///c:/V33R/Programming/College/Sem_7/Project/test1.0/docs/aws_master_decoupled_setup_and_browser_access_guide.md)**
- **[Standalone CoTURN Setup Guide](file:///c:/V33R/Programming/College/Sem_7/Project/test1.0/docs/aws_coturn_standalone_setup_guide.md)**
- **[WebRTC Signaling Protocol Specification](file:///c:/V33R/Programming/College/Sem_7/Project/test1.0/docs/webrtc_signaling_protocol.md)**
- **[App Run & Build Command Matrix](file:///c:/V33R/Programming/College/Sem_7/Project/test1.0/docs/app_run_and_build_commands.md)**

---

## 🛡️ License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
