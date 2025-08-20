// WebSocket connection management with authentication and heartbeat

import { Server as SocketIOServer, Socket } from 'socket.io';
import { WebSocketConnection, HeartbeatData, TypingIndicator } from './types';
import { WebSocketAuth } from './auth';
import { PresenceManager } from './presence';

export class ConnectionManager {
  private connections: Map<string, WebSocketConnection> = new Map();
  private userConnections: Map<string, Set<string>> = new Map(); // userId -> Set of connectionIds
  private heartbeatInterval: NodeJS.Timeout | null = null;
  private typingTimeouts: Map<string, NodeJS.Timeout> = new Map();

  constructor(private io: SocketIOServer) {
    this.setupHeartbeat();
  }

  /**
   * Handle new WebSocket connection
   */
  async handleConnection(socket: Socket): Promise<void> {
    console.log(`New connection attempt: ${socket.id}`);

    // Set up authentication timeout
    const authTimeout = setTimeout(() => {
      if (!this.connections.has(socket.id)) {
        socket.emit('auth_timeout', { message: 'Authentication timeout' });
        socket.disconnect();
      }
    }, 30000); // 30 seconds to authenticate

    // Handle authentication
    socket.on('authenticate', async (data: { token: string; deviceInfo?: any }) => {
      clearTimeout(authTimeout);
      await this.authenticateConnection(socket, data.token, data.deviceInfo);
    });

    // Handle disconnection
    socket.on('disconnect', async (reason: string) => {
      await this.handleDisconnection(socket.id, reason);
    });

    // Handle heartbeat
    socket.on('heartbeat', (data: HeartbeatData) => {
      this.handleHeartbeat(socket.id, data);
    });

    // Handle typing indicators
    socket.on('typing_start', (data: { conversationId: string }) => {
      this.handleTypingStart(socket.id, data.conversationId);
    });

    socket.on('typing_stop', (data: { conversationId: string }) => {
      this.handleTypingStop(socket.id, data.conversationId);
    });

    // Handle presence updates
    socket.on('update_presence', async (data: { status: 'online' | 'away' | 'busy' }) => {
      await this.handlePresenceUpdate(socket.id, data.status);
    });
  }

  /**
   * Authenticate WebSocket connection
   */
  private async authenticateConnection(socket: Socket, token: string, deviceInfo?: any): Promise<void> {
    try {
      const authResult = await WebSocketAuth.authenticateConnection(token);
      
      if (!authResult) {
        socket.emit('auth_failed', { message: 'Authentication failed' });
        socket.disconnect();
        return;
      }

      // Create connection record
      const connection: WebSocketConnection = {
        id: socket.id,
        userId: authResult.userId,
        socket,
        isAuthenticated: true,
        connectedAt: Date.now(),
        lastActivity: Date.now(),
        presence: {
          status: 'online',
          lastSeen: Date.now(),
          deviceInfo
        }
      };

      // Store connection
      this.connections.set(socket.id, connection);
      
      // Track user connections
      if (!this.userConnections.has(authResult.userId)) {
        this.userConnections.set(authResult.userId, new Set());
      }
      this.userConnections.get(authResult.userId)!.add(socket.id);

      // Update presence
      await PresenceManager.updatePresence(authResult.userId, connection.presence);

      // Send authentication success
      socket.emit('auth_success', {
        connectionId: authResult.connectionId,
        userId: authResult.userId,
        userName: authResult.userName,
        userRole: authResult.userRole
      });

      // Join user to their personal room for direct messages
      socket.join(`user:${authResult.userId}`);

      // Send any offline messages
      await this.deliverOfflineMessages(authResult.userId, socket);

      console.log(`User ${authResult.userId} authenticated with connection ${socket.id}`);

    } catch (error) {
      console.error('Authentication error:', error);
      socket.emit('auth_failed', { message: 'Authentication error' });
      socket.disconnect();
    }
  }

  /**
   * Handle connection disconnection
   */
  private async handleDisconnection(socketId: string, reason: string): Promise<void> {
    const connection = this.connections.get(socketId);
    
    if (connection) {
      console.log(`User ${connection.userId} disconnected: ${reason}`);

      // Remove from user connections
      const userConnections = this.userConnections.get(connection.userId);
      if (userConnections) {
        userConnections.delete(socketId);
        
        // If no more connections for this user, set them offline
        if (userConnections.size === 0) {
          await PresenceManager.setUserOffline(connection.userId);
          this.userConnections.delete(connection.userId);
        }
      }

      // Clean up typing indicators
      this.cleanupTypingIndicators(socketId);

      // Remove connection
      this.connections.delete(socketId);
    }
  }

  /**
   * Handle heartbeat from client
   */
  private handleHeartbeat(socketId: string, data: HeartbeatData): void {
    const connection = this.connections.get(socketId);
    
    if (connection) {
      connection.lastActivity = Date.now();
      
      // Send heartbeat response
      connection.socket.emit('heartbeat_ack', {
        serverTime: Date.now(),
        clientTime: data.clientTime
      });
    }
  }

