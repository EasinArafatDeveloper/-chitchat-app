const express = require('express');
const router = express.Router();
const Message = require('../models/Message');
const User = require('../models/User');
const auth = require('../middleware/auth');

// @route   GET api/messages/:userId
// @desc    Get chat history between current user and another user
// @access  Private
router.get('/:userId', auth, async (req, res) => {
  const otherUserId = req.params.userId;
  const currentUserId = req.user;

  try {
    // Find all messages where:
    // (sender = A and receiver = B) OR (sender = B and receiver = A)
    const messages = await Message.find({
      $or: [
        { sender: currentUserId, receiver: otherUserId },
        { sender: otherUserId, receiver: currentUserId }
      ]
    })
    .sort({ createdAt: 1 }); // Sort chronologically

    // Update status to 'seen' for incoming messages
    await Message.updateMany(
      { sender: otherUserId, receiver: currentUserId, status: { $ne: 'seen' } },
      { $set: { status: 'seen' } }
    );

    res.json(messages);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error retrieving chat history' });
  }
});

// @route   GET api/messages/conversations/list
// @desc    Get active conversation summaries list for chat dashboard
// @access  Private
router.get('/conversations/list', auth, async (req, res) => {
  const currentUserId = req.user;

  try {
    // 1. Find all messages involving the current user
    const messages = await Message.find({
      $or: [{ sender: currentUserId }, { receiver: currentUserId }]
    })
    .sort({ createdAt: -1 }); // Newest first

    // 2. Group messages by the "other" participant to build the conversation list
    const conversationMap = new Map();

    for (const msg of messages) {
      // Determine the other user's ID
      const otherUser = msg.sender.toString() === currentUserId.toString()
        ? msg.receiver.toString()
        : msg.sender.toString();

      if (!conversationMap.has(otherUser)) {
        conversationMap.set(otherUser, msg);
      }
    }

    // 3. Populate user details for each unique chat partner
    const conversations = [];
    for (const [otherUserId, lastMsg] of conversationMap.entries()) {
      const user = await User.findById(otherUserId).select('_id name email profilePic isOnline lastSeen');
      if (user) {
        // Calculate unread count (messages sent by the other user to the current user that are not 'seen')
        const unreadCount = await Message.countDocuments({
          sender: otherUserId,
          receiver: currentUserId,
          status: { $ne: 'seen' }
        });

        conversations.push({
          user,
          lastMessage: {
            id: lastMsg._id,
            text: lastMsg.text,
            sender: lastMsg.sender,
            receiver: lastMsg.receiver,
            status: lastMsg.status,
            createdAt: lastMsg.createdAt
          },
          unreadCount
        });
      }
    }

    // Sort conversations by the date of the last message (newest first)
    conversations.sort((a, b) => b.lastMessage.createdAt - a.lastMessage.createdAt);

    res.json(conversations);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error retrieving conversations list' });
  }
});

module.exports = router;
