import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/webrtc_service.dart';

class ChatMessage {
  final String sender;
  final String text;
  final DateTime time;
  final bool isSelf;
  final bool isSystem;

  ChatMessage({
    required this.sender,
    required this.text,
    required this.time,
    this.isSelf = false,
    this.isSystem = false,
  });
}

class InCallChatSheet extends StatefulWidget {
  final String peerUsername;

  const InCallChatSheet({
    super.key,
    this.peerUsername = 'Practice Partner',
  });

  @override
  State<InCallChatSheet> createState() => _InCallChatSheetState();
}

class _InCallChatSheetState extends State<InCallChatSheet> {
  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _messageSubscription;

  late final List<ChatMessage> _messages = [
    ChatMessage(
      sender: 'System',
      text: 'Encrypted P2P Real-Time DataChannel active.',
      time: DateTime.now(),
      isSystem: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Restore existing chat history for the active call session
    for (final msg in WebRTCService.instance.chatHistory) {
      final sender = (msg['sender'] != null && msg['sender'] != 'Partner' && msg['sender'] != 'Practice Partner')
          ? msg['sender'].toString()
          : (msg['isSelf'] == true ? 'You' : widget.peerUsername);

      _messages.add(
        ChatMessage(
          sender: sender,
          text: msg['text'] ?? '',
          time: DateTime.tryParse(msg['time'] ?? '') ?? DateTime.now(),
          isSelf: msg['isSelf'] ?? false,
        ),
      );
    }
    _scrollToBottom();

    _messageSubscription = WebRTCService.instance.inCallMessages.listen((msg) {
      if (mounted) {
        final sender = (msg['sender'] != null && msg['sender'] != 'Partner' && msg['sender'] != 'Practice Partner')
            ? msg['sender'].toString()
            : (msg['isSelf'] == true ? 'You' : widget.peerUsername);

        setState(() {
          _messages.add(
            ChatMessage(
              sender: sender,
              text: msg['text'] ?? '',
              time: DateTime.tryParse(msg['time'] ?? '') ?? DateTime.now(),
              isSelf: msg['isSelf'] ?? false,
            ),
          );
        });
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    WebRTCService.instance.sendChatMessage(text);
    _messageController.clear();
    _scrollToBottom();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.chat, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Chat • ${widget.peerUsername}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.close,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (ctx, idx) {
                final msg = _messages[idx];
                if (msg.isSystem) {
                  return Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : Colors.black12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        msg.text,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    ),
                  );
                }

                final bubbleColor = msg.isSelf
                    ? (isDark ? AppColors.bubbleOutgoingDark : AppColors.bubbleOutgoingLight)
                    : (isDark ? AppColors.bubbleIncomingDark : AppColors.bubbleIncomingLight);

                final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

                return Align(
                  alignment: msg.isSelf ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(12),
                        topRight: const Radius.circular(12),
                        bottomLeft: Radius.circular(msg.isSelf ? 12 : 2),
                        bottomRight: Radius.circular(msg.isSelf ? 2 : 12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          msg.isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        if (!msg.isSelf && msg.sender.isNotEmpty) ...[
                          Text(
                            msg.sender,
                            style: const TextStyle(
                              color: AppColors.primaryLight,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          msg.text,
                          style: TextStyle(color: textColor, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${msg.time.hour.toString().padLeft(2, '0')}:${msg.time.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                            if (msg.isSelf) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.done_all,
                                size: 13,
                                color: Color(0xFF00E676),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: 'Type message...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: isDark ? AppColors.surfaceDark : Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: AppColors.primary,
                radius: 22,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 18),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
