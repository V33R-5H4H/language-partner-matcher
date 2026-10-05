# AWS & Production Cloud Deployment Guide

This guide details how to deploy the **Language Partner Matcher** production infrastructure on AWS using Docker, Amazon RDS, Amazon ElastiCache, and an EC2/ECS instance hosting the FastAPI backend and Coturn TURN relay server.

---

## 1. Architecture Overview

```
                          [ Internet / Mobile Clients ]
                                       │
                    ┌──────────────────┴──────────────────┐
                    │                                     │
           HTTPS / WSS (Port 443)                 STUN/TURN (UDP/TCP 3478, TLS 5349)
                    │                                     │
                    ▼                                     ▼
        ┌───────────────────────┐             ┌───────────────────────┐
        │ AWS ALB / Nginx Proxy │             │   Coturn TURN Server  │
        │   SSL Termination     │             │ (Host Network on EC2) │
        └───────────┬───────────┘             └───────────────────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │ FastAPI Backend (ECS) │
        │ WebSocket Signaling   │
        └───────┬───────┬───────┘
                │       │
       ┌────────┘       └────────┐
       ▼                         ▼
┌──────────────┐         ┌───────────────┐
│  Amazon RDS  │         │  ElastiCache  │
│PostgreSQL 15 │         │    Redis 7    │
└──────────────┘         └───────────────┘
```

---

## 2. Infrastructure Setup Steps

### Step 1: Managed Database & Caching
1. **Amazon RDS PostgreSQL 15**:
   - Instance Class: `db.t4g.micro` or `db.t4g.small`.
   - Engine: PostgreSQL 15.5.
   - Storage: 20 GB GP3 with Auto-scaling enabled.
   - Security Group: Allow TCP 5432 from ECS/EC2 Security Group.

2. **Amazon ElastiCache Redis 7**:
   - Node Type: `cache.t4g.micro`.
   - Multi-AZ with Automatic Failover (optional for HA).
   - Security Group: Allow TCP 6379 from ECS/EC2 Security Group.

---

### Step 2: Coturn TURN Relay Server Setup (EC2 Instance)
WebRTC direct P2P connections fail across restrictive cellular networks and Symmetric NATs. Coturn acts as a high-throughput media relay:

1. **Launch EC2 Instance (Ubuntu 22.04 LTS)**:
   - Instance Type: `t3.small` or `c6g.medium` (network optimized).
   - Assign an **AWS Elastic IP (Static Public IP)**.

2. **Security Group Inbound Rules**:
   - `TCP/UDP 3478` (STUN/TURN standard port)
   - `TCP/UDP 5349` (TURNS TLS port)
   - `UDP 49152 - 65535` (WebRTC dynamic media relay port range)
   - `TCP 80, 443` (HTTP/HTTPS for FastAPI & SSL)

3. **Deploy using Docker Compose**:
   ```bash
   git clone https://github.com/your-org/language-partner-matcher.git
   cd language-partner-matcher/backend
   
   # Copy production environment variables
   cp .env.example .env.prod
   
   # Start all production containers with host networking for Coturn
   docker compose -f docker-compose.prod.yml up -d --build
   ```

---

## 3. Environment Variables Configuration

Create `.env.prod` with your production secrets:

```env
# Database & Cache
DATABASE_URL=postgresql+asyncpg://postgres_user:StrongPassword123@your-rds-endpoint.rds.amazonaws.com:5432/langmatcher
REDIS_URL=redis://your-elasticache-endpoint.cache.amazonaws.com:6379/0

# Security & Tokens
JWT_SECRET_KEY=generate_a_64_character_hex_random_secret_string_here
ENVIRONMENT=production

# Coturn TURN Configuration
TURN_DOMAIN=turn.yourdomain.com
TURN_SHARED_SECRET=generate_strong_random_turn_secret_here
TURN_PORT_UDP=3478
TURN_PORT_TLS=5349
```

---

## 4. Verifying WebRTC TURN Relay

1. Test your TURN server using Google's WebRTC ICE Trickle Tool:
   - URL: `https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/`
   - STUN/TURN URI: `turn:YOUR_PUBLIC_IP:3478?transport=udp`
   - Username: `<timestamp>:<userid>`
   - Password: `<hmac-sha1-base64-token>`
2. Verify candidate type `relay` is returned successfully.
