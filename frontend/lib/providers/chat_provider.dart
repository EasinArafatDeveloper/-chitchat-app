import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class ChatProvider extends ChangeNotifier {
  final SocketService _socketService = SocketService();
  
  String? _token;
  List<dynamic> _conversations = [];
  final Map<String, List<dynamic>> _messages = {};
  final Map<String, bool> _typingStatuses = {};
  
  bool _isLoadingConversations = false;
  bool _isLoadingMessages = false;
  String? _activeChatUserId;

  List<dynamic> get conversations => _conversations;
  bool get isLoadingConversations => _isLoadingConversations;
  bool get isLoadingMessages => _isLoadingMessages;
  String? get activeChatUserId => _activeChatUserId;

  List<dynamic> getMessagesForUser(String userId) {
    return _messages[userId] ?? [];
  }

  bool isUserTyping(String userId) {
    return _typingStatuses[userId] ?? false;
  }

  // Set active chat screen user (so we know when to mark messages as read / play sounds)
  void setActiveChatUser(String? userId) {
    _activeChatUserId = userId;
    if (userId != null) {
      _typingStatuses[userId] = false;
    }
  }

  // Initialize socket connection and configure listeners
  void initSocket(String token) {
    _token = token;
    _socketService.connect(
      token,
      onMessageReceived: (message) {
        final sender = message['sender'];
        final senderId = (sender is Map) ? (sender['_id']?.toString() ?? '') : (sender?.toString() ?? '');
        final receiver = message['receiver'];
        final receiverId = (receiver is Map) ? (receiver['_id']?.toString() ?? '') : (receiver?.toString() ?? '');
        
        // Find which list to add to (if it's incoming or outgoing)
        final otherUserId = senderId == _activeChatUserId ? senderId : (receiverId == _activeChatUserId ? receiverId : senderId);
        
        if (otherUserId.isNotEmpty) {
          if (!_messages.containsKey(otherUserId)) {
            _messages[otherUserId] = [];
          }
          _messages[otherUserId]!.add(message);
        }

        // Auto-refresh conversations list to show last message
        _updateConversationListWithMessage(message);
        
        notifyListeners();
      },
      onTypingStatusChanged: (senderId, isTyping) {
        _typingStatuses[senderId] = isTyping;
        notifyListeners();
      },
      onUserStatusChanged: (userId, isOnline, lastSeen) {
        // Update user status in conversations list
        for (var i = 0; i < _conversations.length; i++) {
          if (_conversations[i]['user']['_id']?.toString() == userId) {
            _conversations[i]['user']['isOnline'] = isOnline;
            if (lastSeen != null) {
              _conversations[i]['user']['lastSeen'] = lastSeen.toIso8601String();
            }
            break;
          }
        }
        notifyListeners();
      },
    );
  }

  // Helper to dynamically update the dashboard conversations list when a new message is received
  void _updateConversationListWithMessage(Map<String, dynamic> message) {
    final sender = message['sender'];
    final senderId = (sender is Map) ? (sender['_id']?.toString() ?? '') : (sender?.toString() ?? '');
    final receiver = message['receiver'];
    final receiverId = (receiver is Map) ? (receiver['_id']?.toString() ?? '') : (receiver?.toString() ?? '');
    
    // We want the other user's ID
    // If sender is me, other user is receiver. If sender is not me, other user is sender.
    // To check this, we check message['sender']['_id'] etc.
    // If it's a simple string, we check that. Let's see who is who.
    // To do this reliably, we'll fetch conversations from API if it's a completely new chat.
    // For now, let's update if conversation already exists, or fetch all.
    bool found = false;
    for (var i = 0; i < _conversations.length; i++) {
      final user = _conversations[i]['user'];
      final userId = user['_id']?.toString() ?? '';
      
      if (userId == senderId || userId == receiverId) {
        _conversations[i]['lastMessage'] = message;
        if (userId == senderId && _activeChatUserId != senderId) {
          _conversations[i]['unreadCount'] = (_conversations[i]['unreadCount'] ?? 0) + 1;
        }
        
        // Move this conversation to the top
        final item = _conversations.removeAt(i);
        _conversations.insert(0, item);
        found = true;
        break;
      }
    }

    if (!found) {
      // Re-fetch conversations list to handle new chats
      fetchConversations(_token); 
    }
  }

  // Fetch conversations list from HTTP API
  Future<void> fetchConversations(String? token) async {
    if (token == null && _socketService.isConnected) {
      // If we don't have token but socket is active, we don't reload unless requested
    }
    
    _isLoadingConversations = true;
    notifyListeners();

    try {
      // Since ApiService requires token, we use a simple hack: we don't fetch if no token.
      // But we can store the token locally or retrieve it from AuthProvider.
      // Let's pass the token from screens where we call fetchConversations.
      if (token == null) {
        _isLoadingConversations = false;
        notifyListeners();
        return;
      }

      final response = await ApiService.getConversations(token);
      if (response.statusCode == 200) {
        _conversations = jsonDecode(response.body);
      }
    } catch (e) {
      print('Error fetching conversations: $e');
    } finally {
      _isLoadingConversations = false;
      notifyListeners();
    }
  }

  // Fetch messages with a user
  Future<void> fetchMessages(String otherUserId, String token) async {
    _isLoadingMessages = true;
    notifyListeners();

    try {
      final response = await ApiService.getMessages(userId: otherUserId, token: token);
      if (response.statusCode == 200) {
        _messages[otherUserId] = jsonDecode(response.body);
        
        // Reset unread count for this user in conversations list
        for (var i = 0; i < _conversations.length; i++) {
          if (_conversations[i]['user']['_id']?.toString() == otherUserId) {
            _conversations[i]['unreadCount'] = 0;
            break;
          }
        }
      }
    } catch (e) {
      print('Error fetching messages: $e');
    } finally {
      _isLoadingMessages = false;
      notifyListeners();
    }
  }

  // Send message via WebSocket
  void sendMessage(String receiverId, String text) {
    if (text.trim().isEmpty) return;

    _socketService.sendMessage(
      receiverId: receiverId,
      text: text.trim(),
      onConfirmation: (savedMessage) {
        if (!_messages.containsKey(receiverId)) {
          _messages[receiverId] = [];
        }
        _messages[receiverId]!.add(savedMessage);
        
        // Update local conversation list
        _updateConversationListWithMessage(savedMessage);
        
        notifyListeners();
      },
    );
  }

  // Send typing status
  void sendTypingStatus(String receiverId, bool isTyping) {
    _socketService.emitTyping(receiverId: receiverId, isTyping: isTyping);
  }

  // Clean state on logout
  void disconnectAndClear() {
    _socketService.disconnect();
    _token = null;
    _conversations = [];
    _messages.clear();
    _typingStatuses.clear();
    _activeChatUserId = null;
    notifyListeners();
  }
}
