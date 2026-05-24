const express = require('express');
const router = express.Router();
const Message = require('../models/Message');
const User = require('../models/User');
const auth = require('../middleware/auth');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

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

// Multer storage configuration for message media
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    const dir = './uploads';
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    cb(null, dir);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, 'msg-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({
  storage: storage,
  limits: { fileSize: 15 * 1024 * 1024 }, // 15MB limit
  fileFilter: function (req, file, cb) {
    const ext = path.extname(file.originalname).toLowerCase();
    const allowedExtensions = ['.jpeg', '.jpg', '.png', '.gif', '.mp3', '.wav', '.m4a', '.aac', '.ogg', '.caf', '.3gp', '.flac'];
    if (allowedExtensions.includes(ext)) {
      return cb(null, true);
    }
    cb(new Error('Invalid file format. Only images and audio files are allowed!'));
  }
});

// @route   POST api/messages/upload-media
// @desc    Upload message attachment (image / audio)
// @access  Private
router.post('/upload-media', [auth, upload.single('media')], async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ message: 'Please upload a media file' });
  }

  try {
    const relativeUrl = `/uploads/${req.file.filename}`;
    res.json({
      mediaUrl: relativeUrl,
      message: 'Media uploaded successfully'
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error uploading media' });
  }
});

module.exports = router;
