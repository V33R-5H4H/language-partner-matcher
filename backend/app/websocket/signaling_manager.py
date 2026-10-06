import logging
from typing import Dict, Any, Optional
from fastapi import WebSocket

logger = logging.getLogger("langmatcher.signaling")


class SignalingManager:
    def __init__(self):
        # user_id -> WebSocket
        self.active_connections: Dict[str, WebSocket] = {}
        # user_id -> User Profile dict (native_lang, target_lang, username)
        self.user_profiles: Dict[str, Dict[str, Any]] = {}
        # user_id -> current room_id
        self.user_rooms: Dict[str, str] = {}
        # Matchmaking queue: set of user_ids actively searching
        self.waiting_queue: list[str] = []

    async def connect(self, user_id: str, websocket: WebSocket):
        await websocket.accept()
        # Replace any stale connection for this user_id
        self.active_connections[user_id] = websocket
        # Ensure user is NOT in discovery queue on connect — they must explicitly start discovery
        if user_id in self.waiting_queue:
            self.waiting_queue.remove(user_id)
        logger.info(f"User {user_id} connected via WebSocket. Active: {len(self.active_connections)}")

    async def disconnect(self, user_id: str) -> Optional[str]:
        # Remove from discovery queue
        if user_id in self.waiting_queue:
            self.waiting_queue.remove(user_id)

        # Notify all other active searching peers that this user left radar
        for wid in list(self.waiting_queue):
            if wid in self.active_connections and wid != user_id:
                await self.send_personal_message({
                    "type": "peer_left_radar",
                    "peer_id": user_id,
                }, wid)

        # Notify any in-call peer that this user disconnected
        room_id = self.user_rooms.pop(user_id, None)
        if room_id:
            other_peers = [p for p, r in list(self.user_rooms.items()) if r == room_id]
            for p in other_peers:
                self.user_rooms.pop(p, None)
                await self.send_personal_message({
                    "type": "call_ended",
                    "peer_id": user_id,
                    "room_id": room_id,
                    "reason": "partner_disconnected",
                }, p)

        if user_id in self.active_connections:
            del self.active_connections[user_id]

        if user_id in self.user_profiles:
            del self.user_profiles[user_id]

        logger.info(f"User {user_id} disconnected. Remaining active: {len(self.active_connections)}")
        return room_id

    def _purge_dead_queue(self):
        """Remove any user from waiting_queue whose WebSocket is no longer active."""
        self.waiting_queue = [
            uid for uid in self.waiting_queue
            if uid in self.active_connections
        ]

    async def enqueue_for_match(self, user_id: str, native_lang: str, target_lang: str, username: str):
        # Update user profile
        self.user_profiles[user_id] = {
            "user_id": user_id,
            "username": username,
            "native_lang": native_lang,
            "target_lang": target_lang,
        }

        # Purge any stale room association for this user
        old_room = self.user_rooms.pop(user_id, None)
        if old_room:
            for p, r in list(self.user_rooms.items()):
                if r == old_room:
                    self.user_rooms.pop(p, None)

        my_native = (native_lang or "").strip().lower()
        my_target = (target_lang or "").strip().lower()

        if not my_native or not my_target:
            logger.warning(f"User {user_id} sent empty language fields — not enqueued.")
            return

        # Purge dead connections from queue
        self._purge_dead_queue()

        # Add to queue if not already searching
        if user_id not in self.waiting_queue:
            self.waiting_queue.append(user_id)

        # Strict reciprocal matching:
        # I Speak A + Learn B  <->  Partner Speaks B + Learns A
        compatible_peers = []
        for waiting_id in self.waiting_queue:
            if str(waiting_id) == str(user_id):
                continue
            peer_profile = self.user_profiles.get(waiting_id)
            if not peer_profile:
                continue

            peer_native = (peer_profile.get("native_lang") or "").strip().lower()
            peer_target = (peer_profile.get("target_lang") or "").strip().lower()

            if not peer_native or not peer_target:
                continue

            # Exact reciprocal tandem: My native = Peer's target AND My target = Peer's native
            is_match = (peer_native == my_target and peer_target == my_native)

            if is_match:
                compatible_peers.append({
                    "peer_id": waiting_id,
                    "peer_username": peer_profile.get("username", "Language Partner"),
                    "peer_native_lang": peer_profile.get("native_lang", ""),
                    "peer_target_lang": peer_profile.get("target_lang", ""),
                    "is_reciprocal": True,
                    "room_id": f"room_{min(user_id, waiting_id)}_{max(user_id, waiting_id)}",
                })

        if compatible_peers:
            # Send full list of reciprocal partners to the requesting user
            await self.send_personal_message({
                "type": "peers_discovered",
                "peers": compatible_peers,
            }, user_id)

            # Broadcast this new user's presence to all compatible partners
            for cp in compatible_peers:
                pid = cp["peer_id"]
                await self.send_personal_message({
                    "type": "peer_joined_radar",
                    "peer": {
                        "peer_id": user_id,
                        "peer_username": username,
                        "peer_native_lang": native_lang,
                        "peer_target_lang": target_lang,
                        "is_reciprocal": True,
                        "room_id": cp["room_id"],
                    },
                }, pid)

            logger.info(
                f"User {user_id} ({native_lang}->{target_lang}) discovered "
                f"{len(compatible_peers)} reciprocal partner(s)."
            )
        else:
            logger.info(
                f"User {user_id} enqueued ({native_lang}->{target_lang}). "
                f"Waiting for partner ({target_lang}->{native_lang})..."
            )

    async def cancel_search(self, user_id: str):
        if user_id in self.waiting_queue:
            self.waiting_queue.remove(user_id)

        # Remove profile so stale data doesn't pollute future searches
        self.user_profiles.pop(user_id, None)

        # Notify all remaining searching peers that this user left radar
        for waiting_id in list(self.waiting_queue):
            if waiting_id in self.active_connections:
                await self.send_personal_message({
                    "type": "peer_left_radar",
                    "peer_id": user_id,
                }, waiting_id)

        logger.info(f"User {user_id} cancelled search and left radar.")

    async def send_personal_message(self, message: dict, user_id: str) -> bool:
        if user_id in self.active_connections:
            try:
                await self.active_connections[user_id].send_json(message)
                return True
            except Exception as e:
                logger.error(f"Failed to deliver message to {user_id}: {e}. Removing stale connection.")
                # Clean up dead connection
                del self.active_connections[user_id]
                if user_id in self.waiting_queue:
                    self.waiting_queue.remove(user_id)
                self.user_profiles.pop(user_id, None)
                return False
        return False


signaling_manager = SignalingManager()
