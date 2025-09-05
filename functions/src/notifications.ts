// Firebase Cloud Functions for Push Notifications
// Complete FCM implementation for TALOWA app

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const db = admin.firestore();
const messaging = admin.messaging();

// Notification types and priorities
enum NotificationType {
  EMERGENCY = 'emergency',
  CAMPAIGN = 'campaign',
  SOCIAL = 'social',
  ENGAGEMENT = 'engagement',
  ANNOUNCEMENT = 'announcement',
  REFERRAL = 'referral',
  SYSTEM = 'system'
}

enum NotificationPriority {
  LOW = 'low',
  NORMAL = 'normal',
  HIGH = 'high',
  CRITICAL = 'critical'
}

// Notification channels for Android
const NOTIFICATION_CHANNELS = {
  [NotificationType.EMERGENCY]: 'talowa_emergency',
  [NotificationType.CAMPAIGN]: 'talowa_campaign',
  [NotificationType.SOCIAL]: 'talowa_social',
  [NotificationType.ENGAGEMENT]: 'talowa_engagement',
  [NotificationType.ANNOUNCEMENT]: 'talowa_announcement',
  [NotificationType.REFERRAL]: 'talowa_referral',
  [NotificationType.SYSTEM]: 'talowa_system'
};

/**
 * Process notification queue - triggered when notification is added to queue
 */
