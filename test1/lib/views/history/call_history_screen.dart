import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/local/database_helper.dart';
import '../call/outgoing_call_dialog.dart';
import '../chat/direct_chat_screen.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  String _searchQuery = '';
  String _selectedLanguageFilter = 'All';

  String _formatDuration(int totalSeconds) {
    if (totalSeconds < 60) return '${totalSeconds}s';
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  String _formatTimestamp(String? isoString) {
    if (isoString == null) return 'Just now';
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return 'Recent';
    final now = DateTime.now();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');

    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today, $hour:$minute';
    } else if (dt.year == now.year && dt.month == now.month && dt.day == now.day - 1) {
      return 'Yesterday, $hour:$minute';
    }
    return '${dt.day}/${dt.month}/${dt.year}, $hour:$minute';
  }

  void _showSessionDetailSheet(BuildContext context, Map<String, dynamic> session, int index) {
    final peerName = session['peer_name'] ?? 'Practice Partner';
    final language = session['language'] ?? 'Language';
    final durationSec = session['duration_seconds'] ?? 0;
    final timestamp = session['timestamp'];
    final sessionId = session['session_id'] ?? 'session_$index';
    final peerId = (session['peer_id'] != null && session['peer_id'].toString().isNotEmpty)
        ? session['peer_id'].toString()
        : sessionId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white12),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),

              // Partner Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.primaryDark,
                    child: Text(
                      peerName.isNotEmpty ? peerName[0].toUpperCase() : 'P',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          peerName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Practiced $language',
                          style: const TextStyle(color: AppColors.primaryLight, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Details Grid Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(Icons.access_time, 'Call Time', _formatTimestamp(timestamp)),
                    const Divider(color: Colors.white10, height: 16),
                    _buildDetailRow(Icons.timelapse, 'Practice Duration', _formatDuration(durationSec)),
                    const Divider(color: Colors.white10, height: 16),
                    _buildDetailRow(Icons.translate, 'Language Exchanged', language),
                    const Divider(color: Colors.white10, height: 16),
                    _buildDetailRow(Icons.lock_outline, 'Encryption', 'End-to-End P2P WebRTC'),
                    const Divider(color: Colors.white10, height: 16),
                    _buildDetailRow(Icons.tag, 'Session ID', sessionId.toString().length > 18 ? '${sessionId.toString().substring(0, 18)}...' : sessionId.toString()),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons Row
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.cardDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: AppColors.primaryDark, width: 1.2),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _startCallWithPartner(peerName, language, isAudioOnly: true, peerId: peerId);
                      },
                      icon: const Icon(Icons.mic, color: AppColors.primaryDark, size: 18),
                      label: const Text('Voice Call', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _startCallWithPartner(peerName, language, isAudioOnly: false, peerId: peerId);
                      },
                      icon: const Icon(Icons.videocam, size: 18),
                      label: const Text('Video Call', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Open Direct Chat Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryLight,
                    side: const BorderSide(color: AppColors.primaryDark, width: 1),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DirectChatScreen(
                          peerId: peerId,
                          peerName: peerName,
                          language: language,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Open Continued Chat', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 6),

              // Delete Single Record Button
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await DatabaseHelper.instance.deleteSessionAtIndex(index);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Call record deleted'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete Call Record'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _startCallWithPartner(String peerName, String targetLanguage, {required bool isAudioOnly, required String peerId}) {
    OutgoingCallDialog.show(
      context,
      peerId: peerId,
      peerName: peerName,
      targetLanguage: targetLanguage,
      isAudioOnly: isAudioOnly,
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primaryDark, size: 18),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 13)),
          ],
        ),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        title: const Text(
          'Calls',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'Clear History',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppColors.surfaceDark,
                  title: const Text('Clear Call History?', style: TextStyle(color: Colors.white)),
                  content: const Text('This will permanently delete all stored call records.', style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondaryDark)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Clear All'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                await DatabaseHelper.instance.clearSessions();
              }
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: DatabaseHelper.instance.sessionsNotifier,
        builder: (context, sessions, _) {
          // Filter sessions
          final filteredSessions = sessions.where((s) {
            final peerName = (s['peer_name'] ?? '').toString().toLowerCase();
            final lang = (s['language'] ?? '').toString().toLowerCase();
            final q = _searchQuery.toLowerCase();
            final matchesQuery = peerName.contains(q) || lang.contains(q);
            final matchesLang = _selectedLanguageFilter == 'All' ||
                lang == _selectedLanguageFilter.toLowerCase();
            return matchesQuery && matchesLang;
          }).toList();

          // Compute total practice time
          int totalSecondsPracticed = 0;
          for (final s in sessions) {
            totalSecondsPracticed += (s['duration_seconds'] as int? ?? 0);
          }

          return Column(
            children: [
              // Search & Filter Header
              Container(
                color: AppColors.surfaceDark,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  children: [
                    TextField(
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search calls by partner or language...',
                        hintStyle: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: AppColors.primaryDark, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                                onPressed: () => setState(() => _searchQuery = ''),
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.cardDark,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${sessions.length} calls • ${_formatDuration(totalSecondsPracticed)} total practice',
                          style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12),
                        ),
                        if (sessions.isNotEmpty)
                          PopupMenuButton<String>(
                            color: AppColors.surfaceDark,
                            icon: const Icon(Icons.filter_list, color: AppColors.primaryDark, size: 18),
                            tooltip: 'Filter by Language',
                            onSelected: (lang) => setState(() => _selectedLanguageFilter = lang),
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(value: 'All', child: Text('All Languages', style: TextStyle(color: Colors.white))),
                              const PopupMenuItem(value: 'Spanish', child: Text('Spanish', style: TextStyle(color: Colors.white))),
                              const PopupMenuItem(value: 'French', child: Text('French', style: TextStyle(color: Colors.white))),
                              const PopupMenuItem(value: 'German', child: Text('German', style: TextStyle(color: Colors.white))),
                              const PopupMenuItem(value: 'Japanese', child: Text('Japanese', style: TextStyle(color: Colors.white))),
                              const PopupMenuItem(value: 'Mandarin', child: Text('Mandarin', style: TextStyle(color: Colors.white))),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Session List
              Expanded(
                child: filteredSessions.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundColor: AppColors.primaryDark.withValues(alpha: 0.15),
                                child: const Icon(
                                  Icons.phone_in_talk,
                                  size: 36,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'No Call History Found',
                                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Completed language partner calls appear here with full duration records and detail breakdowns.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: filteredSessions.length,
                        separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1, indent: 76),
                        itemBuilder: (context, index) {
                          final session = filteredSessions[index];
                          final peerName = session['peer_name'] ?? 'Practice Partner';
                          final language = session['language'] ?? 'Language';
                          final durationSec = session['duration_seconds'] ?? 0;
                          final timestamp = session['timestamp'];

                          return Dismissible(
                            key: Key(session['session_id'] ?? 'sess_$index'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              color: AppColors.danger,
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (_) async {
                              final messenger = ScaffoldMessenger.of(context);
                              await DatabaseHelper.instance.deleteSessionAtIndex(index);
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Call record removed'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                              onTap: () => _showSessionDetailSheet(context, session, index),
                              leading: CircleAvatar(
                                radius: 24,
                                backgroundColor: AppColors.primaryDark,
                                child: Text(
                                  peerName.isNotEmpty ? peerName[0].toUpperCase() : 'P',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                              ),
                              title: Text(
                                peerName,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              subtitle: Row(
                                children: [
                                  const Icon(
                                    Icons.call_made,
                                    size: 14,
                                    color: AppColors.primaryLight,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$language • ${_formatDuration(durationSec)}',
                                    style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
                                  ),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _formatTimestamp(timestamp),
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryDark),
                                  ),
                                  const SizedBox(height: 4),
                                  const Icon(Icons.info_outline, color: AppColors.primaryDark, size: 16),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