  /**
   * Handle typing start
   */
  private handleTypingStart(socketId: string, conversationId: string): void {
    const connection = this.connections.get(socketId);
    
    if (connection) {
      const typingIndicator: TypingIndicator = {
        userId: connection.userId,
        conversationId,
        isTyping: true,
        timestamp: Date.now()
      };

      // Broadcast to conversation participants
      this.broadcastToConversation(conversationId, 'typing_indicator', typingIndicator, connection.userId);

      // Set timeout to auto-stop typing after 10 seconds
      const timeoutKey = `${socketId}:${conversationId}`;
      if (this.typingTimeouts.has(timeoutKey)) {
        clearTimeout(this.typingTimeouts.get(timeoutKey)!);
      }

      const timeout = setTimeout(() => {
        this.handleTypingStop(socketId, conversationId);
      }, 10000);

      this.typingTimeouts.set(timeoutKey, timeout);
    }
  }

  /**
   * Handle typing stop
   */
  private handleTypingStop(socketId: string, conversationId: string): void {
    const connection = this.connections.get(socketId);
    
    if (connection) {
      const typingIndicator: TypingIndicator = {
        userId: connection.userId,
        conversationId,
        isTyping: false,
        timestamp: Date.now()
      };

      // Broadcast to conversation participants
      this.broadcastToConversation(conversationId, 'typing_indicator', typingIndicator, connection.userId);

      // Clear timeout
      const timeoutKey = `${socketId}:${conversationId}`;
      if (this.typingTimeouts.has(timeoutKey)) {
        clearTimeout(this.typingTimeouts.get(timeoutKey)!);
        this.typingTimeouts.delete(timeoutKey);
      }
    }
  }

  /**
   * Handle presence update
   */
  private async handlePresenceUpdate(socketId: string, status: 'online' | 'away' | 'busy'): Promise<void> {
    const connection = this.connections.get(socketId);
    
    if (connection) {
      connection.presence.status = status;
      connection.presence.lastSeen = Date.now();
      
      await PresenceManager.updatePresence(connection.userId, connection.presence);
    }
  }

  /**
   * Send message to specific user
   */
  sendToUser(userId: string, event: string, data: any): boolean {
    const userConnections = this.userConnections.get(userId);
    
    if (!userConnections || userConnections.size === 0) {
      return false; // User not connected
    }

    let sent = false;
    for (const connectionId of userConnections) {
      const connection = this.connections.get(connectionId);
      if (connection && connection.isAuthenticated) {
        connection.socket.emit(event, data);
        sent = true;
      }
    }

    return sent;
  }

  /**
   * Broadcast message to conversation participants
   */
  private async broadcastToConversation(
    conversationId: string,
    event: string,
    data: any,
    excludeUserId?: string
  ): Promise<void> {
    try {
      // Get conversation participants from Firestore
      const admin = require('firebase-admin');
      const db = admin.firestore();
      
      // Try to get from groups collection first
      let participantIds: string[] = [];
      
      const groupDoc = await db.collection('groups').doc(conversationId).get();
      if (groupDoc.exists) {
        const groupData = groupDoc.data();
        participantIds = groupData?.members || [];
      } else {
        // Try conversations collection
        const conversationDoc = await db.collection('conversations').doc(conversationId).get();
        if (conversationDoc.exists) {
          const conversationData = conversationDoc.data();
          participantIds = conversationData?.participantIds || [];
        }
      }

      // Send to all participants except the sender
      for (const participantId of participantIds) {
        if (participantId !== excludeUserId) {
          this.sendToUser(participantId, event, data);
        }
      }
    } catch (error) {
      console.error('Error broadcasting to conversation:', error);
    }
  }

  /**
   * Deliver offline messages to newly connected user
   */
  private async deliverOfflineMessages(userId: string, socket: Socket): Promise<void> {
    try {
      const MessageRouter = require('./messageRouter').MessageRouter;
      const offlineMessages = await MessageRouter.getOfflineMessages(userId);
      
      if (offlineMessages.length > 0) {
        socket.emit('offline_messages', { messages: offlineMessages });
      }
    } catch (error) {
      console.error('Error delivering offline messages:', error);
    }
  }

  /**
   * Clean up typing indicators for disconnected socket
   */
  private cleanupTypingIndicators(socketId: string): void {
    const keysToDelete: string[] = [];
    
    for (const [key, timeout] of this.typingTimeouts.entries()) {
      if (key.startsWith(`${socketId}:`)) {
        clearTimeout(timeout);
        keysToDelete.push(key);
      }
    }
    
    for (const key of keysToDelete) {
      this.typingTimeouts.delete(key);
    }
  }

  /**
   * Set up heartbeat monitoring
   */
  private setupHeartbeat(): void {
    // Check for stale connections every 30 seconds
    this.heartbeatInterval = setInterval(() => {
      const now = Date.now();
      const staleThreshold = 60000; // 1 minute
      
      for (const [socketId, connection] of this.connections.entries()) {
        if (now - connection.lastActivity > staleThreshold) {
          console.log(`Disconnecting stale connection: ${socketId}`);
          connection.socket.disconnect();
        }
      }
    }, 30000);
  }

  /**
   * Get connection statistics
   */
  getConnectionStats(): {
    totalConnections: number;
    authenticatedConnections: number;
    uniqueUsers: number;
  } {
    const totalConnections = this.connections.size;
    const authenticatedConnections = Array.from(this.connections.values())
      .filter(conn => conn.isAuthenticated).length;
    const uniqueUsers = this.userConnections.size;

    return {
      totalConnections,
      authenticatedConnections,
      uniqueUsers
    };
  }

  /**
   * Cleanup on shutdown
   */
  cleanup(): void {
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
    }
    
    for (const timeout of this.typingTimeouts.values()) {
      clearTimeout(timeout);
    }
    
    this.typingTimeouts.clear();
    this.connections.clear();
    this.userConnections.clear();
  }
}