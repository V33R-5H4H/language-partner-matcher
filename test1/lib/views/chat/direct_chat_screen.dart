import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/local/database_helper.dart';
import '../../providers/auth_provider.dart';
import '../../services/websocket_service.dart';
import '../call/outgoing_call_dialog.dart';

class DirectChatScreen extends StatefulWidget {
  final String peerId;
  final String peerName;
  final String language;

  const DirectChatScreen({
    super.key,
    required this.peerId,
    required this.peerName,
    this.language = 'Spanish',
  });

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _wsSubscription;
  List<Map<String, dynamic>> _messages = [];
  bool _isPartnerTyping = false;
  Timer? _typingDebounce;
  bool _isLocalTyping = false;

  @override
  void initState() {
    super.initState();
    DatabaseHelper.instance.directChatsNotifier.addListener(_onChatsUpdated);
    _loadMessages();
    _listenForIncomingMessages();
    _sendReadReceipt();
  }

  void _sendReadReceipt() {
    WebSocketService.instance.send({
      'type': 'read_receipt',
      'peer_id': widget.peerId,
    });
    DatabaseHelper.instance.markMessagesAsRead(widget.peerId);
  }

  void _onChatsUpdated() {
    if (mounted) {
      _loadMessages();
    }
  }

  void _loadMessages() {
    setState(() {
      _messages = DatabaseHelper.instance.getDirectMessages(widget.peerId);
    });
    _scrollToBottom();
  }

