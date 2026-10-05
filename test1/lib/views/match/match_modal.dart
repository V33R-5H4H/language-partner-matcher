import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/match_model.dart';
import '../../services/websocket_service.dart';
import '../call/video_call_screen.dart';

class MatchModal extends StatelessWidget {
  final MatchModel match;
  final bool initialAudioOnly;

  const MatchModal({
    super.key,
    required this.match,
    this.initialAudioOnly = false,
  });

  void _launchCall(BuildContext context, {required bool isAudioOnly}) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          match: match,
          peerUsername: match.peerUsername,
          targetLanguage: match.peerNativeLang,
          isAudioOnly: isAudioOnly,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppColors.surfaceDark,
      child: Padding(
        padding: const EdgeInsets.all(22.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top theme-matched icon
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryDark,
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Partner Discovered!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Reciprocal language exchange match ready',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
            ),
            const SizedBox(height: 16),

            // Profile info card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primaryDark,
                        child: Text(
                          match.peerUsername.isNotEmpty
                              ? match.peerUsername[0].toUpperCase()
                              : 'P',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              match.peerUsername,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const Text(
                              'Verified Exchange Partner',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondaryDark),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: Colors.white10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Speaks (Native):',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
                      ),
                      Chip(
                        label: Text(
                          match.peerNativeLang,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        backgroundColor: AppColors.primaryDark.withValues(alpha: 0.3),
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Learning:',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
                      ),
                      Chip(
                        label: Text(
                          match.peerTargetLang,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        backgroundColor: AppColors.primary.withValues(alpha: 0.3),
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                // Voice Call Option
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: initialAudioOnly ? AppColors.primaryDark : AppColors.cardDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: initialAudioOnly ? AppColors.primaryDark : Colors.white12,
                        ),
                      ),
                    ),
                    onPressed: () => _launchCall(context, isAudioOnly: true),
                    icon: const Icon(Icons.mic, size: 18),
                    label: const Text('Voice Call', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),

                // Video Call Option
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !initialAudioOnly ? AppColors.primaryDark : AppColors.cardDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: !initialAudioOnly ? AppColors.primaryDark : Colors.white12,
                        ),
                      ),
                    ),
                    onPressed: () => _launchCall(context, isAudioOnly: false),
                    icon: const Icon(Icons.videocam, size: 18),
                    label: const Text('Video Call', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Decline Button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondaryDark,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onPressed: () {
                  WebSocketService.instance.send({
                    'type': 'call_declined',
                    'peer_id': match.peerId,
                    'room_id': match.roomId,
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Match declined'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: const Text('Decline Match', style: TextStyle(fontSize: 13, color: AppColors.textSecondaryDark)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
