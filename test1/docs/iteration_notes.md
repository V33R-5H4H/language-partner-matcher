# Iteration `test1` Implementation Notes & Milestone Tracker

## 📌 Iteration Overview
- **Name:** Iteration 1.0 (`test1`)
- **Focus:** Flutter Client Foundation, SQLite Local Caching, WebRTC Media Bindings, and FastAPI Signaling Integration.
- **Global Blueprint:** Refer to root [`/docs/README.md`](file:///c:/V33R/Programming/College/Sem_7/Project/test1.0/docs/README.md) for overarching system design.

---

## 🚀 Iteration 1 Milestone Checklist

### 1. Flutter Client (`test1`) Setup
- [ ] Add required dependencies to `pubspec.yaml` (`flutter_webrtc`, `sqflite`, `path_provider`, `provider`, `http`, `web_socket_channel`, `permission_handler`).
- [ ] Configure Android permissions in `android/app/src/main/AndroidManifest.xml` (Camera, Mic, Audio).
- [ ] Create core theme, constants, and routing structure.

### 2. Local Persistence (SQLite)
- [ ] Implement `DatabaseHelper` for local SQLite database initialization.
- [ ] Implement `LocalProfileRepository` (auth token, user profile).
- [ ] Implement `CallHistoryRepository` (session logs and notes).

### 3. WebRTC & Media Engine
- [ ] Implement `WebRTCService` for peer connection lifecycle and ICE candidate handling.
- [ ] Build camera preview and video renderer widgets.
- [ ] Build call control bar (mic mute, camera toggle, flip camera, hang up).

### 4. Signaling & Backend Integration
- [ ] Implement `WebSocketService` to handle `match_request`, `offer`, `answer`, and `ice_candidate` events.
- [ ] Test real-time connection against FastAPI signaling server.

---

## 📝 Change Log (`test1`)
*   **Initial Setup:** Boilerplate generated and iteration documentation initialized.
