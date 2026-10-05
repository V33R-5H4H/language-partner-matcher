import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../core/constants/app_colors.dart';

class VideoRenderBox extends StatelessWidget {
  final RTCVideoRenderer? renderer;
  final bool isLocal;
  final bool isVideoOff;
  final bool isMicMuted;
  final bool isConnecting;
  final bool showTopBadges;
  final String label;
  final String? avatarLetter;

  const VideoRenderBox({
    super.key,
    this.renderer,
    required this.isLocal,
    this.isVideoOff = false,
    this.isMicMuted = false,
    this.isConnecting = false,
    this.showTopBadges = false,
    required this.label,
    this.avatarLetter,
  });

  @override
  Widget build(BuildContext context) {
    if (renderer == null) {
      return LayoutBuilder(
        builder: (context, constraints) => _buildPlaceholder(constraints),
      );
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: renderer!,
        builder: (context, _) {
          final bool hasStream = renderer!.srcObject != null;

          return LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 180 || constraints.maxHeight < 220;

              return Container(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Keep RTCVideoView mounted so OpenGL/Texture surface is always initialized
                    RTCVideoView(
                      renderer!,
                      mirror: isLocal,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),

                    if (!hasStream || isVideoOff) _buildPlaceholder(constraints),

                    // Connecting indicator
                    if (isConnecting)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryLight,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Connecting...',
                                style: TextStyle(color: Colors.white70, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Top/Status Badges
                    if (showTopBadges) ...[
                      // Top Left: Label Badge (constrained width so it doesn't collide with swap icon)
                      Positioned(
                        top: 6,
                        left: 6,
                        right: isCompact ? 36 : null,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white12, width: 0.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isVideoOff ? AppColors.danger : AppColors.success,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Status Badges (mic mute / camera off) positioned at bottom-right in compact mode
                      Positioned(
                        bottom: isCompact ? 6 : null,
                        top: isCompact ? null : 6,
                        right: 6,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isMicMuted)
                              Container(
                                padding: const EdgeInsets.all(3),
                                margin: const EdgeInsets.only(left: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.danger,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.mic_off,
                                  color: Colors.white,
                                  size: 10,
                                ),
                              ),
                            if (isVideoOff)
                              Container(
                                padding: const EdgeInsets.all(3),
                                margin: const EdgeInsets.only(left: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.danger,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.videocam_off,
                                  color: Colors.white,
                                  size: 10,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPlaceholder(BoxConstraints constraints) {
    final letter = avatarLetter?.isNotEmpty == true
        ? avatarLetter![0].toUpperCase()
        : (label.isNotEmpty ? label[0].toUpperCase() : 'P');

    final bool isCompact = constraints.maxWidth < 180 || constraints.maxHeight < 220;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surfaceDark,
            AppColors.backgroundDark,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      padding: EdgeInsets.all(isCompact ? 4.0 : 16.0),
      child: Center(
        child: isCompact
            // Ultra-compact PiP representation guaranteed not to overflow
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryDark.withValues(alpha: 0.35),
                          border: Border.all(
                            color: isVideoOff ? AppColors.danger : AppColors.primaryLight,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            letter,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      if (isVideoOff)
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: AppColors.danger,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.videocam_off, size: 9, color: Colors.white),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    constraints: const BoxConstraints(maxWidth: 95),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isVideoOff ? (isLocal ? 'Paused' : '$label Off') : label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              )
            // Fullscreen Central Avatar representation
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryDark.withValues(alpha: 0.25),
                      border: Border.all(
                        color: isVideoOff ? AppColors.danger : AppColors.primaryDark,
                        width: 2.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        letter,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isVideoOff ? Icons.videocam_off : Icons.camera_alt_outlined,
                          color: isVideoOff ? AppColors.danger : Colors.white70,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isVideoOff ? '$label Paused Video' : 'Camera Loading...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

