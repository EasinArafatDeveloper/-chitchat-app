import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
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
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();
  
  Timer? _typingTimer;
  bool _isTyping = false;
  bool _showEmojiPicker = false;
  bool _isUploadingMedia = false;

  final List<String> _emojis = [
    '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣', '😊', '😇',
    '🙂', '🙃', '😉', '😌', '😍', '🥰', '😘', '😗', '😙', '😚',
    '😋', '😛', '😝', '😜', '🤪', '🤨', '🧐', '🤓', '😎', '🤩',
    '🥳', '😏', '😒', '😞', '😔', '😟', '😕', '🙁', '☹️', '😣',
    '😖', '😫', '😩', '🥺', '😢', '😭', '😤', '😠', '😡', '🤬',
    '👍', '👎', '👌', '✌️', '👋', '👏', '🙌', '🙏', '❤️', '🔥'
  ];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _showEmojiPicker = false;
        });
        _scrollToBottomDelayed();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      
      // Set active chat user
      chatProvider.setActiveChatUser(widget.userId);
      // Fetch messages history
      chatProvider.fetchMessages(widget.userId, authProvider.token!);
      
      _scrollToBottomDelayed();
    });
  }

  @override
  void dispose() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.setActiveChatUser(null);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
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

  // Pick image from gallery and send
  Future<void> _pickAndSendImage() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _isUploadingMedia = true;
        });

        final success = await chatProvider.sendImageMessage(
          widget.userId,
          File(image.path),
        );

        setState(() {
          _isUploadingMedia = false;
        });

        if (success) {
          _scrollToBottomDelayed();
        } else {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Failed to upload image. Please try again.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      print('Pick image error: $e');
      setState(() {
        _isUploadingMedia = false;
      });
    }
  }

  // Open simulated voice recording bottom sheet
  void _showVoiceRecorder() {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return VoiceRecordSheet(
          onRecordComplete: (recordedFile) async {
            Navigator.of(context).pop();
            setState(() {
              _isUploadingMedia = true;
            });

            final success = await chatProvider.sendAudioMessage(
              widget.userId,
              recordedFile,
            );

            setState(() {
              _isUploadingMedia = false;
            });

            if (success) {
              _scrollToBottomDelayed();
            } else {
              scaffoldMessenger.showSnackBar(
                const SnackBar(
                  content: Text('Failed to upload voice message. Please try again.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          },
        );
      },
    );
  }

  void _onEmojiSelected(String emoji) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    String newText;
    int newOffset;

    if (selection.start >= 0) {
      newText = text.replaceRange(selection.start, selection.end, emoji);
      newOffset = selection.start + emoji.length;
    } else {
      newText = text + emoji;
      newOffset = newText.length;
    }

    _messageController.text = newText;
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: newOffset),
    );
    _onTextChanged(newText);
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

  Widget _buildReceivedMessageStatusIcon(String status) {
    if (status == 'seen') {
      return const Icon(Icons.done_all, size: 13, color: Color(0xFF00A86B));
    }
    return const Icon(Icons.done_all, size: 13, color: Color(0xFF94A3B8));
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

  Widget _buildEmojiPicker() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: _showEmojiPicker ? 240 : 0,
      color: Colors.white,
      child: Column(
        children: [
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _emojis.length,
              itemBuilder: (context, index) {
                return InkWell(
                  onTap: () => _onEmojiSelected(_emojis[index]),
                  child: Center(
                    child: Text(
                      _emojis[index],
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
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
      body: Stack(
        children: [
          Column(
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
                          final msgType = message['messageType'] ?? 'text';
                          final mediaUrl = message['mediaUrl'] ?? '';
                          
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
                                          maxWidth: MediaQuery.of(context).size.width * 0.72,
                                        ),
                                        padding: msgType == 'image' 
                                            ? const EdgeInsets.all(4)
                                            : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                                            // 1. Text Message
                                            if (msgType == 'text')
                                              Text(
                                                text,
                                                style: TextStyle(
                                                  color: isMe ? Colors.white : const Color(0xFF1E293B),
                                                  fontSize: 14.5,
                                                  height: 1.3,
                                                ),
                                              ),
                                            
                                            // 2. Image Message
                                            if (msgType == 'image' && mediaUrl.isNotEmpty)
                                              _buildImageBubble(mediaUrl, isMe),

                                            // 3. Audio / Voice Message
                                            if (msgType == 'audio' && mediaUrl.isNotEmpty)
                                              AudioBubblePlayer(
                                                mediaUrl: mediaUrl,
                                                isMe: isMe,
                                              ),

                                            const SizedBox(height: 4),
                                            
                                            // Message details time footer
                                            Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: msgType == 'image' ? 8.0 : 0.0,
                                                vertical: msgType == 'image' ? 4.0 : 0.0
                                              ),
                                              child: Row(
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
                                                  ] else ...[
                                                    const SizedBox(width: 4),
                                                    _buildReceivedMessageStatusIcon(message['status'] ?? 'sent'),
                                                  ]
                                                ],
                                              ),
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
                            // Plus (+) attachment image share picker
                            IconButton(
                              icon: const Icon(Icons.add, color: Color(0xFF64748B)),
                              onPressed: _pickAndSendImage,
                            ),
                            // Emoji picker toggle icon
                            IconButton(
                              icon: Icon(
                                _showEmojiPicker ? Icons.keyboard_alt_outlined : Icons.emoji_emotions_outlined, 
                                color: const Color(0xFF64748B)
                              ),
                              onPressed: () {
                                if (_showEmojiPicker) {
                                  _focusNode.requestFocus();
                                } else {
                                  _focusNode.unfocus();
                                  setState(() {
                                    _showEmojiPicker = true;
                                  });
                                }
                              },
                            ),
                            // Text field input
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                focusNode: _focusNode,
                                style: const TextStyle(color: Color(0xFF1E293B)),
                                onChanged: _onTextChanged,
                                decoration: const InputDecoration(
                                  hintText: 'Type a message...',
                                  hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 15),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                                ),
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                            // Microphone icon inside pill
                            IconButton(
                              icon: const Icon(Icons.mic, color: Color(0xFF64748B)),
                              onPressed: _showVoiceRecorder,
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
              _buildEmojiPicker(),
            ],
          ),
          
          // Image / Media Upload loading indicator overlay
          if (_isUploadingMedia)
            Container(
              color: Colors.black.withOpacity(0.2),
              child: const Center(
                child: Card(
                  color: Colors.white,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF00A86B)),
                        SizedBox(width: 16),
                        Text(
                          'Sharing file...',
                          style: TextStyle(
                            color: Color(0xFF1E293B),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageBubble(String path, bool isMe) {
    final imageUrl = path.startsWith('http') ? path : '${AppConfig.baseUrl}$path';

    return GestureDetector(
      onTap: () {
        // Show fullscreen image view dialog
        showDialog(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(8),
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                InteractiveViewer(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: CircleAvatar(
                    backgroundColor: Colors.black45,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: 220,
          height: 180,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 220,
            height: 180,
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(color: Color(0xFF00A86B), strokeWidth: 2),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            width: 220,
            height: 180,
            color: Colors.grey[300],
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_rounded, color: Colors.grey, size: 40),
                SizedBox(height: 8),
                Text('Image failed to load', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Stateful Widget representing the interactive custom Audio Wave bubble player
class AudioBubblePlayer extends StatefulWidget {
  final String mediaUrl;
  final bool isMe;

  const AudioBubblePlayer({
    super.key,
    required this.mediaUrl,
    required this.isMe,
  });

  @override
  State<AudioBubblePlayer> createState() => _AudioBubblePlayerState();
}

class _AudioBubblePlayerState extends State<AudioBubblePlayer> {
  bool _isPlaying = false;
  double _playPercent = 0.0;
  Timer? _timer;
  int _secondsPassed = 0;
  final int _totalSeconds = 14; // Mock standard 0:14 duration from screenshot

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _togglePlay() {
    if (_isPlaying) {
      _timer?.cancel();
      setState(() {
        _isPlaying = false;
      });
    } else {
      setState(() {
        _isPlaying = true;
      });
      _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        setState(() {
          _playPercent += 0.1 / _totalSeconds;
          if (timer.tick % 10 == 0) {
            _secondsPassed++;
          }
          if (_playPercent >= 1.0) {
            _playPercent = 0.0;
            _secondsPassed = 0;
            _isPlaying = false;
            _timer?.cancel();
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.isMe ? Colors.white : const Color(0xFF00A86B);
    final inactiveColor = widget.isMe ? Colors.white.withOpacity(0.3) : const Color(0xFFCBD5E1);

    // Dynamic wave bar heights
    final List<double> barHeights = [
      12, 22, 14, 30, 24, 38, 16, 26, 32, 14, 18, 30, 22, 16, 8
    ];

    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Play button
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.isMe ? Colors.white : const Color(0xFF00A86B),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow_rounded,
                color: widget.isMe ? const Color(0xFF00A86B) : Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 10),
          
          // Simulated Waveform visualizer progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(barHeights.length, (index) {
                      // Determine if this bar is reached in the progress
                      final double barWeight = index / barHeights.length;
                      final bool isHighlighted = _playPercent > barWeight;
                      
                      return Container(
                        width: 3.5,
                        height: barHeights[index],
                        decoration: BoxDecoration(
                          color: isHighlighted ? activeColor : inactiveColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 2),
                // Duration track
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '0:${_secondsPassed.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 9,
                        color: widget.isMe ? Colors.white.withOpacity(0.8) : const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      '0:${_totalSeconds}',
                      style: TextStyle(
                        fontSize: 9,
                        color: widget.isMe ? Colors.white.withOpacity(0.8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Simulated Voice Recording sheet drawer
class VoiceRecordSheet extends StatefulWidget {
  final Function(File) onRecordComplete;

  const VoiceRecordSheet({super.key, required this.onRecordComplete});

  @override
  State<VoiceRecordSheet> createState() => _VoiceRecordSheetState();
}

class _VoiceRecordSheetState extends State<VoiceRecordSheet> {
  Timer? _timer;
  int _seconds = 0;
  final List<double> _visualizerBars = List.filled(18, 5.0);
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _startRecordingSim();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startRecordingSim() {
    _timer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      setState(() {
        if (timer.tick % 6.6 == 0) {
          _seconds++;
        }
        // Randomize heights to simulate mic input values
        for (var i = 0; i < _visualizerBars.length; i++) {
          _visualizerBars[i] = _random.nextDouble() * 38 + 6;
        }
      });
    });
  }

  String _formatTime(int sec) {
    final min = sec ~/ 60;
    final remaining = sec % 60;
    return '${min.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
  }

  Future<void> _sendRecording() async {
    _timer?.cancel();
    try {
      // Write mock WAV header or simple text payload to a temp voice.mp3 file
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/temp_voice_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await file.writeAsString('Simulated voice recording data');
      
      widget.onRecordComplete(file);
    } catch (e) {
      print('Save mock voice error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      height: 250,
      decoration: const BoxDecoration(
        color: Color(0xFFF4FAF8),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Recording voice message...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _formatTime(_seconds),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00A86B),
            ),
          ),
          const SizedBox(height: 24),
          
          // Simulated Wave visualizer lines
          SizedBox(
            height: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_visualizerBars.length, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 4,
                  height: _visualizerBars[index],
                  decoration: BoxDecoration(
                    color: const Color(0xFF00A86B),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 20),
          
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 28, color: Colors.redAccent),
                onPressed: () => Navigator.of(context).pop(),
              ),
              GestureDetector(
                onTap: _sendRecording,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF00A86B),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
