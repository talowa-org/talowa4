// Authentication middleware for WebSocket connections

import * as admin from 'firebase-admin';
import * as jwt from 'jsonwebtoken';
import { AuthenticatedSocket } from './types';

export class WebSocketAuth {
  /**
   * Authenticate WebSocket connection using Firebase ID token
   */
  static async authenticateConnection(token: string): Promise<AuthenticatedSocket | null> {
    try {
      if (!token) {
        throw new Error('No authentication token provided');
      }

      // Verify Firebase ID token
      const decodedToken = await admin.auth().verifyIdToken(token);
      const userId = decodedToken.uid;

      // Get user details from Firestore
      const userDoc = await admin.firestore()
        .collection('users')
        .doc(userId)
        .get();

      if (!userDoc.exists) {
        throw new Error('User not found in database');
      }

      const userData = userDoc.data();
      if (!userData) {
        throw new Error('Invalid user data');
      }

      return {
        userId,
        userRole: userData.role || 'member',
        userName: userData.name || 'Unknown User',
        connectionId: this.generateConnectionId(userId)
      };
    } catch (error) {
      console.error('WebSocket authentication failed:', error);
      return null;
    }
  }

  /**
   * Generate unique connection ID for the user session
   */
  private static generateConnectionId(userId: string): string {
    const timestamp = Date.now();
    const random = Math.random().toString(36).substring(2);
    return `${userId}_${timestamp}_${random}`;
  }

  /**
   * Validate message permissions based on user role and message type
   */
  static validateMessagePermissions(
    userRole: string,
    messageType: string,
    isGroupMessage: boolean,
    groupId?: string
  ): boolean {
    // Basic permission checks
    if (messageType === 'emergency' && !['coordinator', 'admin', 'founder'].includes(userRole)) {
      return false;
    }

    // Group message permissions will be checked against group settings
    if (isGroupMessage && groupId) {
      // This will be implemented when we have group management
      return true; // For now, allow all authenticated users
    }

    return true; // Allow direct messages for all authenticated users
  }

  /**
   * Check if user has permission to access a conversation
   */
  static async validateConversationAccess(
    userId: string,
    conversationId: string,
    isGroupConversation: boolean
  ): Promise<boolean> {
    try {
      const db = admin.firestore();
      
      if (isGroupConversation) {
        // Check group membership
        const groupDoc = await db.collection('groups').doc(conversationId).get();
        if (!groupDoc.exists) return false;
        
        const groupData = groupDoc.data();
        return groupData?.members?.includes(userId) || false;
      } else {
        // Check direct conversation participation
        const conversationDoc = await db.collection('conversations').doc(conversationId).get();
        if (!conversationDoc.exists) return false;
        
        const conversationData = conversationDoc.data();
        return conversationData?.participantIds?.includes(userId) || false;
      }
    } catch (error) {
      console.error('Error validating conversation access:', error);
      return false;
    }
  }

  /**
   * Rate limiting check for message sending
   */
  static async checkRateLimit(userId: string, messageType: string): Promise<boolean> {
    try {
      const db = admin.firestore();
      const now = Date.now();
      const oneMinuteAgo = now - 60000; // 1 minute
      
      // Get recent messages from this user
      const recentMessages = await db.collection('messages')
        .where('senderId', '==', userId)
        .where('timestamp', '>', oneMinuteAgo)
        .get();

      const messageCount = recentMessages.size;
      
      // Rate limits based on message type
      const limits = {
        text: 60,      // 60 text messages per minute
        image: 10,     // 10 images per minute
        document: 5,   // 5 documents per minute
        voice: 20,     // 20 voice messages per minute
        emergency: 3   // 3 emergency messages per minute
      };

      const limit = limits[messageType as keyof typeof limits] || limits.text;
      return messageCount < limit;
    } catch (error) {
      console.error('Error checking rate limit:', error);
      return false; // Deny on error for safety
    }
  }
}