import 'package:flutter/material.dart';

class CallControlsBar extends StatelessWidget {
  final bool isMicMuted;
  final bool isVideoOff;
  final bool isSpeakerOn;
  final bool isAudioOnlyMode;
  final int unreadMessageCount;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleVideo;
  final VoidCallback onSwitchCamera;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onToggleCallMode;
  final VoidCallback onOpenChat;
  final VoidCallback onEndCall;

  const CallControlsBar({
    super.key,
    required this.isMicMuted,
    required this.isVideoOff,
    this.isSpeakerOn = true,
    this.isAudioOnlyMode = false,
    this.unreadMessageCount = 0,
    required this.onToggleMic,
    required this.onToggleVideo,
    required this.onSwitchCamera,
    required this.onToggleSpeaker,
    required this.onToggleCallMode,
    required this.onOpenChat,
    required this.onEndCall,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2C34).withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFF2A3942), width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. Microphone Toggle
              _buildRoundButton(
                tooltip: isMicMuted ? 'Unmute' : 'Mute',
                icon: isMicMuted ? Icons.mic_off : Icons.mic,
                backgroundColor: isMicMuted ? const Color(0xFFEA4335) : const Color(0xFF2A3942),
                iconColor: Colors.white,
                onPressed: onToggleMic,
              ),
              const SizedBox(width: 6),

              // 2. Video Toggle / Upgrade to Video
              if (isAudioOnlyMode)
                _buildRoundButton(
                  tooltip: 'Switch to Video Call',
                  icon: Icons.videocam,
                  backgroundColor: const Color(0xFF00A884),
                  iconColor: Colors.white,
                  onPressed: onToggleCallMode,
                )
              else
                _buildRoundButton(
                  tooltip: isVideoOff ? 'Turn Camera On' : 'Turn Camera Off',
                  icon: isVideoOff ? Icons.videocam_off : Icons.videocam,
                  backgroundColor: isVideoOff ? const Color(0xFFEA4335) : const Color(0xFF2A3942),
                  iconColor: Colors.white,
                  onPressed: onToggleVideo,
                ),
              const SizedBox(width: 6),

              // 3. Switch to Voice Only Mode (when in Video mode)
              if (!isAudioOnlyMode) ...[
                _buildRoundButton(
                  tooltip: 'Switch to Voice Mode (Save Data)',
                  icon: Icons.phone_in_talk,
                  backgroundColor: const Color(0xFF2A3942),
                  iconColor: const Color(0xFF00E676),
                  onPressed: onToggleCallMode,
                ),
                const SizedBox(width: 6),
              ],

              // 4. Speakerphone Toggle
              _buildRoundButton(
                tooltip: isSpeakerOn ? 'Speaker ON' : 'Earpiece Mode',
                icon: isSpeakerOn ? Icons.volume_up : Icons.hearing,
                backgroundColor: isSpeakerOn ? const Color(0xFF00A884) : const Color(0xFF2A3942),
                iconColor: Colors.white,
                onPressed: onToggleSpeaker,
              ),
              const SizedBox(width: 6),

              // 5. Flip Camera (Only in video mode)
              if (!isAudioOnlyMode) ...[
                _buildRoundButton(
                  tooltip: 'Switch Camera',
                  icon: Icons.flip_camera_ios,
                  backgroundColor: const Color(0xFF2A3942),
                  iconColor: Colors.white,
                  onPressed: onSwitchCamera,
                ),
                const SizedBox(width: 6),
              ],

              // 6. In-Call Chat with Green Indicator Badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _buildRoundButton(
                    tooltip: 'In-Call Chat',
                    icon: Icons.chat_bubble_outline,
                    backgroundColor: const Color(0xFF2A3942),
                    iconColor: Colors.white,
                    onPressed: onOpenChat,
                  ),
                  if (unreadMessageCount > 0)
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF1F2C34), width: 1.5),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 10,
                          minHeight: 10,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 6),

              // 7. End Call Button
              _buildRoundButton(
                tooltip: 'End Call',
                icon: Icons.call_end,
                backgroundColor: const Color(0xFFEA4335),
                iconColor: Colors.white,
                onPressed: onEndCall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoundButton({
    required String tooltip,
    required IconData icon,
    required Color backgroundColor,
    required Color iconColor,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 19,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }
}

