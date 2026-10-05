# System Design & Architecture (Iteration `test1.0`)

## 1. End-to-End System Architecture

The project is architected with a decoupled mobile frontend (`test1`), containerized Python backend (`backend`), and scalable AWS cloud infrastructure.

```mermaid
flowchart TD
    subgraph Mobile_App ["Flutter Mobile Client (test1)"]
        UI["UI Views & Widgets (Flutter)"]
        State["State Providers (Provider / ChangeNotifier)"]
        LocalDB[("Local SQLite (sqflite)")]
        MediaEngine["WebRTC Media Engine (flutter_webrtc)"]
        WSClient["WebSocket Signaling Client"]
        RESTClient["HTTP REST Client"]
        
        UI <--> State
        State <--> LocalDB
        State <--> MediaEngine
        State <--> WSClient
        State <--> RESTClient
    end

    subgraph AWS_Cloud ["AWS Cloud Infrastructure"]
        ALB["Application Load Balancer (ALB) - HTTPS / WSS"]
        
        subgraph Compute_ASG ["EC2 Auto Scaling Group"]
            FastAPI1["FastAPI Node 1 (REST + WebSockets)"]
            FastAPI2["FastAPI Node 2 (REST + WebSockets)"]
        end
        
        RedisState["Amazon ElastiCache / Redis (Pub/Sub & Queues)"]
        PostgresDB[("Amazon RDS (PostgreSQL 15)")]
        SecManager["AWS Secrets Manager"]
    end

    subgraph NAT_Traversal ["NAT / Firewall Traversal"]
        STUNServer["STUN Server (Google / Coturn)"]
        TURNServer["TURN Server (Coturn Relay)"]
    end

    %% Mobile to Backend Connections
    RESTClient -->|HTTPS (Port 443)| ALB
    WSClient -->|WSS (Port 443)| ALB
    ALB --> FastAPI1
    ALB --> FastAPI2

    %% Backend to Storage & Cache
    FastAPI1 <--> RedisState
    FastAPI2 <--> RedisState
    FastAPI1 --> PostgresDB
    FastAPI2 --> PostgresDB
    SecManager -.->|Runtime Injection| FastAPI1
    SecManager -.->|Runtime Injection| FastAPI2

    %% Media Stream
    MediaEngine <--> STUNServer
    MediaEngine <==>|Direct P2P Video/Audio & DataChannel| RemotePeer["Remote Matched Peer (Flutter)"]
    MediaEngine -.->|TURN Relay Fallback| TURNServer
    TURNServer -.->|TURN Relay Fallback| RemotePeer
```

---

## 2. Flutter Mobile Architecture (`test1`)

The mobile client follows the **Clean Layered / MVVM Architecture**:

```text
               ┌──────────────────────────────┐
               │    UI Layer (Views & Widgets)│
               └──────────────▲───────────────┘
                              │ Watches / Triggers
               ┌──────────────▼───────────────┐
               │ State Layer (Providers)      │
               │ (Auth, Match, WebRTC Call)   │
               └──────▲───────────────▲───────┘
                      │               │
       ┌──────────────▼─────┐   ┌─────▼──────────────┐
       │ Services Layer     │   │ Data Layer         │
       │ - WebRTCService    │   │ - SQLite Helper    │
       │ - WebSocketService │   │ - REST ApiClient   │
       │ - AudioService     │   │ - Repositories     │
       └────────────────────┘   └────────────────────┘
```

### Layer Responsibilities:
1. **UI Layer (`lib/views/`, `lib/widgets/`)**: Reactive, declarative Material 3 widgets for Authentication, Profile Management, Matchmaking Radar, Video Call Screen with Picture-in-Picture, and Call History.
2. **State Layer (`lib/providers/`)**: `ChangeNotifier` providers managing authentication tokens, active match queue status, call session states (incoming, connected, muted, video off), and local cache synchronization.
3. **Services Layer (`lib/services/`)**:
   - `WebRTCService`: Peer connection creation, local/remote media track assignment, STUN/TURN server configuration, ICE candidate exchange, and DataChannel management.
   - `WebSocketService`: Persistent socket connection to AWS ALB, automatic reconnection with exponential backoff, and JSON signaling parser.
4. **Data Layer (`lib/data/`)**:
   - `DatabaseHelper`: Local SQLite database operations (`sqflite`).
   - `ApiClient`: REST requests (`http`) with bearer token injection.
   - `Repositories`: Clean abstraction for caching user profile, saved vocabulary, and call history.

---

## 3. Complete Directory Structure

