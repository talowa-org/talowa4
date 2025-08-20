// Presence tracking system for WebSocket connections

import { createClient } from 'redis';
import { PresenceStatus, PresenceUpdate } from './types';

export class PresenceManager {
  private static redisClient: any = null;

  /**
   * Initialize Redis connection for presence tracking
   */
  static async initialize() {
    if (!this.redisClient) {
      try {
        // Use Redis connection string from environment or default to local
        const redisUrl = process.env.REDIS_URL || 'redis://localhost:6379';
        this.redisClient = createClient({ url: redisUrl });
        
        this.redisClient.on('error', (err: any) => {
          console.error('Redis Client Error:', err);
        });

        await this.redisClient.connect();
        console.log('Redis connected for presence tracking');
      } catch (error) {
        console.error('Failed to initialize Redis:', error);
        // Fallback to in-memory presence tracking
        this.redisClient = new Map();
      }
    }
  }

  /**
   * Update user presence status
   */
  static async updatePresence(userId: string, status: PresenceStatus): Promise<void> {
    try {
      await this.initialize();
      
      const presenceData = {
        ...status,
        lastUpdated: Date.now()
      };

      if (this.redisClient instanceof Map) {
        // In-memory fallback
        this.redisClient.set(`presence:${userId}`, JSON.stringify(presenceData));
      } else {
        // Redis storage
        await this.redisClient.setEx(
          `presence:${userId}`,
          300, // 5 minutes TTL
          JSON.stringify(presenceData)
        );
      }

      // Also update in Firestore for persistence
      await this.updateFirestorePresence(userId, status);
    } catch (error) {
      console.error('Error updating presence:', error);
    }
  }

  /**
   * Get user presence status
   */
  static async getPresence(userId: string): Promise<PresenceStatus | null> {
    try {
      await this.initialize();
      
      let presenceData: string | null = null;

      if (this.redisClient instanceof Map) {
        // In-memory fallback
        presenceData = this.redisClient.get(`presence:${userId}`) || null;
      } else {
        // Redis storage
        presenceData = await this.redisClient.get(`presence:${userId}`);
      }

      if (presenceData) {
        const parsed = JSON.parse(presenceData);
        const lastUpdated = parsed.lastUpdated || 0;
        const fiveMinutesAgo = Date.now() - 300000;

        // If presence is older than 5 minutes, consider user offline
        if (lastUpdated < fiveMinutesAgo) {
          await this.setUserOffline(userId);
          return {
            status: 'offline',
            lastSeen: lastUpdated
          };
        }

        return {
          status: parsed.status,
          lastSeen: parsed.lastSeen || lastUpdated,
          deviceInfo: parsed.deviceInfo
        };
      }

      return null;
    } catch (error) {
      console.error('Error getting presence:', error);
      return null;
    }
  }

  /**
   * Get presence for multiple users
   */
  static async getBulkPresence(userIds: string[]): Promise<Map<string, PresenceStatus>> {
    const presenceMap = new Map<string, PresenceStatus>();
    
    try {
      const promises = userIds.map(async (userId) => {
        const presence = await this.getPresence(userId);
        if (presence) {
          presenceMap.set(userId, presence);
        }
      });

      await Promise.all(promises);
    } catch (error) {
      console.error('Error getting bulk presence:', error);
    }

    return presenceMap;
  }

  /**
   * Set user as offline
   */
  static async setUserOffline(userId: string): Promise<void> {
    try {
      const offlineStatus: PresenceStatus = {
        status: 'offline',
        lastSeen: Date.now()
      };

      await this.updatePresence(userId, offlineStatus);
    } catch (error) {
      console.error('Error setting user offline:', error);
    }
  }

  /**
   * Clean up expired presence entries
   */
  static async cleanupExpiredPresence(): Promise<void> {
    try {
      await this.initialize();
      
      if (this.redisClient instanceof Map) {
        // In-memory cleanup
        const now = Date.now();
        const fiveMinutesAgo = now - 300000;
        
        for (const [key, value] of this.redisClient.entries()) {
          if (key.startsWith('presence:')) {
            try {
              const data = JSON.parse(value);
              if (data.lastUpdated < fiveMinutesAgo) {
                this.redisClient.delete(key);
              }
            } catch (e) {
              this.redisClient.delete(key); // Remove invalid entries
            }
          }
        }
      }
      // Redis handles TTL automatically, no cleanup needed
    } catch (error) {
      console.error('Error cleaning up presence:', error);
    }
  }

  /**
   * Update presence in Firestore for persistence
   */
  private static async updateFirestorePresence(userId: string, status: PresenceStatus): Promise<void> {
    try {
      const admin = require('firebase-admin');
      const db = admin.firestore();
      
      await db.collection('user_presence').doc(userId).set({
        status: status.status,
        lastSeen: status.lastSeen || Date.now(),
        deviceInfo: status.deviceInfo || null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
    } catch (error) {
      console.error('Error updating Firestore presence:', error);
    }
  }

  /**
   * Subscribe to presence updates for a list of users
   */
  static async subscribeToPresenceUpdates(
    userIds: string[],
    callback: (updates: PresenceUpdate[]) => void
  ): Promise<void> {
    // This would typically use Redis pub/sub or Firestore real-time listeners
    // For now, we'll implement polling-based updates
    const pollInterval = 30000; // 30 seconds
    
    const poll = async () => {
      try {
        const updates: PresenceUpdate[] = [];
        const presenceMap = await this.getBulkPresence(userIds);
        
        for (const [userId, status] of presenceMap.entries()) {
          updates.push({ userId, status });
        }
        
        if (updates.length > 0) {
          callback(updates);
        }
      } catch (error) {
        console.error('Error polling presence updates:', error);
      }
    };

    // Initial poll
    await poll();
    
    // Set up periodic polling
    setInterval(poll, pollInterval);
  }

  /**
   * Get online users count for statistics
   */
  static async getOnlineUsersCount(): Promise<number> {
    try {
      await this.initialize();
      
      if (this.redisClient instanceof Map) {
        // In-memory count
        let count = 0;
        const now = Date.now();
        const fiveMinutesAgo = now - 300000;
        
        for (const [key, value] of this.redisClient.entries()) {
          if (key.startsWith('presence:')) {
            try {
              const data = JSON.parse(value);
              if (data.status === 'online' && data.lastUpdated > fiveMinutesAgo) {
                count++;
              }
            } catch (e) {
              // Skip invalid entries
            }
          }
        }
        return count;
      } else {
        // Redis count (approximate)
        const keys = await this.redisClient.keys('presence:*');
        return keys.length;
      }
    } catch (error) {
      console.error('Error getting online users count:', error);
      return 0;
    }
  }
}