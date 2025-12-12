// TALOWA Messaging Cloud Functions - Production Ready
import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import * as logger from 'firebase-functions/logger';

const db = admin.firestore();
const messaging = admin.messaging();

// ============================================================================
// MESSAGE NOTIFICATIONS
// ============================================================================

export const onMessageCreated = onDocumentCreated(
  'conversations/{conversationId}/messages/{messageId}',
  async (event) => {
    try {
      const messageData = event.data?.data();
      if (!messageData) return;

      const conversationId = event.params.conversationId;
      const senderId = messageData.senderId;
      const content = messageData.content;

      const conversationDoc = await db.collection('conversations').doc(conversationId).get();
      if (!conversationDoc.exists) return;

      const conversationData = conversationDoc.data();
      if (!conversationData) return;

      const participants = conversationData.participants || [];
      const conversationName = conversationData.name || 'New Message';

      const senderDoc = await db.collection('users').doc(senderId).get();
      const senderName = senderDoc.data()?.fullName || 'Someone';

      const notificationPromises = participants
        .filter((participantId: string) => participantId !== senderId)
        .map(async (participantId: string) => {
          try {
            const userDoc = await db.collection('users').doc(participantId).get();
            const fcmToken = userDoc.data()?.fcmToken;

            if (!fcmToken) return;

            await messaging.send({
              token: fcmToken,
              notification: {
                title: conversationName,
                body: `${senderName}: ${content}`,
              },
              data: {
                type: 'new_message',
                conversationId,
                senderId,
              },
            });
          } catch (error) {
            logger.error(`Failed to send notification to ${participantId}:`, error);
          }
        });

      await Promise.all(notificationPromises);
    } catch (error) {
      logger.error('Error in onMessageCreated:', error);
    }
  }
);

// ============================================================================
// CONVERSATION MANAGEMENT
// ============================================================================

export const createConversation = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'User must be authenticated');

  const { participantIds, type, name, description } = request.data;

  if (!participantIds || !Array.isArray(participantIds) || participantIds.length === 0) {
    throw new HttpsError('invalid-argument', 'participantIds must be a non-empty array');
  }

  try {
    if (!participantIds.includes(uid)) {
      participantIds.push(uid);
    }

    const conversationRef = await db.collection('conversations').add({
      participantIds: participantIds,
      type: type || 'direct',
      name: name || 'New Conversation',
      description: description || null,
      createdBy: uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastMessage: '',
      lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
      lastMessageSenderId: '',
      unreadCounts: participantIds.reduce((acc: any, id: string) => {
        acc[id] = 0;
        return acc;
      }, {}),
      isActive: true,
      metadata: {},
    });

    return { conversationId: conversationRef.id, success: true };
  } catch (error) {
    logger.error('Error creating conversation:', error);
    throw new HttpsError('internal', 'Failed to create conversation');
  }
});

export const sendMessage = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'User must be authenticated');

  const { conversationId, content, type, mediaUrl, metadata } = request.data;

  if (!conversationId || !content) {
    throw new HttpsError('invalid-argument', 'conversationId and content are required');
  }

  try {
    const conversationDoc = await db.collection('conversations').doc(conversationId).get();

    if (!conversationDoc.exists) {
      throw new HttpsError('not-found', 'Conversation not found');
    }

    const conversationData = conversationDoc.data();
    const participants = conversationData?.participantIds || [];
    
    if (!participants.includes(uid)) {
      throw new HttpsError('permission-denied', 'User is not a participant');
    }

    // Get sender name
    const senderDoc = await db.collection('users').doc(uid).get();
    const senderName = senderDoc.data()?.fullName || 'Unknown';

    const messageRef = await db
      .collection('conversations')
      .doc(conversationId)
      .collection('messages')
      .add({
        conversationId,
        senderId: uid,
        senderName,
        content,
        messageType: type || 'text',
        mediaUrls: mediaUrl ? [mediaUrl] : [],
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        readBy: [uid],
        isEdited: false,
        isDeleted: false,
        metadata: metadata || {},
      });

    await db.collection('conversations').doc(conversationId).update({
      lastMessage: content,
      lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
      lastMessageSenderId: uid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const unreadUpdates: any = {};
    participants.forEach((participantId: string) => {
      if (participantId !== uid) {
        unreadUpdates[`unreadCounts.${participantId}`] = admin.firestore.FieldValue.increment(1);
      }
    });

    if (Object.keys(unreadUpdates).length > 0) {
      await db.collection('conversations').doc(conversationId).update(unreadUpdates);
    }

    return { messageId: messageRef.id, success: true };
  } catch (error) {
    logger.error('Error sending message:', error);
    throw new HttpsError('internal', 'Failed to send message');
  }
});

export const markConversationAsRead = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'User must be authenticated');

  const { conversationId } = request.data;

  if (!conversationId) {
    throw new HttpsError('invalid-argument', 'conversationId is required');
  }

  try {
    await db.collection('conversations').doc(conversationId).update({
      [`unreadCounts.${uid}`]: 0,
    });

    return { success: true };
  } catch (error) {
    logger.error('Error marking conversation as read:', error);
    throw new HttpsError('internal', 'Failed to mark conversation as read');
  }
});

