// Main WebSocket server implementation using Socket.IO

import { Server as SocketIOServer } from 'socket.io';
import { createServer } from 'http';
import * as admin from 'firebase-admin';
import { ConnectionManager } from './connectionManager';
import { MessageRouter } from './messageRouter';
import { WebSocketAuth } from './auth';
import { PresenceManager } from './presence';
import { MessagePayload, MessageDeliveryStatus } from './types';

export class WebSocketServer {
  private io: SocketIOServer;
  private connectionManager: ConnectionManager;
  private messageQueueProcessor: NodeJS.Timeout | null = null;

  constructor(port: number = 3001) {
    // Create HTTP server
    const httpServer = createServer();
    
    // Initialize Socket.IO server
    this.io = new SocketIOServer(httpServer, {
      cors: {
        origin: "*", // Configure this properly for production
        methods: ["GET", "POST"],
        credentials: true
      },
      transports: ['websocket', 'polling'],
      pingTimeout: 60000,
      pingInterval: 25000
    });

    // Initialize connection manager
    this.connectionManager = new ConnectionManager(this.io);

    // Set up event handlers
    this.setupEventHandlers();

    // Start message queue processor
    this.startMessageQueueProcessor();

    // Start server
    httpServer.listen(port, () => {
      console.log(`WebSocket server running on port ${port}`);
    });

    // Initialize presence manager
    PresenceManager.initialize().catch(console.error);
  }

  /**
   * Set up Socket.IO event handlers
   */
  private setupEventHandlers(): void {
    this.io.on('connection', async (socket) => {
      try {
        // Handle new connection
        await this.connectionManager.handleConnection(socket);

        // Set up message handlers after authentication
        socket.on('send_message', async (data: MessagePayload) => {
          await this.handleSendMessage(socket, data);
        });

        socket.on('mark_as_read', async (data: { messageId: string }) => {
          await this.handleMarkAsRead(socket, data.messageId);
        });

        socket.on('join_group', async (data: { groupId: string }) => {
          await this.handleJoinGroup(socket, data.groupId);
        });

        socket.on('leave_group', async (data: { groupId: string }) => {
          await this.handleLeaveGroup(socket, data.groupId);
        });

        socket.on('get_conversation_history', async (data: { 
          conversationId: string; 
          limit?: number; 
          before?: number 
        }) => {
          await this.handleGetConversationHistory(socket, data);
        });

        socket.on('search_messages', async (data: { 
          query: string; 
          conversationId?: string;
          limit?: number 
        }) => {
          await this.handleSearchMessages(socket, data);
        });

      } catch (error) {
        console.error('Error setting up socket handlers:', error);
        socket.disconnect();
      }
    });

    // Handle server-level events
    this.io.engine.on('connection_error', (err) => {
      console.error('Connection error:', err);
    });
  }

  /**
   * Handle send message event
   */
  private async handleSendMessage(socket: any, messageData: MessagePayload): Promise<void> {
    try {
      // Get authenticated user info from socket
      const userId = socket.userId;
      const userName = socket.userName;
      const userRole = socket.userRole;

      if (!userId) {
        socket.emit('message_error', { 
          messageId: messageData.id,
          error: 'Not authenticated' 
        });
        return;
      }

      // Validate message permissions
      const hasPermission = WebSocketAuth.validateMessagePermissions(
        userRole,
        messageData.type,
        !!messageData.groupId,
        messageData.groupId
      );

      if (!hasPermission) {
        socket.emit('message_error', { 
          messageId: messageData.id,
          error: 'Insufficient permissions' 
        });
        return;
      }

      // Check rate limiting
      const withinRateLimit = await WebSocketAuth.checkRateLimit(userId, messageData.type);
      if (!withinRateLimit) {
        socket.emit('message_error', { 
          messageId: messageData.id,
          error: 'Rate limit exceeded' 
        });
        return;
      }

      // Validate conversation access
      const conversationId = messageData.groupId || messageData.recipientId;
      if (conversationId) {
        const hasAccess = await WebSocketAuth.validateConversationAccess(
          userId,
          conversationId,
          !!messageData.groupId
        );

        if (!hasAccess) {
          socket.emit('message_error', { 
            messageId: messageData.id,
            error: 'Access denied to conversation' 
          });
          return;
        }
      }

      // Route the message
      const deliveryStatus = await MessageRouter.routeMessage(
        messageData,
        userId,
        userName,
        userRole,
        this.connectionManager
      );

      // Send delivery confirmation to sender
      socket.emit('message_delivery_status', deliveryStatus);

    } catch (error) {
      console.error('Error handling send message:', error);
      socket.emit('message_error', { 
        messageId: messageData.id,
        error: 'Failed to send message' 
      });
    }
  }

