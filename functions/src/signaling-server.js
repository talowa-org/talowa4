const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');

// Create Express app
const app = express();
const server = http.createServer(app);

// Configure CORS
app.use(cors({
  origin: "*",
  methods: ["GET", "POST"]
}));

// Create Socket.IO server
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

// Store connected users and active calls
const connectedUsers = new Map();
const activeCalls = new Map();
const callRooms = new Map();

// TURN server configuration (you would replace with actual TURN servers)
const TURN_SERVERS = [
  {
    urls: 'stun:stun.l.google.com:19302'
  },
  {
    urls: 'turn:your-turn-server.com:3478',
    username: 'your-username',
    credential: 'your-credential'
  }
];

// Socket connection handler
io.on('connection', (socket) => {
  console.log('User connected:', socket.id);

  // Handle user authentication
  socket.on('authenticate', (data) => {
    const { userId, authToken } = data;
    
    // TODO: Validate auth token with Firebase Auth
    // For now, just store the user
    connectedUsers.set(socket.id, {
      userId,
      socketId: socket.id,
      connectedAt: Date.now()
    });

    socket.userId = userId;
    socket.join(`user_${userId}`);
    
    socket.emit('authenticated', { userId });
    console.log('User authenticated:', userId);
  });

  // Handle WebRTC offer
  socket.on('offer', (data) => {
    const { callId, offer } = data;
    const user = connectedUsers.get(socket.id);
    
    if (!user) {
      socket.emit('error', { message: 'User not authenticated' });
      return;
    }

    // Store call information
    activeCalls.set(callId, {
      callId,
      callerId: user.userId,
      offer,
      createdAt: Date.now()
    });

    // Forward offer to recipient (you would determine recipient from callId)
    // For now, broadcast to all users except sender
    socket.broadcast.emit('offer', { callId, offer });
    
    console.log('Offer sent for call:', callId);
  });

  // Handle WebRTC answer
  socket.on('answer', (data) => {
    const { callId, answer } = data;
    const user = connectedUsers.get(socket.id);
    
    if (!user) {
      socket.emit('error', { message: 'User not authenticated' });
      return;
    }

    const call = activeCalls.get(callId);
    if (call) {
      call.answer = answer;
      call.recipientId = user.userId;
      activeCalls.set(callId, call);
    }

    // Forward answer to caller
    socket.broadcast.emit('answer', { callId, answer });
    
    console.log('Answer sent for call:', callId);
  });

  // Handle ICE candidates
  socket.on('ice-candidate', (data) => {
    const { callId, candidate } = data;
    
    // Forward ICE candidate to other peer
    socket.broadcast.emit('ice-candidate', { callId, candidate });
    
    console.log('ICE candidate forwarded for call:', callId);
  });

  // Handle incoming call notification
  socket.on('initiate-call', (data) => {
    const { recipientId, callType, callerName, callerRole } = data;
    const user = connectedUsers.get(socket.id);
    
    if (!user) {
      socket.emit('error', { message: 'User not authenticated' });
      return;
    }

    const callId = `call_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    
    // Store call information
    activeCalls.set(callId, {
      callId,
      callerId: user.userId,
      recipientId,
      callType: callType || 'voice',
      status: 'initiated',
      createdAt: Date.now()
    });

    // Send incoming call notification to recipient
    io.to(`user_${recipientId}`).emit('incoming-call', {
      callId,
      callerId: user.userId,
      callerName: callerName || 'Unknown',
      callerRole: callerRole || 'member',
      callType: callType || 'voice'
    });

    // Confirm call initiation to caller
    socket.emit('call-initiated', { callId });
    
    console.log('Call initiated:', callId, 'from', user.userId, 'to', recipientId);
  });

  // Handle call rejection
  socket.on('reject-call', (data) => {
    const { callId } = data;
    const call = activeCalls.get(callId);
    
    if (call) {
      call.status = 'rejected';
      call.endedAt = Date.now();
      activeCalls.set(callId, call);
      
      // Notify caller about rejection
      io.to(`user_${call.callerId}`).emit('call-rejected', { callId });
    }
    
    console.log('Call rejected:', callId);
  });

  // Handle call end
  socket.on('end-call', (data) => {
    const { callId } = data;
    const call = activeCalls.get(callId);
    
    if (call) {
      call.status = 'ended';
      call.endedAt = Date.now();
      activeCalls.set(callId, call);
      
      // Notify all participants about call end
      if (call.callerId) {
        io.to(`user_${call.callerId}`).emit('call-ended', { callId });
      }
      if (call.recipientId) {
        io.to(`user_${call.recipientId}`).emit('call-ended', { callId });
      }
    }
    
    console.log('Call ended:', callId);
  });

  // Handle room creation for group calls
  socket.on('create-room', (data) => {
    const { participants } = data;
    const roomId = `room_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    
    callRooms.set(roomId, {
      roomId,
      participants,
      createdAt: Date.now(),
      createdBy: socket.userId
    });
    
    socket.emit('room-created', { roomId });
    console.log('Room created:', roomId);
  });

  // Handle joining room
  socket.on('join-room', (data) => {
    const { roomId, userId } = data;
    socket.join(roomId);
    
    // Notify other participants
    socket.to(roomId).emit('user-joined', { userId, socketId: socket.id });
    
    console.log('User joined room:', userId, roomId);
  });

  // Handle leaving room
  socket.on('leave-room', (data) => {
    const { roomId, userId } = data;
    socket.leave(roomId);
    
    // Notify other participants
    socket.to(roomId).emit('user-left', { userId, socketId: socket.id });
    
    console.log('User left room:', userId, roomId);
  });

  // Handle TURN credentials request
  socket.on('get-turn-credentials', () => {
    // In production, you would generate temporary credentials
    const credentials = {
      urls: TURN_SERVERS[1].urls,
      username: TURN_SERVERS[1].username,
      credential: TURN_SERVERS[1].credential,
      ttl: 3600 // 1 hour
    };
    
    socket.emit('turn-credentials', credentials);
  });

  // Handle optimal TURN server request
  socket.on('get-optimal-turn-server', (data) => {
    const { location } = data;
    
    // In production, you would select based on location
    const optimalServer = {
      url: TURN_SERVERS[1].urls,
      region: 'us-east-1',
      latency: 50
    };
    
    socket.emit('optimal-turn-server', optimalServer);
  });

  // Handle disconnection
  socket.on('disconnect', () => {
    const user = connectedUsers.get(socket.id);
    if (user) {
      console.log('User disconnected:', user.userId);
      
      // Clean up user's active calls
      for (const [callId, call] of activeCalls.entries()) {
        if (call.callerId === user.userId || call.recipientId === user.userId) {
          call.status = 'disconnected';
          call.endedAt = Date.now();
          activeCalls.set(callId, call);
          
          // Notify other participant
          const otherUserId = call.callerId === user.userId ? call.recipientId : call.callerId;
          if (otherUserId) {
            io.to(`user_${otherUserId}`).emit('call-ended', { callId, reason: 'peer-disconnected' });
          }
        }
      }
      
      connectedUsers.delete(socket.id);
    }
  });
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    connectedUsers: connectedUsers.size,
    activeCalls: activeCalls.size,
    uptime: process.uptime()
  });
});

// Get server statistics
app.get('/stats', (req, res) => {
  res.json({
    connectedUsers: connectedUsers.size,
    activeCalls: activeCalls.size,
    callRooms: callRooms.size,
    uptime: process.uptime(),
    memory: process.memoryUsage()
  });
});

// Start server
const PORT = process.env.PORT || 3001;
server.listen(PORT, () => {
  console.log(`WebRTC Signaling Server running on port ${PORT}`);
});

// Clean up old calls periodically
setInterval(() => {
  const now = Date.now();
  const maxAge = 24 * 60 * 60 * 1000; // 24 hours
  
  for (const [callId, call] of activeCalls.entries()) {
    if (now - call.createdAt > maxAge) {
      activeCalls.delete(callId);
    }
  }
  
  for (const [roomId, room] of callRooms.entries()) {
    if (now - room.createdAt > maxAge) {
      callRooms.delete(roomId);
    }
  }
}, 60 * 60 * 1000); // Run every hour

module.exports = { app, server, io };