# Master Project Documentation Center (Global Reference)

> **Location:** `/docs/` (Root Directory)  
> **Purpose:** This directory serves as the **Global Source of Truth** for the entire Language Partner Matcher project across all development iterations, prototypes, and production releases.

---

## 🏛️ Master Architecture & System Specifications

All foundational engineering, architectural contracts, protocols, and cloud infrastructure designs are centrally managed here:

| Document | Scope & Purpose |
| :--- | :--- |
| [**`project_context.md`**](file:///c:/V33R/Programming/College/Sem_7/Project/test1.0/docs/project_context.md) | Academic alignment (Semester 7 CSE), problem statement, core deliverables, and syllabus coverage. |
| [**`system_design.md`**](file:///c:/V33R/Programming/College/Sem_7/Project/test1.0/docs/system_design.md) | High-level system architecture, WebRTC signaling & P2P media flow, component breakdowns, and sequence diagrams. |
| [**`aws_implementation_step_by_step_guide.md`**](file:///c:/V33R/Programming/College/Sem_7/Project/test1.0/docs/aws_implementation_step_by_step_guide.md) | Complete cloud provisioning blueprint (VPC, Subnets, EC2 ASG, ALB with WebSocket stickiness, RDS PostgreSQL, Secrets Manager, Coturn). |
| [**`database_schema.md`**](file:///c:/V33R/Programming/College/Sem_7/Project/test1.0/docs/database_schema.md) | Centralized PostgreSQL DDL definitions, entity relationships, indexes, and mobile SQLite schema. |
| [**`webrtc_signaling_protocol.md`**](file:///c:/V33R/Programming/College/Sem_7/Project/test1.0/docs/webrtc_signaling_protocol.md) | Standard WebSocket signaling message contract (SDP offer/answer, ICE candidates) and P2P `RTCDataChannel` payload schemas. |
| [**`matchmaking_algorithm.md`**](file:///c:/V33R/Programming/College/Sem_7/Project/test1.0/docs/matchmaking_algorithm.md) | Mathematical model for reciprocal language matching, time-decay tolerance expansion, and atomic Redis Lua queues. |

---

## 🔄 Iteration-Specific Documentation Structure

Each sub-iteration codebase maintains its own local documentation directory under `<iteration_folder>/docs/` (for example: [`/test1/docs/`](file:///c:/V33R/Programming/College/Sem_7/Project/test1.0/test1/docs/)) for:
- Iteration-specific sprint tracking & milestone progress.
- Local environment setup and module-specific notes.
- Feature changelogs and version diffs.