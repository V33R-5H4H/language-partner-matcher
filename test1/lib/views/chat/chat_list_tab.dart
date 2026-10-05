import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/local/database_helper.dart';
import 'direct_chat_screen.dart';

class ChatListTab extends StatelessWidget {
  const ChatListTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0.5,
        title: const Text(
          'Chats',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
        ),
      ),
      body: ValueListenableBuilder<Map<String, List<Map<String, dynamic>>>>(
        valueListenable: DatabaseHelper.instance.directChatsNotifier,
        builder: (context, chatMap, _) {
          if (chatMap.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.primaryDark.withValues(alpha: 0.15),
                      child: const Icon(
                        Icons.chat_bubble_outline,
                        size: 38,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Direct Chats Yet',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Messages exchanged during and after practice sessions will be saved here so you can continue conversations anytime.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
            );
          }

          final peerIds = chatMap.keys.toList();

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: peerIds.length,
            separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1, indent: 76),
            itemBuilder: (ctx, idx) {
              final peerId = peerIds[idx];
              final messages = chatMap[peerId] ?? [];
              final lastMsg = messages.isNotEmpty ? messages.last : null;
              final peerName = lastMsg?['peer_name'] ?? 'Practice Partner';
              final lastText = lastMsg?['text'] ?? 'No messages yet';
              final timeStr = lastMsg?['time']?.toString() ?? '';
              final dt = DateTime.tryParse(timeStr) ?? DateTime.now();
              final formattedTime =
                  '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

              final itemWidget = ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DirectChatScreen(
                        peerId: peerId,
                        peerName: peerName,
                      ),
                    ),
                  );
                },
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primaryDark,
                  child: Text(
                    peerName.isNotEmpty ? peerName[0].toUpperCase() : 'P',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                title: Text(
                  peerName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Text(
                  lastText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
                ),
                trailing: Text(
                  formattedTime,
                  style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 11),
                ),
              );

              return Dismissible(
                key: Key('chat_$peerId'),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: AppColors.danger,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) async {
                  await DatabaseHelper.instance.deleteDirectChat(peerId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Chat with $peerName deleted'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: itemWidget,
              );
            },
          );
        },
      ),
    );
  }
}
