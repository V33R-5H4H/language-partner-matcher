# WebRTC Signaling & Real-Time Protocol Specification

This document defines the WebSocket signaling message schema, handshake lifecycles, and DataChannel payload formats between the Flutter mobile client and the FastAPI signaling server.

---

## 1. WebSocket Endpoint & Authentication

- **Endpoint:** `wss://api.yourdomain.com/ws/signaling/{user_id}?token=<JWT_TOKEN>`
- **Authentication:** Token verified on handshake. If expired or invalid, socket is closed immediately with code `4001 (Unauthorized)`.

---

## 2. Signaling Event Types & JSON Schemas

### 2.1 Matchmaking & Room Assignment

#### 1. `match_request` (Client -> Server)
Submitted when user clicks "Find Partner".
```json
{
  "type": "match_request",
  "target_language_id": 2,
  "max_wait_seconds": 60
}
```

#### 2. `match_found` (Server -> Both Clients)
Server notifies matched peers of their assigned room and initial WebRTC roles.
```json
{
  "type": "match_found",
  "room_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
  "peer_id": "c1a23e45-5678-90ab-cdef-1234567890ab",
  "peer_username": "Carlos_ES",
  "peer_native_lang": "Spanish",
  "peer_target_lang": "English",
  "is_initiator": true
}
```
*Note: The `is_initiator: true` client generates the initial SDP Offer.*

---

### 2.2 WebRTC Session Description Protocol (SDP) Exchange

#### 3. `offer` (Client -> Server -> Peer)
```json
{
  "type": "offer",
  "room_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
  "sdp": {
    "type": "offer",
    "sdp": "v=0\r\no=- 4611731400430051336 2 IN IP4 127.0.0.1\r\ns=-\r\nt=0 0\r\n..."
  }
}
```

#### 4. `answer` (Client -> Server -> Peer)
```json
{
  "type": "answer",
  "room_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
  "sdp": {
    "type": "answer",
    "sdp": "v=0\r\no=- 7811731400430051336 2 IN IP4 127.0.0.1\r\ns=-\r\nt=0 0\r\n..."
  }
}
```

---

### 2.3 Trickle ICE Candidate Exchange

#### 5. `ice_candidate` (Bidirectional Peer Relay)
```json
{
  "type": "ice_candidate",
  "room_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
  "candidate": {
    "candidate": "candidate:842163049 1 udp 1677729535 192.168.1.100 58432 typ host ...",
    "sdpMid": "0",
    "sdpMLineIndex": 0
  }
}
```

---

### 2.4 Call Teardown & Heartbeat

#### 6. `ping` / `pong` (Heartbeat)
Every 25 seconds to keep the ALB connection open.
- Client -> Server: `{"type": "ping"}`
- Server -> Client: `{"type": "pong"}`

#### 7. `hangup` / `peer_left`
```json
{
  "type": "hangup",
  "room_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
  "reason": "USER_ENDED"
}
```

---

## 3. WebRTC DataChannel Protocol (In-Call P2P)

Data is sent directly peer-to-peer over the `RTCDataChannel` named `"chat-and-prompts"`.

### 3.1 In-Call Chat Message
```json
{
  "channel_event": "chat_message",
  "sender_name": "Carlos_ES",
  "text": "How do you pronounce this word in English?",
  "timestamp": "2026-09-30T10:00:00Z"
}
```

### 3.2 Conversation Prompt Sync
```json
{
  "channel_event": "topic_prompt",
  "prompt_id": 42,
  "topic_title": "Favorite Hobbies",
  "question_native": "What do you enjoy doing on weekends?",
  "question_target": "What do you like to do on weekends?"
}
```
