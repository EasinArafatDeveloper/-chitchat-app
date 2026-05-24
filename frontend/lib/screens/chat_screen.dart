import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../config.dart';

class ChatScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String? userProfilePic;
  final bool isOnline;

  const ChatScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.userProfilePic,
    required this.isOnline,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _typingTimer;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      
      // Set active chat user
      chatProvider.setActiveChatUser(widget.userId);
      // Fetch messages history
      chatProvider.fetchMessages(widget.userId, authProvider.token!);
      
      // Setup auto-scroll when messages load
      _scrollToBottomDelayed();
    });
  }

  @override
  void dispose() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.setActiveChatUser(null);
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _scrollToBottomDelayed() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.sendMessage(widget.userId, text);
    
    _messageController.clear();
    _onTextChanged(''); // Stop typing status
    
    // Auto-scroll after sending message
    _scrollToBottomDelayed();
  }

  // Handle typing indicator trigger
  void _onTextChanged(String text) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    if (text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      chatProvider.sendTypingStatus(widget.userId, true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        _isTyping = false;
        chatProvider.sendTypingStatus(widget.userId, false);
      }
    });
  }

  Widget _buildAvatar(String? path, String name) {
    if (path == null || path.isEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: const Color(0xFF6C63FF).withOpacity(0.2),
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Color(0xFF8B80F9),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      );
    }

    final imageUrl = path.startsWith('http') ? path : '${AppConfig.baseUrl}$path';

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: 36,
        height: 36,
        fit: BoxFit.cover,
        placeholder: (context, url) => CircleAvatar(
          radius: 18,
          backgroundColor: Colors.grey[900],
          child: const SizedBox(
            height: 12,
            width: 12,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF6C63FF)),
          ),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: 18,
          backgroundColor: Colors.grey[800],
          child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildMessageStatusIcon(String status) {
    if (status == 'sent') {
      return const Icon(Icons.check, size: 12, color: Colors.white30);
    } else if (status == 'delivered') {
      return const Icon(Icons.done_all, size: 12, color: Colors.white30);
    } else if (status == 'seen') {
      return const Icon(Icons.done_all, size: 12, color: Color(0xFF8B80F9));
    }
    return const SizedBox.shrink();
  }

  String _formatTime(String? timeString) {
    if (timeString == null) return '';
    try {
      final dateTime = DateTime.parse(timeString).toLocal();
      return DateFormat('hh:mm a').format(dateTime);
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    
    final currentUserId = authProvider.user?['id']?.toString() ?? authProvider.user?['_id']?.toString() ?? '';
    final messages = chatProvider.getMessagesForUser(widget.userId);
    final isTyping = chatProvider.isUserTyping(widget.userId);

    // Auto-scroll when new messages arrive
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final position = _scrollController.position;
        // Scroll to bottom if we are already close to the bottom
        if (position.maxScrollExtent - position.pixels < 300) {
          _scrollController.jumpTo(position.maxScrollExtent);
        }
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0F0C20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF15102A),
        elevation: 0,
        leadingWidth: 44,
        titleSpacing: 0,
        title: Row(
          children: [
            _buildAvatar(widget.userProfilePic, widget.userName),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.userName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  isTyping 
                      ? 'typing...' 
                      : (widget.isOnline ? 'Online' : 'Offline'),
                  style: TextStyle(
                    fontSize: 11,
                    color: isTyping 
                        ? const Color(0xFF8B80F9)
                        : (widget.isOnline ? Colors.greenAccent[400] : Colors.white30),
                    fontWeight: isTyping || widget.isOnline ? FontWeight.bold : FontWeight.normal
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Message Thread List View
          Expanded(
            child: chatProvider.isLoadingMessages && messages.isEmpty
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final sender = message['sender'];
                      final String senderId = (sender is Map)
                          ? (sender['_id']?.toString() ?? '')
                          : (sender?.toString() ?? '');
                      final isMe = senderId == currentUserId;
                      final text = message['text'] ?? '';
                      
                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8, top: 4),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isMe 
                                ? const Color(0xFF6C63FF) 
                                : Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                              bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                text,
                                style: const TextStyle(color: Colors.white, fontSize: 15),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatTime(message['createdAt']),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.4),
                                      fontSize: 10,
                                    ),
                                  ),
                                  if (isMe) ...[
                                    const SizedBox(width: 4),
                                    _buildMessageStatusIcon(message['status'] ?? 'sent'),
                                  ]
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          // Typing status banner
          if (isTyping)
            Container(
              padding: const EdgeInsets.only(left: 20, bottom: 8),
              alignment: Alignment.centerLeft,
              child: Text(
                '${widget.userName} is typing...',
                style: const TextStyle(color: Color(0xFF8B80F9), fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),

          // Message Input Field Box
          Container(
            padding: const EdgeInsets.only(left: 14, right: 14, bottom: 20, top: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF15102A),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Type your message...',
                        hintStyle: TextStyle(color: Colors.white30),
                        border: InputBorder.none,
                      ),
                      onChanged: _onTextChanged,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF6C63FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 20,
                    ),
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
