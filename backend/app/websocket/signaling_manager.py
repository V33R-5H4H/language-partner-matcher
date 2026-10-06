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
        # Matchmaking queue: list of waiting user_ids
        self.waiting_queue: list[str] = []

    async def connect(self, user_id: str, websocket: WebSocket):
        await websocket.accept()
        self.active_connections[user_id] = websocket
        logger.info(f"User {user_id} connected via WebSocket. Active: {len(self.active_connections)}")

    async def disconnect(self, user_id: str) -> Optional[str]:
        if user_id in self.waiting_queue:
            self.waiting_queue.remove(user_id)

        room_id = self.user_rooms.pop(user_id, None)
        if room_id:
            # Notify peer in room that user disconnected
            other_peers = [p for p, r in list(self.user_rooms.items()) if r == room_id]
            for p in other_peers:
                self.user_rooms.pop(p, None)
                if p in self.active_connections and p in self.user_profiles:
                    if p not in self.waiting_queue:
                        self.waiting_queue.append(p)
                        logger.info(f"Re-enqueued peer {p} back into queue after partner {user_id} disconnected.")
                await self.send_personal_message({
                    "type": "peer_left_radar",
                    "peer_id": user_id,
                    "room_id": room_id,
                }, p)

        if user_id in self.active_connections:
            del self.active_connections[user_id]

        if user_id in self.user_profiles:
            del self.user_profiles[user_id]

        logger.info(f"User {user_id} disconnected. Remaining active: {len(self.active_connections)}")
        return room_id

    def set_user_profile(self, user_id: str, profile: Dict[str, Any]):
        self.user_profiles[user_id] = profile

    async def enqueue_for_match(self, user_id: str, native_lang: str, target_lang: str, username: str):
        self.user_profiles[user_id] = {
            "user_id": user_id,
            "username": username,
            "native_lang": native_lang,
            "target_lang": target_lang,
        }

        # Purge any previous stale room for this user
        old_room = self.user_rooms.pop(user_id, None)
        if old_room:
            for p, r in list(self.user_rooms.items()):
                if r == old_room:
                    self.user_rooms.pop(p, None)

        my_native = (native_lang or "").strip().lower()
        my_target = (target_lang or "").strip().lower()

        # Clean out dead connections from queue first
        valid_queue = []
        for wid in self.waiting_queue:
            if wid in self.active_connections and wid != user_id:
                valid_queue.append(wid)
        self.waiting_queue = valid_queue

        if user_id not in self.waiting_queue:
            self.waiting_queue.append(user_id)

        # Collect all compatible active peers currently on radar
        compatible_peers = []
        for waiting_id in self.waiting_queue:
            if str(waiting_id) == str(user_id):
                continue
            peer_profile = self.user_profiles.get(waiting_id)
            if not peer_profile:
                continue

            peer_native = (peer_profile.get("native_lang") or "").strip().lower()
            peer_target = (peer_profile.get("target_lang") or "").strip().lower()

            is_reciprocal = (peer_native == my_target and peer_target == my_native)
            is_compatible = (peer_target == my_target or peer_native == my_target or peer_target == my_native)

            if is_reciprocal or is_compatible:
                compatible_peers.append({
                    "peer_id": waiting_id,
                    "peer_username": peer_profile.get("username", "Language Partner"),
                    "peer_native_lang": peer_profile.get("native_lang", target_lang),
                    "peer_target_lang": peer_profile.get("target_lang", native_lang),
                    "is_reciprocal": is_reciprocal,
                    "room_id": f"room_{user_id}_{waiting_id}",
                })

        if compatible_peers:
            # Send the full pool of discovered peers to the searching user
            await self.send_personal_message({
                "type": "peers_discovered",
                "peers": compatible_peers,
            }, user_id)

            # Also broadcast peer_joined_radar to all active compatible peers
            for cp in compatible_peers:
                pid = cp["peer_id"]
                await self.send_personal_message({
                    "type": "peer_joined_radar",
                    "peer": {
                        "peer_id": user_id,
                        "peer_username": username,
                        "peer_native_lang": native_lang,
                        "peer_target_lang": target_lang,
                        "is_reciprocal": cp["is_reciprocal"],
                        "room_id": cp["room_id"],
                    },
                }, pid)

            logger.info(f"User {user_id} discovered {len(compatible_peers)} partner(s) on radar.")
        else:
            logger.info(f"User {user_id} enqueued (Native: {native_lang}, Target: {target_lang}). Waiting for partners...")

    async def cancel_search(self, user_id: str):
        if user_id in self.waiting_queue:
            self.waiting_queue.remove(user_id)

        # Broadcast to all remaining active waiting users that this user left the radar
        for waiting_id in list(self.waiting_queue):
            if waiting_id in self.active_connections:
                await self.send_personal_message({
                    "type": "peer_left_radar",
                    "peer_id": user_id,
                }, waiting_id)

        logger.info(f"User {user_id} removed from matchmaking queue.")

    async def send_personal_message(self, message: dict, user_id: str) -> bool:
        if user_id in self.active_connections:
            try:
                await self.active_connections[user_id].send_json(message)
                return True
            except Exception as e:
                logger.error(f"Error sending message to {user_id}: {e}")
                return False
        return False

signaling_manager = SignalingManager()


