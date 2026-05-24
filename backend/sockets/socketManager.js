const jwt = require('jsonwebtoken');
const User = require('../models/User');
const Message = require('../models/Message');

// In-memory mapping of User IDs to Socket IDs
const onlineUsers = new Map();

module.exports = function (io) {
  // Middleware to authenticate socket connections
  io.use(async (socket, next) => {
    const token = socket.handshake.auth.token || socket.handshake.query.token;

    if (!token) {
      return next(new Error('Authentication error: Token is required'));
    }

    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET || 'super_secret_jwt_key_12345');
      socket.userId = decoded.userId;
      next();
    } catch (err) {
      return next(new Error('Authentication error: Invalid token'));
    }
  });

  io.on('connection', async (socket) => {
    const userId = socket.userId;
    console.log(`User connected: ${userId} (Socket: ${socket.id})`);

    // 1. Save socket mapping
    onlineUsers.set(userId.toString(), socket.id);

    // 2. Set online status in database and notify other clients
    try {
      await User.findByIdAndUpdate(userId, { isOnline: true, lastSeen: Date.now() });
      socket.broadcast.emit('user_status', {
        userId: userId,
        isOnline: true
      });
    } catch (err) {
      console.error('Error updating user online status:', err);
    }

    // 3. Listen for real-time messages
    socket.on('send_message', async (data, callback) => {
      const { receiverId, text, messageType, mediaUrl } = data;

      if (!receiverId || (!text && !mediaUrl)) {
        if (callback) callback({ success: false, error: 'Receiver ID and text or mediaUrl are required' });
        return;
      }

      try {
        const receiverSocketId = onlineUsers.get(receiverId.toString());
        const status = receiverSocketId ? 'delivered' : 'sent';

        // Save message to MongoDB
        const newMessage = new Message({
          sender: userId,
          receiver: receiverId,
          text: text || '',
          messageType: messageType || 'text',
          mediaUrl: mediaUrl || '',
          status: status
        });
        await newMessage.save();

        // Populate sender info if needed
        const populatedMessage = await Message.findById(newMessage._id)
          .populate('sender', 'name email profilePic')
          .populate('receiver', 'name email profilePic');

        // Forward message to receiver in real-time if online
        if (receiverSocketId) {
          io.to(receiverSocketId).emit('receive_message', populatedMessage);
        }

        // Send confirmation back to sender client
        if (callback) {
          callback({
            success: true,
            message: populatedMessage
          });
        }
      } catch (err) {
        console.error('Error sending message:', err);
        if (callback) callback({ success: false, error: 'Database save error' });
      }
    });

    // 4. Listen for typing events
    socket.on('typing', (data) => {
      const { receiverId, isTyping } = data;
      const receiverSocketId = onlineUsers.get(receiverId.toString());

      if (receiverSocketId) {
        io.to(receiverSocketId).emit('typing_status', {
          senderId: userId,
          isTyping: isTyping
        });
      }
    });

    // 5. Handle user disconnect
    socket.on('disconnect', async () => {
      console.log(`User disconnected: ${userId}`);

      // Remove from online mapping
      onlineUsers.delete(userId.toString());

      // Update offline status in database and notify other clients
      try {
        const lastSeenTime = Date.now();
        await User.findByIdAndUpdate(userId, { isOnline: false, lastSeen: lastSeenTime });
        
        io.emit('user_status', {
          userId: userId,
          isOnline: false,
          lastSeen: lastSeenTime
        });
      } catch (err) {
        console.error('Error updating user offline status:', err);
      }
    });
  });
};
