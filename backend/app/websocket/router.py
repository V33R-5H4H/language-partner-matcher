import logging
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from app.websocket.signaling_manager import signaling_manager

logger = logging.getLogger("langmatcher.ws")
router = APIRouter()

@router.websocket("/ws/signaling/{user_id}")
async def websocket_signaling_endpoint(websocket: WebSocket, user_id: str):
    await signaling_manager.connect(user_id, websocket)
    try:
        while True:
            data = await websocket.receive_json()
            event_type = data.get("type")

            if event_type == "ping":
                await websocket.send_json({"type": "pong"})

            elif event_type in ("enqueue", "find_match"):
                native_lang = data.get("native_lang", "English")
                target_lang = data.get("target_lang", "Spanish")
                username = data.get("username", f"User_{user_id[:4]}")
                await signaling_manager.enqueue_for_match(user_id, native_lang, target_lang, username)

            elif event_type == "cancel_search":
                await signaling_manager.cancel_search(user_id)
                await websocket.send_json({"type": "search_cancelled"})

            elif event_type in ("offer", "answer", "ice_candidate", "chat_message", "peer_ready", "call_declined", "call_ended", "incoming_call_request", "call_accepted", "typing_status", "read_receipt", "media_state_changed", "call_mode_changed", "peer_left_radar", "peer_unavailable"):
                target_peer_id = data.get("peer_id") or data.get("to")
                if target_peer_id:
                    # Forward signaling payload to peer with sender ID
                    payload = dict(data)
                    payload["from"] = user_id
                    delivered = await signaling_manager.send_personal_message(payload, target_peer_id)
                    if not delivered and event_type == "incoming_call_request":
                        await websocket.send_json({
                            "type": "peer_unavailable",
                            "peer_id": target_peer_id,
                            "reason": "Partner is currently offline",
                        })
                else:
                    logger.warning(f"Signaling event {event_type} received without target peer_id from {user_id}")

    except WebSocketDisconnect:
        room_id = await signaling_manager.disconnect(user_id)
        if room_id:
            logger.info(f"User {user_id} disconnected during call/room {room_id}")
    except Exception as e:
        logger.error(f"WebSocket error for user {user_id}: {e}")
        await signaling_manager.disconnect(user_id)