  /**
   * Handle mark as read event
   */
  private async handleMarkAsRead(socket: any, messageId: string): Promise<void> {
    try {
      const userId = socket.userId;
      
      if (!userId) {
        socket.emit('error', { message: 'Not authenticated' });
        return;
      }

      await MessageRouter.handleReadReceipt(messageId, userId, this.connectionManager);
      
      socket.emit('message_read_confirmed', { messageId });

    } catch (error) {
      console.error('Error handling mark as read:', error);
      socket.emit('error', { message: 'Failed to mark message as read' });
    }
  }

  /**
   * Handle join group event
   */
  private async handleJoinGroup(socket: any, groupId: string): Promise<void> {
    try {
      const userId = socket.userId;
      
      if (!userId) {
        socket.emit('error', { message: 'Not authenticated' });
        return;
      }

      // Validate group access
      const hasAccess = await WebSocketAuth.validateConversationAccess(userId, groupId, true);
      
      if (!hasAccess) {
        socket.emit('error', { message: 'Access denied to group' });
        return;
      }

      // Join Socket.IO room for real-time updates
      socket.join(`group:${groupId}`);
      
      socket.emit('group_joined', { groupId });

    } catch (error) {
      console.error('Error handling join group:', error);
      socket.emit('error', { message: 'Failed to join group' });
    }
  }

  /**
   * Handle leave group event
   */
  private async handleLeaveGroup(socket: any, groupId: string): Promise<void> {
    try {
      // Leave Socket.IO room
      socket.leave(`group:${groupId}`);
      
      socket.emit('group_left', { groupId });

    } catch (error) {
      console.error('Error handling leave group:', error);
      socket.emit('error', { message: 'Failed to leave group' });
    }
  }

