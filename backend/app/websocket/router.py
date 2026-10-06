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
                native_lang = data.get("native_lang", "")
                target_lang = data.get("target_lang", "")
                username = data.get("username", f"User_{user_id[:6]}")
                await signaling_manager.enqueue_for_match(user_id, native_lang, target_lang, username)

            elif event_type == "cancel_search":
                await signaling_manager.cancel_search(user_id)
                await websocket.send_json({"type": "search_cancelled"})

            elif event_type in (
                "offer", "answer", "ice_candidate",
                "peer_ready",
                "incoming_call_request", "call_accepted", "call_declined", "call_ended",
                "chat_message",
                "typing_status", "read_receipt",
                "media_state_changed", "call_mode_changed",
                "peer_unavailable",
            ):
                # Determine the target peer — prioritise peer_id over to
                target_peer_id = (
                    data.get("peer_id") or
                    data.get("to") or
                    data.get("caller_id") if event_type == "call_accepted" else None
                )
                # For incoming_call_request the backend should forward to the *recipient* peer
                if event_type == "incoming_call_request":
                    target_peer_id = data.get("peer_id")

                if target_peer_id:
                    payload = dict(data)
                    payload["from"] = user_id
                    delivered = await signaling_manager.send_personal_message(payload, target_peer_id)
                    if not delivered:
                        # Notify caller that the target peer is offline
                        await websocket.send_json({
                            "type": "peer_unavailable",
                            "peer_id": target_peer_id,
                            "reason": "Partner is currently offline",
                        })
                else:
                    logger.warning(
                        f"Signaling event '{event_type}' from {user_id} missing target peer_id — dropped."
                    )

    except WebSocketDisconnect:
        room_id = await signaling_manager.disconnect(user_id)
        if room_id:
            logger.info(f"User {user_id} disconnected from active room {room_id}")
        else:
            logger.info(f"User {user_id} disconnected (no active room)")
    except Exception as e:
        logger.error(f"WebSocket error for user {user_id}: {e}", exc_info=True)
        await signaling_manager.disconnect(user_id)
