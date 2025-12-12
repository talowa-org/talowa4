// Migration script to fix existing conversation field names
import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';

const db = admin.firestore();

/**
 * Migrate existing conversations to new field structure
 * This fixes conversations created with old field names
 */
export const migrateConversations = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'User must be authenticated');
  }

  // Check if user is admin
  const userDoc = await db.collection('users').doc(uid).get();
  const userRole = userDoc.data()?.role;

  if (userRole !== 'admin') {
    throw new HttpsError('permission-denied', 'Only admins can run migrations');
  }

  try {
    const conversationsSnapshot = await db.collection('conversations').get();
    let migratedCount = 0;
    let errorCount = 0;

    for (const doc of conversationsSnapshot.docs) {
      try {
        const data = doc.data();
        const updates: any = {};

        // Migrate participants -> participantIds
        if (data.participants && !data.participantIds) {
          updates.participantIds = data.participants;
          logger.info(`Migrating participants for ${doc.id}`);
        }

        // Migrate unreadCount -> unreadCounts
        if (data.unreadCount && !data.unreadCounts) {
          updates.unreadCounts = data.unreadCount;
          logger.info(`Migrating unreadCount for ${doc.id}`);
        }

        // Migrate active -> isActive
        if (data.active !== undefined && data.isActive === undefined) {
          updates.isActive = data.active;
          logger.info(`Migrating active for ${doc.id}`);
        }

        // Add missing fields
        if (!data.updatedAt) {
          updates.updatedAt = data.lastMessageAt || admin.firestore.FieldValue.serverTimestamp();
        }

        if (!data.lastMessageSenderId) {
          updates.lastMessageSenderId = '';
        }

        if (!data.metadata) {
          updates.metadata = {};
        }

        // Apply updates if any
        if (Object.keys(updates).length > 0) {
          await doc.ref.update(updates);
          migratedCount++;
          logger.info(`Migrated conversation ${doc.id}`);
        }

        // Migrate messages in this conversation
        const messagesSnapshot = await doc.ref.collection('messages').get();
        for (const messageDoc of messagesSnapshot.docs) {
          try {
            const messageData = messageDoc.data();
            const messageUpdates: any = {};

            // Migrate type -> messageType
            if (messageData.type && !messageData.messageType) {
              messageUpdates.messageType = messageData.type;
            }

            // Migrate createdAt -> sentAt
            if (messageData.createdAt && !messageData.sentAt) {
              messageUpdates.sentAt = messageData.createdAt;
            }

            // Migrate mediaUrl -> mediaUrls
            if (messageData.mediaUrl && !messageData.mediaUrls) {
              messageUpdates.mediaUrls = [messageData.mediaUrl];
            } else if (!messageData.mediaUrls) {
              messageUpdates.mediaUrls = [];
            }

            // Add missing fields
            if (!messageData.conversationId) {
              messageUpdates.conversationId = doc.id;
            }

            if (!messageData.senderName) {
              // Try to get sender name from users collection
              if (messageData.senderId && messageData.senderId !== 'anonymous') {
                const senderDoc = await db.collection('users').doc(messageData.senderId).get();
                messageUpdates.senderName = senderDoc.data()?.fullName || 'Unknown';
              } else {
                messageUpdates.senderName = 'Anonymous';
              }
            }

            if (messageData.isEdited === undefined) {
              messageUpdates.isEdited = false;
            }

            if (messageData.isDeleted === undefined) {
              messageUpdates.isDeleted = false;
            }

            if (!messageData.metadata) {
              messageUpdates.metadata = {};
            }

            // Apply message updates
            if (Object.keys(messageUpdates).length > 0) {
              await messageDoc.ref.update(messageUpdates);
              logger.info(`Migrated message ${messageDoc.id} in conversation ${doc.id}`);
            }
          } catch (messageError) {
            logger.error(`Error migrating message ${messageDoc.id}:`, messageError);
            errorCount++;
          }
        }
      } catch (error) {
        logger.error(`Error migrating conversation ${doc.id}:`, error);
        errorCount++;
      }
    }

    return {
      success: true,
      migratedCount,
      errorCount,
      totalConversations: conversationsSnapshot.docs.length,
    };
  } catch (error) {
    logger.error('Migration failed:', error);
    throw new HttpsError('internal', 'Migration failed');
  }
});
