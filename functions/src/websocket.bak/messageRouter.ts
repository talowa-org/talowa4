// Message routing system for direct and group messages

import * as admin from 'firebase-admin';
import { MessagePayload, IncomingMessage, MessageRouting, MessageDeliveryStatus } from './types';
import { PresenceManager } from './presence';

export class MessageRouter {
  private static messageQueue: Map<string, MessageRouting[]> = new Map();
  private static deliveryCallbacks: Map<string, (status: MessageDeliveryStatus) => void> = new Map();

  /**
   * Route message to appropriate recipients
   */
  static async routeMessage(
    message: MessagePayload,
    senderId: string,
    senderName: string,
    senderRole: string,
    socketManager: any
  ): Promise<MessageDeliveryStatus> {
    try {
      // Create the complete message object
      const completeMessage: IncomingMessage = {
        ...message,
        senderId,
        senderName,
        senderRole,
        deliveryStatus: 'sent',
        isEncrypted: message.encryptionLevel !== 'standard'
      };

      // Store message in Firestore
      const messageDoc = await this.storeMessage(completeMessage);
      completeMessage.id = messageDoc.id;

      // Determine recipients
      const recipientIds = await this.getRecipientIds(message);
      
      if (recipientIds.length === 0) {
        return {
          messageId: completeMessage.id,
          status: 'failed',
          timestamp: Date.now(),
          error: 'No valid recipients found'
        };
      }

      // Create routing entry
      const routing: MessageRouting = {
        messageId: completeMessage.id,
        senderId,
        recipientIds,
        groupId: message.groupId,
        priority: this.determinePriority(message),
        deliveryAttempts: 0,
        maxRetries: 3
      };

      // Attempt immediate delivery
      const deliveryResults = await this.deliverMessage(completeMessage, recipientIds, socketManager);
      
      // Handle failed deliveries
      const failedRecipients = deliveryResults
        .filter(result => !result.success)
        .map(result => result.recipientId);

      if (failedRecipients.length > 0) {
        // Queue for retry
        routing.recipientIds = failedRecipients;
        this.queueMessage(routing);
      }

      // Update delivery status in Firestore
      await this.updateMessageDeliveryStatus(completeMessage.id, deliveryResults);

      return {
        messageId: completeMessage.id,
        status: failedRecipients.length === 0 ? 'delivered' : 'sent',
        timestamp: Date.now()
      };

    } catch (error) {
      console.error('Error routing message:', error);
      return {
        messageId: message.id,
        status: 'failed',
        timestamp: Date.now(),
        error: error instanceof Error ? error.message : 'Unknown error'
      };
    }
  }

  /**
   * Get recipient IDs based on message type
   */
  private static async getRecipientIds(message: MessagePayload): Promise<string[]> {
    if (message.recipientId) {
      // Direct message
      return [message.recipientId];
    }

    if (message.groupId) {
      // Group message - get all group members
      try {
        const db = admin.firestore();
        const groupDoc = await db.collection('groups').doc(message.groupId).get();
        
        if (!groupDoc.exists) {
          throw new Error('Group not found');
        }

        const groupData = groupDoc.data();
        return groupData?.members || [];
      } catch (error) {
        console.error('Error getting group members:', error);
        return [];
      }
    }

    return [];
  }

  /**
   * Determine message priority
   */
  private static determinePriority(message: MessagePayload): 'normal' | 'high' | 'emergency' {
    // Check if message content indicates emergency
    if (message.content.toLowerCase().includes('emergency') || 
        message.content.toLowerCase().includes('urgent') ||
        message.content.toLowerCase().includes('help')) {
      return 'emergency';
    }
    
    if (message.encryptionLevel === 'high_security') {
      return 'high';
    }

    return 'normal';
  }

  /**
   * Deliver message to recipients
   */
  private static async deliverMessage(
    message: IncomingMessage,
    recipientIds: string[],
    socketManager: any
  ): Promise<Array<{ recipientId: string; success: boolean; error?: string }>> {
    const results: Array<{ recipientId: string; success: boolean; error?: string }> = [];

    for (const recipientId of recipientIds) {
      try {
        // Check if recipient is online
        const presence = await PresenceManager.getPresence(recipientId);
        const isOnline = presence?.status === 'online';

        if (isOnline) {
          // Deliver via WebSocket
          const delivered = socketManager.sendToUser(recipientId, 'new_message', message);
          results.push({
            recipientId,
            success: delivered,
            error: delivered ? undefined : 'User not connected'
          });
        } else {
          // Queue for offline delivery
          await this.queueOfflineMessage(recipientId, message);
          results.push({
            recipientId,
            success: true // Queued successfully
          });
        }
      } catch (error) {
        results.push({
          recipientId,
          success: false,
          error: error instanceof Error ? error.message : 'Delivery failed'
        });
      }
    }

    return results;
  }

  /**
   * Store message in Firestore
   */
  private static async storeMessage(message: IncomingMessage): Promise<admin.firestore.DocumentReference> {
    const db = admin.firestore();
    
    const messageData = {
      content: message.content,
      type: message.type,
      senderId: message.senderId,
      senderName: message.senderName,
      senderRole: message.senderRole,
      recipientId: message.recipientId || null,
      groupId: message.groupId || null,
      mediaUrl: message.mediaUrl || null,
      mediaMetadata: message.mediaMetadata || null,
      encryptionLevel: message.encryptionLevel,
      isAnonymous: message.isAnonymous,
      isEncrypted: message.isEncrypted,
      deliveryStatus: message.deliveryStatus,
      timestamp: admin.firestore.Timestamp.fromMillis(message.timestamp),
      clientMessageId: message.clientId,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    };

    return await db.collection('messages').add(messageData);
  }

