import asyncio
import json

class MatchmakingService:
    def __init__(self):
        self.waiting_users = []

    async def enqueue_user(self, user_id: str, native_lang_id: int, target_lang_id: int, proficiency: int):
        self.waiting_users.append({
            "user_id": user_id,
            "native_lang_id": native_lang_id,
            "target_lang_id": target_lang_id,
            "proficiency": proficiency,
        })

    async def find_match(self, user_id: str):
        # Match evaluation logic
        return None

matchmaking_service = MatchmakingService()