export const processNotificationQueue = functions
  .region('asia-south1')
  .firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    try {
      const notificationData = snap.data();
      const notificationId = context.params.notificationId;

      console.log(`Processing notification: ${notificationId}`);

      // Validate notification data
      if (!notificationData.title || !notificationData.body) {
        console.error('Invalid notification data - missing title or body');
        await snap.ref.update({ status: 'failed', error: 'Missing title or body' });
        return;
      }

      let deliveryResults: any = {};

      // Send to specific user
      if (notificationData.targetUserId) {
        deliveryResults = await sendToUser(notificationData, notificationData.targetUserId);
      }
      // Send to topic
      else if (notificationData.targetTopic) {
        deliveryResults = await sendToTopic(notificationData, notificationData.targetTopic);
      }
      // Send to user list
      else if (notificationData.targetUserIds && Array.isArray(notificationData.targetUserIds)) {
        deliveryResults = await sendToUserList(notificationData, notificationData.targetUserIds);
      }
      // Send to geographic region
      else if (notificationData.targetRegion) {
        deliveryResults = await sendToRegion(notificationData, notificationData.targetRegion);
      }
      else {
        console.error('No valid target specified for notification');
        await snap.ref.update({ status: 'failed', error: 'No valid target specified' });
        return;
      }

      // Update notification status
      await snap.ref.update({
        status: 'sent',
        deliveryResults,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`Notification ${notificationId} processed successfully`);

    } catch (error) {
      console.error('Error processing notification:', error);
      await snap.ref.update({
        status: 'failed',
        error: error instanceof Error ? error.message : String(error),
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

/**
 * Send notification to a specific user
 */
async function sendToUser(notificationData: any, userId: string): Promise<any> {
  try {
    // Get user's FCM token and preferences
    const userDoc = await db.collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      console.log(`User ${userId} not found`);
      return { success: false, error: 'User not found' };
    }

    const userData = userDoc.data()!;
    const fcmToken = userData.fcmToken;

    if (!fcmToken) {
      console.log(`No FCM token for user ${userId}`);
      return { success: false, error: 'No FCM token' };
    }

    // Check user notification preferences
    const preferences = userData.notificationPreferences || {};
    if (!shouldSendNotification(notificationData, preferences)) {
      console.log(`Notification blocked by user preferences for ${userId}`);
      return { success: false, error: 'Blocked by user preferences' };
    }

    // Build and send FCM message
    const message = buildFCMMessage(notificationData, fcmToken);
    const response = await messaging.send(message);

    // Save notification to user's notification history
    await saveUserNotification(userId, notificationData);

    console.log(`Notification sent to user ${userId}: ${response}`);
    return { success: true, messageId: response };

  } catch (error) {
    console.error(`Error sending notification to user ${userId}:`, error);
    return { success: false, error: error instanceof Error ? error.message : String(error) };
  }
}

/**
 * Send notification to a topic
 */
async function sendToTopic(notificationData: any, topic: string): Promise<any> {
  try {
    const message = buildTopicMessage(notificationData, topic);
    const response = await messaging.send(message);

    console.log(`Notification sent to topic ${topic}: ${response}`);
    return { success: true, messageId: response, topic };

  } catch (error) {
    console.error(`Error sending notification to topic ${topic}:`, error);
    return { success: false, error: error instanceof Error ? error.message : String(error) };
  }
}

/**
 * Send notification to multiple users
 */
async function sendToUserList(notificationData: any, userIds: string[]): Promise<any> {
  try {
    const results = [];
    const batchSize = 500; // FCM multicast limit

    // Process in batches
    for (let i = 0; i < userIds.length; i += batchSize) {
      const batch = userIds.slice(i, i + batchSize);
      const tokens = await getUserTokens(batch);
      
      if (tokens.length > 0) {
        const message = buildMulticastMessage(notificationData, tokens);
        const response = await messaging.sendMulticast(message);
        
        results.push({
          successCount: response.successCount,
          failureCount: response.failureCount,
          responses: response.responses
        });

        // Save notifications to users' history
        await Promise.all(batch.map(userId => saveUserNotification(userId, notificationData)));
      }
    }

    console.log(`Notification sent to ${userIds.length} users`);
    return { success: true, results };

  } catch (error) {
    console.error('Error sending notification to user list:', error);
    return { success: false, error: error instanceof Error ? error.message : String(error) };
  }
}

/**
 * Send notification to geographic region
 */
async function sendToRegion(notificationData: any, region: any): Promise<any> {
  try {
    // Get users in the specified region
    let query: admin.firestore.Query = db.collection('users');

    if (region.state) {
      query = query.where('address.state', '==', region.state);
    }
    if (region.district) {
      query = query.where('address.district', '==', region.district);
    }
    if (region.mandal) {
      query = query.where('address.mandal', '==', region.mandal);
    }

    const snapshot = await query.get();
    const userIds = snapshot.docs.map(doc => doc.id);

    if (userIds.length === 0) {
      console.log('No users found in specified region');
      return { success: false, error: 'No users in region' };
    }

    // Send to user list
    return await sendToUserList(notificationData, userIds);

  } catch (error) {
    console.error('Error sending notification to region:', error);
    return { success: false, error: error instanceof Error ? error.message : String(error) };
  }
}

/**
 * Build FCM message for single user
 */
function buildFCMMessage(notificationData: any, fcmToken: string): admin.messaging.Message {
  const priority = getPriority(notificationData.type);
  const channelId = NOTIFICATION_CHANNELS[notificationData.type as NotificationType] || NOTIFICATION_CHANNELS[NotificationType.SYSTEM];

  return {
    token: fcmToken,
    notification: {
      title: notificationData.title,
      body: notificationData.body,
      imageUrl: notificationData.imageUrl,
    },
    data: {
      notificationId: notificationData.id || '',
      type: notificationData.type || NotificationType.SYSTEM,
      ...notificationData.data,
    },
    android: {
      priority: priority === NotificationPriority.CRITICAL ? 'high' : 'normal',
      notification: {
        channelId,
        priority: getAndroidPriority(notificationData.type),
        defaultSound: true,
        defaultVibrateTimings: true,
        color: getNotificationColor(notificationData.type),
      },
    },
    apns: {
      payload: {
        aps: {
          alert: {
            title: notificationData.title,
            body: notificationData.body,
          },
          badge: 1,
          sound: 'default',
          category: notificationData.type,
        },
      },
    },
    webpush: {
      notification: {
        title: notificationData.title,
        body: notificationData.body,
        icon: '/icons/icon-192x192.png',
        badge: '/icons/badge-72x72.png',
        tag: notificationData.type,
        requireInteraction: priority === NotificationPriority.CRITICAL,
      },
    },
  };
}

/**
 * Build topic message
 */
function buildTopicMessage(notificationData: any, topic: string): admin.messaging.TopicMessage {
  const baseMessage = buildFCMMessage(notificationData, '');
  const { token, ...messageWithoutToken } = baseMessage as any;
  return {
    ...messageWithoutToken,
    topic: topic,
  } as admin.messaging.TopicMessage;
}

/**
 * Build multicast message
 */
function buildMulticastMessage(notificationData: any, tokens: string[]): admin.messaging.MulticastMessage {
  const baseMessage = buildFCMMessage(notificationData, '');
  const { token, ...messageWithoutToken } = baseMessage as any;
  return {
    ...messageWithoutToken,
    tokens: tokens,
  } as admin.messaging.MulticastMessage;
}

/**
 * Get FCM tokens for user IDs
 */
async function getUserTokens(userIds: string[]): Promise<string[]> {
  try {
    const userDocs = await Promise.all(
      userIds.map(id => db.collection('users').doc(id).get())
    );

    return userDocs
      .filter(doc => doc.exists && doc.data()?.fcmToken)
      .map(doc => doc.data()!.fcmToken);

  } catch (error) {
    console.error('Error getting user tokens:', error);
    return [];
  }
}

/**
 * Save notification to user's history
 */
async function saveUserNotification(userId: string, notificationData: any): Promise<void> {
  try {
    await db
      .collection('users')
      .doc(userId)
      .collection('notifications')
      .add({
        ...notificationData,
        isRead: false,
        receivedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
  } catch (error) {
    console.error(`Error saving notification for user ${userId}:`, error);
  }
}

/**
 * Check if notification should be sent based on user preferences
 */
function shouldSendNotification(notificationData: any, preferences: any): boolean {
  // Always send emergency notifications
  if (notificationData.type === NotificationType.EMERGENCY) {
    return true;
  }

  // Check if push notifications are enabled
  if (preferences.enablePushNotifications === false) {
    return false;
  }

  // Check if specific type is enabled
  const typeEnabled = preferences[`enable${notificationData.type.charAt(0).toUpperCase() + notificationData.type.slice(1)}Notifications`];
  if (typeEnabled === false) {
    return false;
  }

  // Check quiet hours
  if (preferences.quietHours && isInQuietHours(preferences.quietHours)) {
    // Allow emergency override
    if (preferences.enableEmergencyOverride && notificationData.priority === NotificationPriority.CRITICAL) {
      return true;
    }
    return false;
  }

  return true;
}

/**
 * Check if current time is in quiet hours
 */
function isInQuietHours(quietHours: any): boolean {
  if (!quietHours.enabled) return false;

  const now = new Date();
  const currentHour = now.getHours();
  const startHour = parseInt(quietHours.startTime.split(':')[0]);
  const endHour = parseInt(quietHours.endTime.split(':')[0]);

  if (startHour <= endHour) {
    return currentHour >= startHour && currentHour < endHour;
  } else {
    return currentHour >= startHour || currentHour < endHour;
  }
}

/**
 * Get notification priority
 */
function getPriority(type: string): NotificationPriority {
  switch (type) {
    case NotificationType.EMERGENCY:
      return NotificationPriority.CRITICAL;
    case NotificationType.CAMPAIGN:
    case NotificationType.ANNOUNCEMENT:
      return NotificationPriority.HIGH;
    case NotificationType.SOCIAL:
    case NotificationType.ENGAGEMENT:
      return NotificationPriority.NORMAL;
    default:
      return NotificationPriority.LOW;
  }
}

/**
 * Get Android notification priority
 */
function getAndroidPriority(type: string): 'min' | 'low' | 'default' | 'high' | 'max' {
  switch (getPriority(type)) {
    case NotificationPriority.CRITICAL:
      return 'max';
    case NotificationPriority.HIGH:
      return 'high';
    case NotificationPriority.NORMAL:
      return 'default';
    default:
      return 'low';
  }
}

/**
 * Get notification color for Android
 */
function getNotificationColor(type: string): string {
  switch (type) {
    case NotificationType.EMERGENCY:
      return '#FF0000'; // Red
    case NotificationType.CAMPAIGN:
      return '#FF9800'; // Orange
    case NotificationType.SOCIAL:
      return '#2196F3'; // Blue
    case NotificationType.ENGAGEMENT:
      return '#4CAF50'; // Green
    case NotificationType.ANNOUNCEMENT:
      return '#9C27B0'; // Purple
    case NotificationType.REFERRAL:
      return '#FFC107'; // Amber
    default:
      return '#607D8B'; // Blue Grey
  }
}

/**
 * Send welcome notification to new users
 */
export const sendWelcomeNotification = functions
  .region('asia-south1')
  .firestore
  .document('users/{userId}')
  .onCreate(async (snap, context) => {
    try {
      const userId = context.params.userId;
      const userData = snap.data();

      console.log(`Sending welcome notification to new user: ${userId}`);

      // Create welcome notification
      await db.collection('notifications').add({
        title: 'Welcome to TALOWA! 🎉',
        body: `Hello ${userData.name || 'Friend'}! Welcome to the land rights movement. Let's fight for justice together!`,
        type: NotificationType.SYSTEM,
        priority: NotificationPriority.NORMAL,
        targetUserId: userId,
        data: {
          action: 'open_onboarding',
          screen: 'welcome'
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        status: 'pending'
      });

      console.log(`Welcome notification queued for user: ${userId}`);

    } catch (error) {
      console.error('Error sending welcome notification:', error);
    }
  });

/**
 * Send referral success notification
 */
export const sendReferralNotification = functions
  .region('asia-south1')
  .firestore
  .document('users/{userId}')
  .onUpdate(async (change, context) => {
    try {
      const userId = context.params.userId;
      const beforeData = change.before.data();
      const afterData = change.after.data();

      // Check if referral count increased
      const beforeReferrals = beforeData.referralStats?.totalReferrals || 0;
      const afterReferrals = afterData.referralStats?.totalReferrals || 0;

      if (afterReferrals > beforeReferrals) {
        console.log(`Sending referral success notification to user: ${userId}`);

        // Create referral success notification
        await db.collection('notifications').add({
          title: 'New Referral Success! 🎊',
          body: `Congratulations! Someone joined TALOWA using your referral code. You now have ${afterReferrals} referrals!`,
          type: NotificationType.REFERRAL,
          priority: NotificationPriority.NORMAL,
          targetUserId: userId,
          data: {
            action: 'open_referrals',
            screen: 'my_network',
            referralCount: afterReferrals
          },
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          status: 'pending'
        });

        console.log(`Referral notification queued for user: ${userId}`);
      }

    } catch (error) {
      console.error('Error sending referral notification:', error);
    }
  });

/**
 * Send social engagement notifications (likes, comments, shares)
 */
export const sendSocialNotification = functions
  .region('asia-south1')
  .firestore
  .document('posts/{postId}/interactions/{interactionId}')
  .onCreate(async (snap, context) => {
    try {
      const postId = context.params.postId;
      const interactionData = snap.data();
      const interactionType = interactionData.type; // 'like', 'comment', 'share'
      const actorUserId = interactionData.userId;

      // Get post data to find the author
      const postDoc = await db.collection('posts').doc(postId).get();
      if (!postDoc.exists) return;

      const postData = postDoc.data()!;
      const postAuthorId = postData.authorId;

      // Don't send notification if user interacted with their own post
      if (actorUserId === postAuthorId) return;

      // Get actor user data
      const actorDoc = await db.collection('users').doc(actorUserId).get();
      if (!actorDoc.exists) return;

      const actorData = actorDoc.data()!;
      const actorName = actorData.name || 'Someone';

      let title = '';
      let body = '';
      let action = '';

      switch (interactionType) {
        case 'like':
          title = 'New Like! ❤️';
          body = `${actorName} liked your post`;
          action = 'open_post';
          break;
        case 'comment':
          title = 'New Comment! 💬';
          body = `${actorName} commented on your post: "${interactionData.content?.substring(0, 50) || 'View comment'}"`;
          action = 'open_post';
          break;
        case 'share':
          title = 'Post Shared! 🔄';
          body = `${actorName} shared your post`;
          action = 'open_post';
          break;
        default:
          return;
      }

      console.log(`Sending social notification to post author: ${postAuthorId}`);

      // Create social notification
      await db.collection('notifications').add({
        title,
        body,
        type: NotificationType.SOCIAL,
        priority: NotificationPriority.NORMAL,
        targetUserId: postAuthorId,
        data: {
          action,
          screen: 'post_detail',
          postId,
          actorUserId,
          interactionType
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        status: 'pending'
      });

      console.log(`Social notification queued for user: ${postAuthorId}`);

    } catch (error) {
      console.error('Error sending social notification:', error);
    }
  });

/**
 * Send campaign update notifications
 */
export const sendCampaignNotification = functions
  .region('asia-south1')
  .https
  .onCall(async (data, context) => {
    try {
      // Verify admin access
      if (!context.auth || !context.auth.token.role || context.auth.token.role !== 'super_admin') {
        throw new functions.https.HttpsError('permission-denied', 'Only admins can send campaign notifications');
      }

      const { title, body, targetRegion, targetTopic, imageUrl, actionUrl } = data;

      if (!title || !body) {
        throw new functions.https.HttpsError('invalid-argument', 'Title and body are required');
      }

      console.log('Sending campaign notification from admin');

      // Create campaign notification
      const notificationData: any = {
        title,
        body,
        type: NotificationType.CAMPAIGN,
        priority: NotificationPriority.HIGH,
        imageUrl,
        data: {
          action: 'open_url',
          url: actionUrl || '',
          screen: 'campaign'
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        status: 'pending'
      };

      // Set target
      if (targetRegion) {
        notificationData.targetRegion = targetRegion;
      } else if (targetTopic) {
        notificationData.targetTopic = targetTopic;
      } else {
        notificationData.targetTopic = 'all_users'; // Default to all users
      }

      // Queue notification
      const notificationRef = await db.collection('notifications').add(notificationData);

      console.log(`Campaign notification queued: ${notificationRef.id}`);

      return { success: true, notificationId: notificationRef.id };

    } catch (error) {
      console.error('Error sending campaign notification:', error);
      throw new functions.https.HttpsError('internal', 'Failed to send campaign notification');
    }
  });

/**
 * Send emergency alert notifications
 */
export const sendEmergencyAlert = functions
  .region('asia-south1')
  .https
  .onCall(async (data, context) => {
    try {
      // Verify admin access
      if (!context.auth || !context.auth.token.role || context.auth.token.role !== 'super_admin') {
        throw new functions.https.HttpsError('permission-denied', 'Only admins can send emergency alerts');
      }

      const { title, body, targetRegion, urgencyLevel } = data;

      if (!title || !body) {
        throw new functions.https.HttpsError('invalid-argument', 'Title and body are required');
      }

      console.log('Sending emergency alert from admin');

      // Create emergency notification
      const notificationData: any = {
        title: `🚨 EMERGENCY: ${title}`,
        body,
        type: NotificationType.EMERGENCY,
        priority: NotificationPriority.CRITICAL,
        data: {
          action: 'show_emergency_alert',
          urgencyLevel: urgencyLevel || 'high',
          screen: 'emergency'
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        status: 'pending'
      };

      // Set target region or send to all users
      if (targetRegion) {
        notificationData.targetRegion = targetRegion;
      } else {
        notificationData.targetTopic = 'emergency_alerts';
      }

      // Queue notification
      const notificationRef = await db.collection('notifications').add(notificationData);

      console.log(`Emergency alert queued: ${notificationRef.id}`);

      return { success: true, notificationId: notificationRef.id };

    } catch (error) {
      console.error('Error sending emergency alert:', error);
      throw new functions.https.HttpsError('internal', 'Failed to send emergency alert');
    }
  });