```text
test1.0/
│
├── docs/                                  # Master Project Documentation (Global Source of Truth)
│   ├── README.md                          # Master documentation index
│   ├── project_context.md                 # Academic scope & requirements
│   ├── system_design.md                   # Global architecture
│   ├── aws_implementation_step_by_step_guide.md # AWS deployment guide
│   ├── database_schema.md                 # PostgreSQL & SQLite schemas
│   ├── webrtc_signaling_protocol.md       # WebSocket signaling protocol
│   └── matchmaking_algorithm.md           # Matchmaking mathematical model
│
├── backend/                               # Python FastAPI Cloud Backend
│   ├── app/
│   │   ├── __init__.py
│   │   ├── main.py                        # FastAPI application entrypoint & middleware
│   │   ├── core/                          # Core configuration & security
│   │   │   ├── config.py                  # Environment variables & secrets loader
│   │   │   ├── security.py                # Password hashing & JWT creation/verification
│   │   │   └── database.py                # SQLAlchemy engine & session factory
│   │   ├── models/                        # SQLAlchemy ORM Models
│   │   │   ├── user.py                    # User model
│   │   │   ├── language.py                # Language model
│   │   │   ├── timezone.py                # Timezone & Availability model
│   │   │   └── call_session.py            # Call session log model
│   │   ├── schemas/                       # Pydantic validation schemas
│   │   │   ├── auth.py                    # Login/Register request & response schemas
│   │   │   ├── user.py                    # User profile schemas
│   │   │   └── match.py                   # Match queue schemas
│   │   ├── api/                           # REST API Endpoints
│   │   │   ├── v1/
│   │   │   │   ├── auth.py                # /api/v1/auth (login, register, me)
│   │   │   │   ├── users.py               # /api/v1/users (profile, availability)
│   │   │   │   ├── languages.py           # /api/v1/languages (supported languages)
│   │   │   │   └── match.py               # /api/v1/match (enqueue, cancel, status)
│   │   │   └── health.py                  # /api/v1/health (ALB health check)
│   │   ├── services/                      # Business & Matchmaking Logic
│   │   │   ├── matchmaking_service.py     # Redis queue management & Lua matching
│   │   │   └── redis_pubsub.py            # Multi-node message broadcaster
│   │   └── websocket/                     # Real-Time WebRTC Signaling
│   │       ├── signaling_manager.py       # Active socket connection registry
│   │       └── router.py                  # /ws/signaling/{user_id} endpoint
│   ├── alembic/                           # Database migration scripts
│   ├── Dockerfile                         # Production Docker container definition
│   ├── docker-compose.yml                 # Local dev stack (FastAPI + PostgreSQL + Redis)
│   └── requirements.txt                   # Python dependencies
│
└── test1/                                 # Flutter Mobile Client (Current Iteration)
    ├── docs/                              # Iteration 1 Documentation & Progress Tracker
    │   ├── README.md                      # Iteration 1 index
    │   ├── iteration_notes.md             # Sprint checklist & changelog
    │   ├── system_design.md               # Iteration-specific system design
    │   ├── project_context.md
    │   ├── aws_implementation_step_by_step_guide.md
    │   ├── database_schema.md
    │   ├── webrtc_signaling_protocol.md
    │   └── matchmaking_algorithm.md
    ├── android/                           # Android native platform project
    │   └── app/src/main/AndroidManifest.xml # Permissions (Camera, Mic, Audio, Internet)
    ├── ios/                               # iOS native platform project
    │   └── Runner/Info.plist              # Camera & Microphone usage descriptions
    ├── lib/                               # Flutter Dart Source Code
    │   ├── main.dart                      # App initialization & provider setup
    │   ├── core/                          # Core utilities, theme & constants
    │   │   ├── constants/
    │   │   │   ├── api_endpoints.py / .dart # REST & WebSocket URLs
    │   │   │   └── app_colors.dart        # Color palette & theme tokens
    │   │   ├── theme/
    │   │   │   └── app_theme.dart         # Material 3 light/dark themes
    │   │   └── utils/
    │   │       └── permissions.dart       # Camera & Mic permission handlers
    │   ├── data/                          # Data persistence & networking
    │   │   ├── local/
    │   │   │   ├── database_helper.dart   # SQLite database singleton
    │   │   │   └── local_storage.dart     # Shared preferences / secure storage
    │   │   ├── remote/
    │   │   │   └── api_client.dart        # HTTP REST client with JWT header
    │   │   └── repositories/
    │   │       ├── auth_repository.dart   # User login/register & cache sync
    │   │       ├── match_repository.dart  # Match queue API calls
    │   │       └── history_repository.dart # Local SQLite call history queries
    │   ├── models/                        # Dart Data Models
    │   │   ├── user_model.dart            # User profile data model
    │   │   ├── language_model.dart        # Language metadata model
    │   │   ├── match_model.dart           # Match result & peer data model
    │   │   └── session_model.dart         # Call session & vocabulary model
    │   ├── providers/                     # State Management (ChangeNotifiers)
    │   │   ├── auth_provider.dart         # Auth state, login status, user profile
    │   │   ├── match_provider.dart        # Active queue timer, partner found state
    │   │   └── call_provider.dart         # Active WebRTC call state, audio/video toggles
    │   ├── services/                      # Platform & Network Services
    │   │   ├── webrtc_service.dart        # RTCPeerConnection & RTCVideoRenderer engine
    │   │   └── websocket_service.dart     # WebSocket signaling client & event dispatcher
    │   ├── views/                         # Application Screens (UI)
    │   │   ├── auth/
    │   │   │   ├── login_screen.dart      # User login screen
    │   │   │   └── register_screen.dart   # Registration & language selection
    │   │   ├── home/
    │   │   │   ├── home_screen.dart       # Dashboard & navigation hub
    │   │   │   └── profile_tab.dart       # Target language & proficiency editor
    │   │   ├── match/
    │   │   │   ├── match_screen.dart      # Animated radar matchmaking search screen
    │   │   │   └── match_modal.dart       # Partner discovered prompt
    │   │   ├── call/
    │   │   │   ├── video_call_screen.dart # Fullscreen video call with PiP preview
    │   │   │   └── in_call_chat_sheet.dart# P2P DataChannel chat & conversation prompts
    │   │   └── history/
    │   │       └── call_history_screen.dart # Offline session logs & saved vocabulary
    │   └── widgets/                       # Reusable UI Widgets
    │       ├── video_render_box.dart      # WebRTC RTCVideoView wrapper
    │       ├── call_controls_bar.dart     # Mic, Camera, Flip, and End Call buttons
    │       └── language_badge.dart        # Language & proficiency indicator chip
    ├── pubspec.yaml                       # Flutter dependencies & assets
    └── README.md                          # Flutter project readme
```