  /**
   * Handle get conversation history event
   */
  private async handleGetConversationHistory(socket: any, data: {
    conversationId: string;
    limit?: number;
    before?: number;
  }): Promise<void> {
    try {
      const userId = socket.userId;
      
      if (!userId) {
        socket.emit('error', { message: 'Not authenticated' });
        return;
      }

      const { conversationId, limit = 50, before } = data;

      // Validate access to conversation
      const isGroup = conversationId.startsWith('group:');
      const hasAccess = await WebSocketAuth.validateConversationAccess(
        userId,
        conversationId,
        isGroup
      );

      if (!hasAccess) {
        socket.emit('error', { message: 'Access denied to conversation' });
        return;
      }

      // Get messages from Firestore
      const db = admin.firestore();
      let query = db.collection('messages')
        .where(isGroup ? 'groupId' : 'recipientId', '==', conversationId)
        .orderBy('timestamp', 'desc')
        .limit(limit);

      if (before) {
        query = query.where('timestamp', '<', admin.firestore.Timestamp.fromMillis(before));
      }

      const messagesSnapshot = await query.get();
      const messages = messagesSnapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data(),
        timestamp: doc.data().timestamp?.toMillis() || 0
      }));

      socket.emit('conversation_history', {
        conversationId,
        messages: messages.reverse(), // Return in chronological order
        hasMore: messages.length === limit
      });

    } catch (error) {
      console.error('Error getting conversation history:', error);
      socket.emit('error', { message: 'Failed to get conversation history' });
    }
  }

  /**
   * Handle search messages event
   */
  private async handleSearchMessages(socket: any, data: {
    query: string;
    conversationId?: string;
    limit?: number;
  }): Promise<void> {
    try {
      const userId = socket.userId;
      
      if (!userId) {
        socket.emit('error', { message: 'Not authenticated' });
        return;
      }

      const { query, conversationId, limit = 20 } = data;

      if (!query || query.trim().length < 2) {
        socket.emit('search_results', { results: [] });
        return;
      }

      // Build Firestore query
      const db = admin.firestore();
      let messagesQuery = db.collection('messages')
        .where('content', '>=', query.toLowerCase())
        .where('content', '<=', query.toLowerCase() + '\uf8ff')
        .limit(limit);

      // Filter by conversation if specified
      if (conversationId) {
        const isGroup = conversationId.startsWith('group:');
        messagesQuery = messagesQuery.where(
          isGroup ? 'groupId' : 'recipientId',
          '==',
          conversationId
        );
      } else {
        // Search only in conversations the user has access to
        messagesQuery = messagesQuery.where('senderId', '==', userId);
      }

      const searchResults = await messagesQuery.get();
      const results = searchResults.docs.map(doc => ({
        id: doc.id,
        ...doc.data(),
        timestamp: doc.data().timestamp?.toMillis() || 0
      }));

      socket.emit('search_results', { 
        query,
        results,
        conversationId 
      });

    } catch (error) {
      console.error('Error searching messages:', error);
      socket.emit('error', { message: 'Failed to search messages' });
    }
  }

  /**
   * Start message queue processor
   */
  private startMessageQueueProcessor(): void {
    // Process message queue every 10 seconds
    this.messageQueueProcessor = setInterval(async () => {
      try {
        await MessageRouter.processMessageQueue(this.connectionManager);
      } catch (error) {
        console.error('Error processing message queue:', error);
      }
    }, 10000);

    // Clean up expired presence entries every 5 minutes
    setInterval(async () => {
      try {
        await PresenceManager.cleanupExpiredPresence();
      } catch (error) {
        console.error('Error cleaning up presence:', error);
      }
    }, 300000);
  }

  /**
   * Get server statistics
   */
  getServerStats(): any {
    const connectionStats = this.connectionManager.getConnectionStats();
    
    return {
      ...connectionStats,
      uptime: process.uptime(),
      memoryUsage: process.memoryUsage(),
      timestamp: Date.now()
    };
  }

  /**
   * Broadcast emergency message to all connected users in a geographic area
   */
  async broadcastEmergencyMessage(message: {
    title: string;
    content: string;
    locationLevel: 'village' | 'mandal' | 'district' | 'state';
    locationIds: string[];
    priority: 'high' | 'critical';
  }): Promise<void> {
    try {
      // Get users in the specified geographic area
      const db = admin.firestore();
      const usersQuery = await db.collection('users')
        .where(`location.${message.locationLevel}Id`, 'in', message.locationIds)
        .get();

      const emergencyPayload = {
        type: 'emergency_broadcast',
        title: message.title,
        content: message.content,
        priority: message.priority,
        timestamp: Date.now(),
        locationLevel: message.locationLevel,
        locationIds: message.locationIds
      };

      // Send to all users in the area
      for (const userDoc of usersQuery.docs) {
        const userId = userDoc.id;
        this.connectionManager.sendToUser(userId, 'emergency_broadcast', emergencyPayload);
      }

      console.log(`Emergency broadcast sent to ${usersQuery.size} users in ${message.locationLevel}: ${message.locationIds.join(', ')}`);

    } catch (error) {
      console.error('Error broadcasting emergency message:', error);
    }
  }

  /**
   * Shutdown server gracefully
   */
  async shutdown(): Promise<void> {
    console.log('Shutting down WebSocket server...');
    
    if (this.messageQueueProcessor) {
      clearInterval(this.messageQueueProcessor);
    }

    this.connectionManager.cleanup();
    
    this.io.close(() => {
      console.log('WebSocket server shut down');
    });
  }
}