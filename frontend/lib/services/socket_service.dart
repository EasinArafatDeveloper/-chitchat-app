import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config.dart';

class SocketService {
  io.Socket? _socket;

  // Initialize and connect socket
  void connect(String token, {
    required Function(Map<String, dynamic>) onMessageReceived,
    required Function(String senderId, bool isTyping) onTypingStatusChanged,
    required Function(String userId, bool isOnline, DateTime? lastSeen) onUserStatusChanged,
    Function(dynamic)? onConnectError,
  }) {
    if (_socket != null && _socket!.connected) {
      return;
    }

    _socket = io.io(AppConfig.baseUrl, io.OptionBuilder()
      .setTransports(['websocket']) // Use WebSocket transport only
      .disableAutoConnect()
      .setAuth({'token': token})
      .build()
    );

    // Socket listeners
    _socket!.onConnect((_) {
      print('Socket connected: ${_socket!.id}');
    });

    _socket!.onConnectError((data) {
      print('Socket connect error: $data');
      if (onConnectError != null) onConnectError(data);
    });

    _socket!.onDisconnect((_) {
      print('Socket disconnected');
    });

    // Real-time message receiver
    _socket!.on('receive_message', (data) {
      if (data != null) {
        onMessageReceived(Map<String, dynamic>.from(data));
      }
    });

    // Real-time typing status receiver
    _socket!.on('typing_status', (data) {
      if (data != null) {
        final senderId = data['senderId']?.toString() ?? '';
        final isTyping = data['isTyping'] as bool? ?? false;
        onTypingStatusChanged(senderId, isTyping);
      }
    });

    // Real-time online presence status receiver
    _socket!.on('user_status', (data) {
      if (data != null) {
        final userId = data['userId']?.toString() ?? '';
        final isOnline = data['isOnline'] as bool? ?? false;
        final lastSeenRaw = data['lastSeen'];
        final lastSeen = lastSeenRaw != null 
            ? DateTime.fromMillisecondsSinceEpoch(lastSeenRaw)
            : null;
        
        onUserStatusChanged(userId, isOnline, lastSeen);
      }
    });

    _socket!.connect();
  }

  // Send message
  void sendMessage({
    required String receiverId,
    String? text,
    String? messageType,
    String? mediaUrl,
    required Function(Map<String, dynamic> msg) onConfirmation,
  }) {
    if (_socket == null || !_socket!.connected) {
      print('Cannot send message: Socket is not connected');
      return;
    }

    _socket!.emitWithAck('send_message', {
      'receiverId': receiverId,
      'text': text ?? '',
      'messageType': messageType ?? 'text',
      'mediaUrl': mediaUrl ?? '',
    }, ack: (data) {
      if (data != null && data['success'] == true) {
        onConfirmation(Map<String, dynamic>.from(data['message']));
      } else {
        print('Message send acknowledgment error: $data');
      }
    });
  }

  // Emit typing status
  void emitTyping({required String receiverId, required bool isTyping}) {
    if (_socket == null || !_socket!.connected) return;
    _socket!.emit('typing', {
      'receiverId': receiverId,
      'isTyping': isTyping,
    });
  }

  // Disconnect socket
  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
    }
  }

  bool get isConnected => _socket?.connected ?? false;
}