// ============================================================================
// ANONYMOUS REPORTS
// ============================================================================

export const createAnonymousReport = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'User must be authenticated');

  const { content, category, location } = request.data;

  if (!content || !category) {
    throw new HttpsError('invalid-argument', 'content and category are required');
  }

  try {
    const adminsSnapshot = await db.collection('users').where('role', '==', 'admin').get();
    const adminIds = adminsSnapshot.docs.map((doc) => doc.id);

    if (adminIds.length === 0) {
      throw new HttpsError('failed-precondition', 'No admins available');
    }

    const conversationRef = await db.collection('conversations').add({
      participantIds: adminIds,
      type: 'anonymous',
      name: `Anonymous Report - ${category}`,
      description: 'Anonymous report submitted',
      createdBy: 'anonymous',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastMessage: content,
      lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
      lastMessageSenderId: 'anonymous',
      unreadCounts: adminIds.reduce((acc: any, id: string) => {
        acc[id] = 1;
        return acc;
      }, {}),
      isActive: true,
      metadata: { category, location: location || null, anonymous: true },
    });

    await db
      .collection('conversations')
      .doc(conversationRef.id)
      .collection('messages')
      .add({
        conversationId: conversationRef.id,
        senderId: 'anonymous',
        senderName: 'Anonymous',
        content,
        messageType: 'text',
        mediaUrls: [],
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        readBy: [],
        isEdited: false,
        isDeleted: false,
        metadata: { category, location: location || null, anonymous: true },
      });

    return { conversationId: conversationRef.id, success: true };
  } catch (error) {
    logger.error('Error creating anonymous report:', error);
    throw new HttpsError('internal', 'Failed to create anonymous report');
  }
});

// ============================================================================
// EMERGENCY BROADCASTS
// ============================================================================

export const sendEmergencyBroadcast = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'User must be authenticated');

  const { message, category, targetUserIds } = request.data;

  if (!message || !category) {
    throw new HttpsError('invalid-argument', 'message and category are required');
  }

  try {
    const userDoc = await db.collection('users').doc(uid).get();
    const userRole = userDoc.data()?.role;

    if (userRole !== 'admin' && userRole !== 'coordinator') {
      throw new HttpsError('permission-denied', 'Only admins and coordinators can send broadcasts');
    }

    let recipients = targetUserIds || [];
    if (recipients.length === 0) {
      const usersSnapshot = await db.collection('users').get();
      recipients = usersSnapshot.docs.map((doc) => doc.id);
    }

    const conversationRef = await db.collection('conversations').add({
      participantIds: recipients,
      type: 'group',
      name: '🚨 Emergency Alert',
      description: 'Emergency broadcast message',
      createdBy: uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastMessage: message,
      lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
      lastMessageSenderId: uid,
      unreadCounts: recipients.reduce((acc: any, id: string) => {
        acc[id] = id === uid ? 0 : 1;
        return acc;
      }, {}),
      isActive: true,
      metadata: { emergency: true, category, broadcastedBy: uid },
    });

    // Get sender name
    const senderDoc = await db.collection('users').doc(uid).get();
    const senderName = senderDoc.data()?.fullName || 'Admin';

    await db
      .collection('conversations')
      .doc(conversationRef.id)
      .collection('messages')
      .add({
        conversationId: conversationRef.id,
        senderId: uid,
        senderName,
        content: message,
        messageType: 'text',
        mediaUrls: [],
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        readBy: [uid],
        isEdited: false,
        isDeleted: false,
        metadata: { emergency: true, category, broadcastedBy: uid },
      });

    return { conversationId: conversationRef.id, success: true, recipientCount: recipients.length };
  } catch (error) {
    logger.error('Error sending emergency broadcast:', error);
    throw new HttpsError('internal', 'Failed to send emergency broadcast');
  }
});

// ============================================================================
// UTILITIES
// ============================================================================

export const getUserConversations = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'User must be authenticated');

  try {
    const snapshot = await db
      .collection('conversations')
      .where('participantIds', 'array-contains', uid)
      .limit(50)
      .get();

    const conversations = snapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    return { conversations };
  } catch (error) {
    logger.error('Error getting user conversations:', error);
    throw new HttpsError('internal', 'Failed to get conversations');
  }
});

export const getUnreadCount = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'User must be authenticated');

  try {
    const snapshot = await db
      .collection('conversations')
      .where('participantIds', 'array-contains', uid)
      .get();

    let totalUnread = 0;
    snapshot.docs.forEach((doc) => {
      const unreadCounts = doc.data().unreadCounts || {};
      totalUnread += unreadCounts[uid] || 0;
    });

    return { unreadCount: totalUnread };
  } catch (error) {
    logger.error('Error getting unread count:', error);
    throw new HttpsError('internal', 'Failed to get unread count');
  }
});
