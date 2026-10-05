# Language Partner Matcher

> **Real-Time Cross-Platform Peer-to-Peer Language Exchange Platform**  
> *Developed as a Semester 7 Computer Science and Engineering Capstone Project.*

---

## 📖 Project Documentation

Complete architectural and technical specifications are available in the [`docs/`](file:///c:/V33R/Programming/College/Sem_7/Project/test1.0/test1/docs) directory:

1. [**Project Context & Motivation (`docs/project_context.md`)**](file:///c:/V33R/Programming/College/Sem_7/Project/test1.0/test1/docs/project_context.md) — Academic alignment, problem statement, and project goals.
2. [**System Design & Architecture (`docs/system_design.md`)**](file:///c:/V33R/Programming/College/Sem_7/Project/test1.0/test1/docs/system_design.md) — High-level architecture, WebRTC P2P flow, component architecture, and sequence diagrams.
3. [**AWS Implementation Step-by-Step Guide (`docs/aws_implementation_step_by_step_guide.md`)**](file:///c:/V33R/Programming/College/Sem_7/Project/test1.0/test1/docs/aws_implementation_step_by_step_guide.md) — Comprehensive guide for deploying ALB, ASG, RDS, Secrets Manager, and Coturn on AWS.
4. [**Database Schema (`docs/database_schema.md`)**](file:///c:/V33R/Programming/College/Sem_7/Project/test1.0/test1/docs/database_schema.md) — PostgreSQL cloud DDL and SQLite local mobile schema.
5. [**WebRTC Signaling & Protocol (`docs/webrtc_signaling_protocol.md`)**](file:///c:/V33R/Programming/College/Sem_7/Project/test1.0/test1/docs/webrtc_signaling_protocol.md) — WebSocket payload schemas, ICE candidate trickling, and DataChannel messaging.
6. [**Matchmaking Algorithm (`docs/matchmaking_algorithm.md`)**](file:///c:/V33R/Programming/College/Sem_7/Project/test1.0/test1/docs/matchmaking_algorithm.md) — Mathematical formula, dynamic time-decay window expansion, and Redis atomic queue matching.

---

## 🛠️ Tech Stack

*   **Mobile Frontend:** Flutter (Dart), `flutter_webrtc`, SQLite (`sqflite`), Provider/State Management.
*   **Backend & Signaling:** Python 3.11, FastAPI, WebSockets, Redis (Pub/Sub & Queues), SQLAlchemy, Alembic, Docker.
*   **Cloud Infrastructure (AWS):**
    *   **Compute:** EC2 Auto Scaling Group (ASG)
    *   **Traffic Routing:** Application Load Balancer (ALB) with WebSocket stickiness
    *   **Database:** Amazon RDS (PostgreSQL 15)
    *   **Secrets & Config:** AWS Secrets Manager
    *   **NAT Traversal:** Coturn (STUN/TURN Relay) on EC2

---

## 🚀 Getting Started

### Prerequisites
*   Flutter SDK (v3.13+)
*   Docker & Docker Compose
*   Python 3.11+
*   AWS CLI configured (for cloud deployments)

### Running Backend Locally
```bash
cd backend
docker-compose up --build
```
*   FastAPI Swagger UI: `http://localhost:8000/docs`
*   Health Check: `http://localhost:8000/api/v1/health`

### Running Mobile Client Locally
```bash
cd test1 # or mobile
flutter pub get
flutter run
```

---

## 📂 Project Directory Structure

```text
test1.0/
├── test1/                      # Project root / Mobile client
│   ├── docs/                   # Architectural & technical documentation
│   ├── lib/                    # Flutter application source code
│   │   ├── core/               # Constants, theme, network client
│   │   ├── data/               # SQLite helper, repositories, API services
│   │   ├── models/             # Data models & JSON serialization
│   │   ├── providers/          # State controllers
│   │   ├── services/           # WebRTC and WebSocket services
│   │   └── views/              # UI screens & components
│   ├── android/                # Android native project files & permissions
│   ├── ios/                    # iOS native configuration
│   └── pubspec.yaml            # Flutter dependencies
├── backend/                    # FastAPI backend (signaling + REST)
│   ├── app/                    # Application source code
│   ├── docker-compose.yml      # Local dev stack (FastAPI + PostgreSQL + Redis)
│   └── Dockerfile              # Production container image
```
