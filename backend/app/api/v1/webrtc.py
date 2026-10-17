import hmac
import hashlib
import base64
import time
import os
from typing import Dict, Any, List
from fastapi import APIRouter, HTTPException

router = APIRouter(prefix="/webrtc", tags=["WebRTC & ICE"])

# TURN server configuration — all values must come from environment variables.
# Set these via .env (local) or AWS Secrets Manager → .env on EC2 (production).
TURN_DOMAIN = os.getenv("TURN_DOMAIN", "")
TURN_SECRET = os.getenv("TURN_SHARED_SECRET", "")
TURN_PORT_UDP = int(os.getenv("TURN_PORT_UDP", 3478))
TURN_PORT_TLS = int(os.getenv("TURN_PORT_TLS", 5349))

@router.get("/ice-servers", response_model=Dict[str, Any])
async def get_ice_servers(user_id: str = "guest") -> Dict[str, Any]:
    """
    Generate dynamic ephemeral WebRTC ICE server credentials (STUN + TURN).
    Uses HMAC-SHA1 time-limited tokens for secure Coturn relay authentication.
    Returns only STUN entries if TURN is not configured.
    """
    # Public STUN servers are always available
    stun_entry: Dict[str, Any] = {
        "urls": [
            "stun:stun.l.google.com:19302",
            "stun:stun1.l.google.com:19302",
            "stun:stun2.l.google.com:19302",
            "stun:global.stun.twilio.com:3478",
        ]
    }
    ice_servers: List[Dict[str, Any]] = [stun_entry]

    # Only add TURN entries when fully configured
    if TURN_DOMAIN and TURN_SECRET:
        # 24-hour credential expiration
        expiry_time = int(time.time()) + (24 * 3600)
        ephemeral_username = f"{expiry_time}:{user_id}"

        # HMAC-SHA1 signature using the shared Coturn secret
        key = TURN_SECRET.encode("utf-8")
        message = ephemeral_username.encode("utf-8")
        h = hmac.new(key, message, hashlib.sha1)
        ephemeral_password = base64.b64encode(h.digest()).decode("utf-8")

        ice_servers += [
            # TURN UDP (Standard NAT traversal)
            {
                "urls": [f"turn:{TURN_DOMAIN}:{TURN_PORT_UDP}?transport=udp"],
                "username": ephemeral_username,
                "credential": ephemeral_password,
            },
            # TURN TCP (Firewall traversal)
            {
                "urls": [f"turn:{TURN_DOMAIN}:{TURN_PORT_UDP}?transport=tcp"],
                "username": ephemeral_username,
                "credential": ephemeral_password,
            },
            # TURNS TLS (Encrypted relay over port 5349)
            {
                "urls": [f"turns:{TURN_DOMAIN}:{TURN_PORT_TLS}?transport=tcp"],
                "username": ephemeral_username,
                "credential": ephemeral_password,
            },
        ]

    return {
        "iceServers": ice_servers,
        "turnConfigured": bool(TURN_DOMAIN and TURN_SECRET),
        "expiresAt": int(time.time()) + (24 * 3600),
    }
