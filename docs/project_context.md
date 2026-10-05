# Project Context & Motivation

## 1. Academic Background & Capstone Scope
*   **Course / Curriculum:** Semester 7 — Computer Science and Engineering
*   **Domain:** Mobile Application Development, Distributed Systems, Real-Time Peer-to-Peer Multimedia, and Cloud Architecture
*   **Project Title:** **Language Partner Matcher**
*   **Core Concepts Applied:**
    *   Cross-platform reactive UI and state architecture using **Flutter** (Dart).
    *   Native device hardware control (Camera, Microphone, Audio Routing, Permissions) via platform channels and WebRTC bindings.
    *   Offline data persistence and local caching utilizing **SQLite** (`sqflite`).
    *   Asynchronous backend services, REST APIs, and stateful WebSockets using **Python (FastAPI)**.
    *   Real-time signaling and multi-instance orchestration using **Redis Pub/Sub**.
    *   Direct peer-to-peer low-latency audio/video communication via **WebRTC** (STUN/TURN NAT traversal).
    *   Cloud-native resilient infrastructure on **Amazon Web Services (AWS)** (ALB, EC2 Auto Scaling Group, RDS PostgreSQL, Secrets Manager).

---

## 2. Problem Statement
Language learners face significant hurdles in achieving conversational fluency:
1.  **High Cost & Inaccessibility:** 1-on-1 private tutoring with native speakers is expensive and inaccessible for many students and global learners.
2.  **Asynchronous / Text Limitations:** Chat-based apps (text/voice notes) do not simulate real-time conversational pressure, spontaneous speech processing, pronunciation correction, or body language cues.
3.  **Scheduling & Timezone Friction:** Manually finding language exchange partners across disparate timezones with matching skill levels is cumbersome.
4.  **Media Streaming Scalability Bottlenecks:** Centralized media streaming servers (SFUs/MCUs) introduce excessive bandwidth bills, high latency, and centralized single points of failure for large-scale video calls.

---

## 3. Project Objectives & Key Deliverables

1.  **Automated Real-Time Matchmaking:**
    *   Pair users mutually based on complementary learning goals (User A speaks Native Language X and wants to learn Y; User B speaks Native Language Y and wants to learn X).
    *   Incorporate proficiency-matching scores and timezone availability bitmasks to maximize compatibility.
2.  **Zero-Relay Direct P2P Video/Audio Streaming (WebRTC):**
    *   Offload media streams directly between peers, reducing backend compute and bandwidth footprint by >90%.
    *   Implement Coturn/STUN/TURN NAT traversal to reliably connect peers across mobile and restricted networks.
3.  **Real-Time In-Call Collaboration (Data Channels):**
    *   Enable bidirectional peer-to-peer text chat, live topic prompts, and vocabulary notes directly over WebRTC DataChannels with zero database/server load.
4.  **Offline-First Mobile Experience:**
    *   Cache user profile, practice session history, and saved vocabulary locally in SQLite for instant startup and offline review.
5.  **Enterprise-Grade AWS Cloud Infrastructure:**
    *   Deploy backend services in an Auto Scaling Group behind an Application Load Balancer with WebSocket stickiness, connected to a resilient RDS PostgreSQL database.