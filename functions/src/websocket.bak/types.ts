// WebSocket Types and Interfaces for TALOWA Communication System

export interface MessagePayload {
  id: string;
  type: 'text' | 'image' | 'document' | 'voice' | 'location' | 'emergency';
  content: string;
  recipientId?: string;        // For direct messages
  groupId?: string;            // For group messages
  mediaUrl?: string;
  mediaMetadata?: MediaMetadata;
  encryptionLevel: 'standard' | 'high_security';
  isAnonymous: boolean;
  timestamp: number;
  clientId: string;            // For deduplication
}

export interface IncomingMessage extends MessagePayload {
  senderId: string;
  senderName: string;
  senderRole: string;
  deliveryStatus: 'sent' | 'delivered' | 'read';
  isEncrypted: boolean;
}

export interface MediaMetadata {
  size: number;
  mimeType: string;
  duration?: number;         // For voice messages
  dimensions?: { width: number; height: number }; // For images
}

export interface PresenceStatus {
  status: 'online' | 'offline' | 'away' | 'busy';
  lastSeen: number;
  deviceInfo?: {
    platform: string;
    version: string;
  };
}

export interface PresenceUpdate {
  userId: string;
  status: PresenceStatus;
}

export interface ConnectionStatus {
  isConnected: boolean;
  connectionId: string;
  lastHeartbeat: number;
  reconnectAttempts: number;
}

export interface MessageDeliveryStatus {
  messageId: string;
  status: 'queued' | 'sent' | 'delivered' | 'failed';
  timestamp: number;
  error?: string;
}

export interface WebSocketConnection {
  id: string;
  userId: string;
  socket: any; // Socket.IO socket instance
  isAuthenticated: boolean;
  connectedAt: number;
  lastActivity: number;
  presence: PresenceStatus;
}

export interface AuthenticatedSocket {
  userId: string;
  userRole: string;
  userName: string;
  connectionId: string;
}

export interface MessageRouting {
  messageId: string;
  senderId: string;
  recipientIds: string[];
  groupId?: string;
  priority: 'normal' | 'high' | 'emergency';
  deliveryAttempts: number;
  maxRetries: number;
}

export interface ReadReceipt {
  messageId: string;
  userId: string;
  readAt: number;
}

export interface TypingIndicator {
  userId: string;
  conversationId: string;
  isTyping: boolean;
  timestamp: number;
}

export interface HeartbeatData {
  connectionId: string;
  timestamp: number;
  clientTime: number;
}