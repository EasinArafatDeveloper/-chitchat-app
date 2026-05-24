import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../config.dart';
import 'call_screen.dart';

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

  Widget _buildAvatar(String? path, String name, {double radius = 18}) {
    if (path == null || path.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFF00A86B).withOpacity(0.1),
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            color: const Color(0xFF00A86B),
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.8,
          ),
        ),
      );
    }

    final imageUrl = path.startsWith('http') ? path : '${AppConfig.baseUrl}$path';

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        placeholder: (context, url) => CircleAvatar(
          radius: radius,
          backgroundColor: Colors.grey[100],
          child: const SizedBox(
            height: 12,
            width: 12,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF00A86B)),
          ),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: radius,
          backgroundColor: Colors.grey[200],
          child: Text(name[0].toUpperCase(), style: const TextStyle(color: Color(0xFF1E293B))),
        ),
      ),
    );
  }

  Widget _buildMessageStatusIcon(String status) {
    if (status == 'sent') {
      return const Icon(Icons.check, size: 13, color: Colors.white60);
    } else if (status == 'delivered') {
      return const Icon(Icons.done_all, size: 13, color: Colors.white60);
    } else if (status == 'seen') {
      return const Icon(Icons.done_all, size: 13, color: Colors.white);
    }
    return const SizedBox.shrink();
  }

  String _formatTime(String? timeString) {
    if (timeString == null) return '';
    try {
      final dateTime = DateTime.parse(timeString).toLocal();
      return DateFormat('h:mm a').format(dateTime);
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
        if (position.maxScrollExtent - position.pixels < 300) {
          _scrollController.jumpTo(position.maxScrollExtent);
        }
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 54,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Stack(
              children: [
                _buildAvatar(widget.userProfilePic, widget.userName, radius: 18),
                if (widget.isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00A86B),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.userName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    isTyping 
                        ? 'typing...' 
                        : (widget.isOnline ? 'Online' : 'Offline'),
                    style: TextStyle(
                      fontSize: 11,
                      color: isTyping 
                          ? const Color(0xFF00A86B)
                          : (widget.isOnline ? const Color(0xFF00A86B) : const Color(0xFF64748B)),
                      fontWeight: isTyping || widget.isOnline ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Audio Call icon -> triggers CallScreen
          IconButton(
            icon: const Icon(Icons.phone_rounded, color: Color(0xFF00A86B)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CallScreen(name: widget.userName, isVideo: false),
                ),
              );
            },
          ),
          // Video Call icon -> triggers CallScreen
          IconButton(
            icon: const Icon(Icons.videocam_rounded, color: Color(0xFF00A86B)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CallScreen(name: widget.userName, isVideo: true),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Message Thread List View
          Expanded(
            child: chatProvider.isLoadingMessages && messages.isEmpty
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00A86B)))
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

                      // Simple date separator helper
                      final bool isFirstMessage = index == 0;
                      
                      return Column(
                        children: [
                          if (isFirstMessage)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: const Text(
                                    'Today',
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Row(
                              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (!isMe) ...[
                                  _buildAvatar(widget.userProfilePic, widget.userName, radius: 14),
                                  const SizedBox(width: 8),
                                ],
                                Flexible(
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 8, top: 4),
                                    constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isMe 
                                          ? const Color(0xFF00A86B) 
                                          : Colors.white,
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(18),
                                        topRight: const Radius.circular(18),
                                        bottomLeft: isMe ? const Radius.circular(18) : Radius.zero,
                                        bottomRight: isMe ? Radius.zero : const Radius.circular(18),
                                      ),
                                      border: isMe 
                                          ? null 
                                          : Border.all(color: const Color(0xFFE2E8F0)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.02),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          text,
                                          style: TextStyle(
                                            color: isMe ? Colors.white : const Color(0xFF1E293B),
                                            fontSize: 14.5,
                                            height: 1.3,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _formatTime(message['createdAt']),
                                              style: TextStyle(
                                                color: isMe 
                                                    ? Colors.white.withOpacity(0.7) 
                                                    : const Color(0xFF64748B),
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
                                ),
                              ],
                            ),
                          ),
                        ],
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
                style: const TextStyle(
                  color: Color(0xFF00A86B),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          // Message Input Field Box - Styled matching Mockup 1
          Container(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 24, top: 12),
            color: Colors.white,
            child: Row(
              children: [
                // Rounded Pill Container
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        // Plus (+) attachment icon
                        IconButton(
                          icon: const Icon(Icons.add, color: Color(0xFF64748B)),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Attachments functionality not enabled in this demo.')),
                            );
                          },
                        ),
                        // Emoji icon
                        IconButton(
                          icon: const Icon(Icons.emoji_emotions_outlined, color: Color(0xFF64748B)),
                          onPressed: () {},
                        ),
                        // Text field input
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            style: const TextStyle(color: Color(0xFF1E293B)),
                            onChanged: _onTextChanged,
                            decoration: const InputDecoration(
                              hintText: 'Type a message...',
                              hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 15),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        // Microphone icon inside pill
                        IconButton(
                          icon: const Icon(Icons.mic, color: Color(0xFF64748B)),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Audio recording is not supported in this demo.')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                
                // Separate Send Button (Circular Emerald Green with paper plane)
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF00A86B),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send_rounded,
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