  void _onTextChanged(String text) {
    if (text.isNotEmpty && !_isLocalTyping) {
      _isLocalTyping = true;
      WebSocketService.instance.send({
        'type': 'typing_status',
        'peer_id': widget.peerId,
        'is_typing': true,
      });
    }

    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 1800), () {
      if (_isLocalTyping) {
        _isLocalTyping = false;
        WebSocketService.instance.send({
          'type': 'typing_status',
          'peer_id': widget.peerId,
          'is_typing': false,
        });
      }
    });
  }

  void _listenForIncomingMessages() {
    _wsSubscription = WebSocketService.instance.messages.listen((event) {
      if (!mounted) return;
      final type = event['type'];

      if (type == 'chat_message') {
        final fromPeerId = (event['from'] ?? event['peer_id'] ?? '').toString();
        if (fromPeerId == widget.peerId || fromPeerId.isNotEmpty) {
          final msgId = event['id']?.toString() ?? 'msg_${DateTime.now().millisecondsSinceEpoch}';
          final text = event['text']?.toString() ?? '';
          final time = event['time']?.toString() ?? DateTime.now().toIso8601String();

          DatabaseHelper.instance.saveDirectMessage(
            peerId: widget.peerId,
            peerName: widget.peerName,
            id: msgId,
            text: text,
            time: time,
            isSelf: false,
          );

          // Acknowledge receipt
          _sendReadReceipt();
        }
      } else if (type == 'typing_status') {
        final from = (event['from'] ?? event['peer_id'] ?? '').toString();
        if (from == widget.peerId || from.isNotEmpty) {
          setState(() {
            _isPartnerTyping = event['is_typing'] == true;
          });
        }
      } else if (type == 'read_receipt') {
        final from = (event['from'] ?? event['peer_id'] ?? '').toString();
        if (from == widget.peerId || from.isNotEmpty) {
          DatabaseHelper.instance.markMessagesAsRead(widget.peerId);
        }
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

    final msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    final timeStr = DateTime.now().toIso8601String();

    // 1. Send via WebSocket to peer
    WebSocketService.instance.send({
      'type': 'chat_message',
      'id': msgId,
      'peer_id': widget.peerId,
      'text': text,
      'time': timeStr,
      'sender': Provider.of<AuthProvider>(context, listen: false).currentUser.username,
    });

    // Reset typing status
    if (_isLocalTyping) {
      _isLocalTyping = false;
      WebSocketService.instance.send({
        'type': 'typing_status',
        'peer_id': widget.peerId,
        'is_typing': false,
      });
    }

    // 2. Persist in local storage
    DatabaseHelper.instance.saveDirectMessage(
      peerId: widget.peerId,
      peerName: widget.peerName,
      id: msgId,
      text: text,
      time: timeStr,
      isSelf: true,
      status: 'sent',
    );

    _messageController.clear();
    _loadMessages();
  }

  void _startDirectCall({required bool isAudioOnly}) {
    OutgoingCallDialog.show(
      context,
      peerId: widget.peerId,
      peerName: widget.peerName,
      targetLanguage: widget.language,
      isAudioOnly: isAudioOnly,
    );
  }

  void _showVocabularyModal(String text) {
    final words = text
        .replaceAll(RegExp(r'[^\w\s\u00C0-\u017F]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.trim().isNotEmpty)
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        String? selectedWord = words.isNotEmpty ? words.first : text;
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: Colors.white12),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.translate, color: AppColors.primaryLight, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Practice Translation & Vocabulary',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Select a word from this message to save to your Vocabulary List:',
                    style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: words.map((w) {
                      final isSelected = w == selectedWord;
                      return ChoiceChip(
                        label: Text(w, style: TextStyle(color: isSelected ? Colors.white : AppColors.textSecondaryDark)),
                        selected: isSelected,
                        selectedColor: AppColors.primaryDark,
                        backgroundColor: AppColors.cardDark,
                        onSelected: (_) {
                          setModalState(() => selectedWord = w);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  if (selectedWord != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryDark.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedWord!,
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Language: ${widget.language} • Context: "$text"',
                                  style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryDark,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              await DatabaseHelper.instance.insertVocabulary({
                                'word': selectedWord,
                                'translation': 'Learned in practice chat',
                                'language': widget.language,
                                'context': text,
                              });
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Saved "$selectedWord" to Vocabulary List! 📚'),
                                    backgroundColor: AppColors.primaryDark,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.bookmark_add, size: 16),
                            label: const Text('Save', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    DatabaseHelper.instance.directChatsNotifier.removeListener(_onChatsUpdated);
    _typingDebounce?.cancel();
    _wsSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        elevation: 1,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primaryDark,
              child: Text(
                widget.peerName.isNotEmpty ? widget.peerName[0].toUpperCase() : 'P',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.peerName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    _isPartnerTyping
                        ? 'typing...'
                        : 'Practice Partner • ${widget.language}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: _isPartnerTyping ? FontWeight.bold : FontWeight.normal,
                      color: _isPartnerTyping ? AppColors.primaryLight : AppColors.textSecondaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic, color: AppColors.primaryLight),
            tooltip: 'Voice Call',
            onPressed: () => _startDirectCall(isAudioOnly: true),
          ),
          IconButton(
            icon: const Icon(Icons.videocam, color: AppColors.primaryLight),
            tooltip: 'Video Call',
            onPressed: () => _startDirectCall(isAudioOnly: false),
          ),
        ],
      ),
      body: Column(
        children: [
          // Message Thread List
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Messages and calls are end-to-end encrypted.\nSay hi to start your language practice!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12, height: 1.4),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, idx) {
                      final msg = _messages[idx];
                      final isSelf = msg['isSelf'] == true;
                      final status = msg['status'] ?? 'sent';
                      final timeStr = msg['time']?.toString() ?? '';
                      final dt = DateTime.tryParse(timeStr) ?? DateTime.now();
                      final formattedTime =
                          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

                      final bubbleColor =
                          isSelf ? AppColors.bubbleOutgoingDark : AppColors.bubbleIncomingDark;

                      return GestureDetector(
                        onLongPress: () => _showVocabularyModal(msg['text'] ?? ''),
                        onTap: () => _showVocabularyModal(msg['text'] ?? ''),
                        child: Align(
                          alignment: isSelf ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.75,
                            ),
                            decoration: BoxDecoration(
                              color: bubbleColor,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(12),
                                topRight: const Radius.circular(12),
                                bottomLeft: Radius.circular(isSelf ? 12 : 2),
                                bottomRight: Radius.circular(isSelf ? 2 : 12),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  msg['text'] ?? '',
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      formattedTime,
                                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondaryDark),
                                    ),
                                    if (isSelf) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        status == 'read' ? Icons.done_all : (status == 'delivered' ? Icons.done_all : Icons.check),
                                        size: 13,
                                        color: const Color(0xFF00E676),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Message Input Field (WhatsApp Style)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: AppColors.surfaceDark,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onChanged: _onTextChanged,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Type a message in ${widget.language}...',
                      hintStyle: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.cardDark,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppColors.primaryDark,
                  radius: 22,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