  /**
   * Queue message for retry delivery
   */
  private static queueMessage(routing: MessageRouting): void {
    const queueKey = `retry_${routing.priority}`;
    
    if (!this.messageQueue.has(queueKey)) {
      this.messageQueue.set(queueKey, []);
    }

    this.messageQueue.get(queueKey)!.push(routing);
  }

  /**
   * Queue message for offline user
   */
  private static async queueOfflineMessage(userId: string, message: IncomingMessage): Promise<void> {
    try {
      const db = admin.firestore();
      
      await db.collection('offline_messages').add({
        userId,
        messageId: message.id,
        message: {
          id: message.id,
          content: message.content,
          type: message.type,
          senderId: message.senderId,
          senderName: message.senderName,
          timestamp: message.timestamp,
          groupId: message.groupId || null,
          mediaUrl: message.mediaUrl || null
        },
        queuedAt: admin.firestore.FieldValue.serverTimestamp(),
        delivered: false
      });
    } catch (error) {
      console.error('Error queuing offline message:', error);
    }
  }

  /**
   * Process message delivery queue
   */
  static async processMessageQueue(socketManager: any): Promise<void> {
    const priorities = ['emergency', 'high', 'normal'];
    
    for (const priority of priorities) {
      const queueKey = `retry_${priority}`;
      const queue = this.messageQueue.get(queueKey) || [];
      
      if (queue.length === 0) continue;

      // Process up to 10 messages per priority level
      const messagesToProcess = queue.splice(0, 10);
      
      for (const routing of messagesToProcess) {
        try {
          routing.deliveryAttempts++;
          
          // Get the original message
          const db = admin.firestore();
          const messageDoc = await db.collection('messages').doc(routing.messageId).get();
          
          if (!messageDoc.exists) continue;
          
          const messageData = messageDoc.data();
          const message: IncomingMessage = {
            id: routing.messageId,
            content: messageData?.content || '',
            type: messageData?.type || 'text',
            senderId: messageData?.senderId || '',
            senderName: messageData?.senderName || '',
            senderRole: messageData?.senderRole || '',
            deliveryStatus: 'sent',
            isEncrypted: messageData?.isEncrypted || false,
            timestamp: messageData?.timestamp?.toMillis() || Date.now(),
            encryptionLevel: messageData?.encryptionLevel || 'standard',
            isAnonymous: messageData?.isAnonymous || false,
            clientId: messageData?.clientMessageId || '',
            recipientId: messageData?.recipientId,
            groupId: messageData?.groupId,
            mediaUrl: messageData?.mediaUrl,
            mediaMetadata: messageData?.mediaMetadata
          };

          // Retry delivery
          const deliveryResults = await this.deliverMessage(message, routing.recipientIds, socketManager);
          
          // Check for remaining failures
          const stillFailed = deliveryResults
            .filter(result => !result.success)
            .map(result => result.recipientId);

          if (stillFailed.length > 0 && routing.deliveryAttempts < routing.maxRetries) {
            // Requeue with updated recipient list
            routing.recipientIds = stillFailed;
            this.queueMessage(routing);
          }

        } catch (error) {
          console.error('Error processing queued message:', error);
        }
      }
    }
  }

  /**
   * Update message delivery status in Firestore
   */
  private static async updateMessageDeliveryStatus(
    messageId: string,
    deliveryResults: Array<{ recipientId: string; success: boolean; error?: string }>
  ): Promise<void> {
    try {
      const db = admin.firestore();
      
      const deliveryData = {
        deliveryResults,
        lastDeliveryAttempt: admin.firestore.FieldValue.serverTimestamp(),
        successfulDeliveries: deliveryResults.filter(r => r.success).length,
        failedDeliveries: deliveryResults.filter(r => !r.success).length
      };

      await db.collection('messages').doc(messageId).update(deliveryData);
    } catch (error) {
      console.error('Error updating delivery status:', error);
    }
  }

  /**
   * Get offline messages for a user when they come online
   */
  static async getOfflineMessages(userId: string): Promise<IncomingMessage[]> {
    try {
      const db = admin.firestore();
      
      const offlineMessagesQuery = await db.collection('offline_messages')
        .where('userId', '==', userId)
        .where('delivered', '==', false)
        .orderBy('queuedAt', 'asc')
        .limit(50) // Limit to prevent overwhelming the user
        .get();

      const messages: IncomingMessage[] = [];
      const batch = db.batch();

      for (const doc of offlineMessagesQuery.docs) {
        const data = doc.data();
        messages.push(data.message);
        
        // Mark as delivered
        batch.update(doc.ref, { delivered: true, deliveredAt: admin.firestore.FieldValue.serverTimestamp() });
      }

      // Commit the batch update
      if (offlineMessagesQuery.docs.length > 0) {
        await batch.commit();
      }

      return messages;
    } catch (error) {
      console.error('Error getting offline messages:', error);
      return [];
    }
  }

  /**
   * Handle read receipts
   */
  static async handleReadReceipt(messageId: string, userId: string, socketManager: any): Promise<void> {
    try {
      const db = admin.firestore();
      
      // Update message read status
      await db.collection('messages').doc(messageId).update({
        [`readBy.${userId}`]: admin.firestore.FieldValue.serverTimestamp(),
        lastReadAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Get message details to notify sender
      const messageDoc = await db.collection('messages').doc(messageId).get();
      if (messageDoc.exists) {
        const messageData = messageDoc.data();
        const senderId = messageData?.senderId;
        
        if (senderId && senderId !== userId) {
          // Notify sender about read receipt
          socketManager.sendToUser(senderId, 'message_read', {
            messageId,
            readBy: userId,
            readAt: Date.now()
          });
        }
      }
    } catch (error) {
      console.error('Error handling read receipt:', error);
    }
  }
}