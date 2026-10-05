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

        my_native = (native_lang or "").strip().lower()
        my_target = (target_lang or "").strip().lower()

        # Check for a match in the waiting queue:
        # Tier 1: Perfect reciprocal match (User A native == User B target AND User A target == User B native)
        # Tier 2: Compatible match (User A target == User B target, or one speaks what other is learning)
        matched_peer_id = None
        
        # Pass 1: Reciprocal
        for waiting_id in self.waiting_queue:
            if str(waiting_id) == str(user_id):
                continue
            peer_profile = self.user_profiles.get(waiting_id)
            if not peer_profile:
                continue

            peer_native = (peer_profile.get("native_lang") or "").strip().lower()
            peer_target = (peer_profile.get("target_lang") or "").strip().lower()

            if peer_native == my_target and peer_target == my_native:
                matched_peer_id = waiting_id
                break

        # Pass 2: Co-learning / Compatible if no reciprocal match yet
        if not matched_peer_id:
            for waiting_id in self.waiting_queue:
                if str(waiting_id) == str(user_id):
                    continue
                peer_profile = self.user_profiles.get(waiting_id)
                if not peer_profile:
                    continue

                peer_native = (peer_profile.get("native_lang") or "").strip().lower()
                peer_target = (peer_profile.get("target_lang") or "").strip().lower()

                # Both practicing the same target language or complementary
                if peer_target == my_target or peer_native == my_target or peer_target == my_native:
                    matched_peer_id = waiting_id
                    break

        if matched_peer_id:
            # Remove matched peer from queue
            if matched_peer_id in self.waiting_queue:
                self.waiting_queue.remove(matched_peer_id)
            if user_id in self.waiting_queue:
                self.waiting_queue.remove(user_id)

            room_id = f"room_{user_id}_{matched_peer_id}"
            self.user_rooms[user_id] = room_id
            self.user_rooms[matched_peer_id] = room_id

            peer_profile = self.user_profiles.get(matched_peer_id, {})
            my_profile = self.user_profiles.get(user_id, {})

            # Notify User A (Initiator)
            await self.send_personal_message({
                "type": "match_found",
                "room_id": room_id,
                "peer_id": matched_peer_id,
                "peer_username": peer_profile.get("username", "Language Partner"),
                "peer_native_lang": peer_profile.get("native_lang", target_lang),
                "peer_target_lang": peer_profile.get("target_lang", native_lang),
                "is_initiator": True,
            }, user_id)

            # Notify User B (Receiver)
            await self.send_personal_message({
                "type": "match_found",
                "room_id": room_id,
                "peer_id": user_id,
                "peer_username": my_profile.get("username", "Language Partner"),
                "peer_native_lang": my_profile.get("native_lang", native_lang),
                "peer_target_lang": my_profile.get("target_lang", target_lang),
                "is_initiator": False,
            }, matched_peer_id)

            logger.info(f"Match created between {user_id} and {matched_peer_id} in {room_id}")
        else:
            if user_id not in self.waiting_queue:
                self.waiting_queue.append(user_id)
                logger.info(f"User {user_id} enqueued (Native: {native_lang}, Target: {target_lang}). Queue size: {len(self.waiting_queue)}")

    async def cancel_search(self, user_id: str):
        if user_id in self.waiting_queue:
            self.waiting_queue.remove(user_id)

        room_id = self.user_rooms.pop(user_id, None)
        if room_id:
            other_peers = [p for p, r in list(self.user_rooms.items()) if r == room_id]
            for p in other_peers:
                self.user_rooms.pop(p, None)
                if p in self.active_connections and p in self.user_profiles:
                    if p not in self.waiting_queue:
                        self.waiting_queue.append(p)
                        logger.info(f"Re-enqueued peer {p} back into queue after partner {user_id} cancelled search.")
                await self.send_personal_message({
                    "type": "peer_left_radar",
                    "peer_id": user_id,
                    "room_id": room_id,
                }, p)
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


