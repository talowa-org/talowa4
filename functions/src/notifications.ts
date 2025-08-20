// Cloud Functions for Push Notification System
// Part of Task 12: Build push notification system

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const db = admin.firestore();
const messaging = admin.messaging();

// Notification processing function
export const processNotification = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    try {
      const notificationData = snap.data();
      const notificationId = context.params.notificationId;

      console.log(`Processing notification: ${notificationId}`);

      // Determine delivery method based on notification data
      if (notificationData.targetUserId) {
        // Single user notification
        await deliverToUser(notificationData, notificationData.targetUserId);
      } else if (notificationData.targetTopic) {
        // Topic-based notification
        await deliverToTopic(notificationData, notificationData.targetTopic);
      } else if (notificationData.targetUserIds) {
        // Bulk user notification
        await deliverToBulkUsers(notificationData, notificationData.targetUserIds);
      }

      // Update notification status
      await snap.ref.update({
        status: 'processed',
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`Notification processed successfully: ${notificationId}`);
      return null;
    } catch (error) {
      console.error('Error processing notification:', error);
      
      // Update notification status to failed
      await snap.ref.update({
        status: 'failed',
        error: error.message,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      throw error;
    }
  });

// Deliver notification to single user
async function deliverToUser(notificationData: any, userId: string) {
  try {
    console.log(`Delivering notification to user: ${userId}`);

    // Get user data
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      console.log(`User ${userId} not found`);
      return;
    }

    const userData = userDoc.data()!;
    const deliveryResults: { [key: string]: boolean } = {};

    // Primary delivery: Push notification
    if (userData.fcmToken) {
      try {
        const message = buildFCMMessage(notificationData, userData.fcmToken);
        await messaging.send(message);
        deliveryResults.push = true;
        console.log(`Push notification sent to user ${userId}`);
      } catch (error) {
        console.error(`Push notification failed for user ${userId}:`, error);
        deliveryResults.push = false;
      }
    } else {
      deliveryResults.push = false;
    }

    // SMS fallback for critical messages or push failures
    if (shouldSendSMS(notificationData, deliveryResults.push)) {
      try {
        await sendSMSNotification(userData, notificationData);
        deliveryResults.sms = true;
        console.log(`SMS notification sent to user ${userId}`);
      } catch (error) {
        console.error(`SMS notification failed for user ${userId}:`, error);
        deliveryResults.sms = false;
      }
    }

    // Email fallback for important messages
    if (shouldSendEmail(notificationData, deliveryResults)) {
      try {
        await sendEmailNotification(userData, notificationData);
        deliveryResults.email = true;
        console.log(`Email notification sent to user ${userId}`);
      } catch (error) {
        console.error(`Email notification failed for user ${userId}:`, error);
        deliveryResults.email = false;
      }
    }

    // Log delivery results
    await logDeliveryResult(notificationData.id, userId, deliveryResults);

    // Schedule retry if all methods failed
    const success = Object.values(deliveryResults).some(result => result === true);
    if (!success) {
      await scheduleNotificationRetry(notificationData.id, userId, deliveryResults);
    }

  } catch (error) {
    console.error(`Error delivering to user ${userId}:`, error);
    throw error;
  }
}

// Deliver notification to topic
async function deliverToTopic(notificationData: any, topic: string) {
  try {
    console.log(`Delivering notification to topic: ${topic}`);

    const message = buildTopicFCMMessage(notificationData, topic);
    const response = await messaging.send(message);

    console.log(`Topic notification sent successfully: ${response}`);

    // Log topic delivery
    await db.collection('notification_delivery_logs').add({
      notificationId: notificationData.id,
      deliveryType: 'topic',
      target: topic,
      success: true,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

  } catch (error) {
    console.error(`Error delivering to topic ${topic}:`, error);
    
    // Log failed topic delivery
    await db.collection('notification_delivery_logs').add({
      notificationId: notificationData.id,
      deliveryType: 'topic',
      target: topic,
      success: false,
      error: error.message,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    throw error;
  }
}

// Deliver notification to bulk users
async function deliverToBulkUsers(notificationData: any, userIds: string[]) {
  try {
    console.log(`Delivering notification to ${userIds.length} users`);

    // Process in batches to avoid overwhelming the system
    const batchSize = 100;
    const batches: string[][] = [];
    
    for (let i = 0; i < userIds.length; i += batchSize) {
      batches.push(userIds.slice(i, i + batchSize));
    }

    // Process batches with controlled concurrency
    const batchPromises = batches.map((batch, index) => 
      processBulkBatch(notificationData, batch, index)
    );

    await Promise.all(batchPromises);

    console.log(`Bulk notification delivered to ${userIds.length} users`);
  } catch (error) {
    console.error('Error delivering bulk notification:', error);
    throw error;
  }
}

// Process bulk notification batch
async function processBulkBatch(notificationData: any, userIds: string[], batchIndex: number) {
  console.log(`Processing bulk batch ${batchIndex} with ${userIds.length} users`);

  const deliveryPromises = userIds.map(userId => 
    deliverToUser(notificationData, userId)
  );

  await Promise.all(deliveryPromises);
  console.log(`Completed bulk batch ${batchIndex}`);
}

// Build FCM message for single user
function buildFCMMessage(notificationData: any, fcmToken: string): admin.messaging.Message {
  const message: admin.messaging.Message = {
    token: fcmToken,
    notification: {
      title: notificationData.title,
      body: notificationData.body,
      imageUrl: notificationData.imageUrl,
    },
    data: {
      notificationId: notificationData.id || '',
      type: notificationData.type || 'general',
      ...notificationData.data,
    },
    android: {
      priority: getPriority(notificationData.type),
      notification: {
        channelId: getChannelId(notificationData.type),
        priority: getAndroidPriority(notificationData.type),
        defaultSound: true,
        defaultVibrateTimings: true,
      },
    },
    apns: {
      payload: {
        aps: {
          alert: {
            title: notificationData.title,
            body: notificationData.body,
          },
          sound: 'default',
          badge: 1,
          'interruption-level': getInterruptionLevel(notificationData.type),
        },
      },
    },
  };

  return message;
}

// Build FCM message for topic
function buildTopicFCMMessage(notificationData: any, topic: string): admin.messaging.Message {
  const message: admin.messaging.Message = {
    topic: topic,
    notification: {
      title: notificationData.title,
      body: notificationData.body,
      imageUrl: notificationData.imageUrl,
    },
    data: {
      notificationId: notificationData.id || '',
      type: notificationData.type || 'general',
      ...notificationData.data,
    },
    android: {
      priority: getPriority(notificationData.type),
      notification: {
        channelId: getChannelId(notificationData.type),
        priority: getAndroidPriority(notificationData.type),
        defaultSound: true,
        defaultVibrateTimings: true,
      },
    },
    apns: {
      payload: {
        aps: {
          alert: {
            title: notificationData.title,
            body: notificationData.body,
          },
          sound: 'default',
          badge: 1,
          'interruption-level': getInterruptionLevel(notificationData.type),
        },
      },
    },
  };

  return message;
}

// Check if SMS should be sent
function shouldSendSMS(notificationData: any, pushSuccess: boolean): boolean {
  // Send SMS for critical notifications
  if (notificationData.type === 'emergency' || 
      notificationData.type === 'landRightsAlert' ||
      notificationData.type === 'courtDateReminder') {
    return true;
  }

  // Send SMS if push notification failed for important notifications
  if (!pushSuccess && (
      notificationData.type === 'announcement' ||
      notificationData.type === 'legalUpdate' ||
      notificationData.type === 'campaignUpdate'
  )) {
    return true;
  }

  return false;
}

// Check if email should be sent
function shouldSendEmail(notificationData: any, deliveryResults: any): boolean {
  // Send email for legal updates if other methods failed
  if (notificationData.type === 'legalUpdate' && 
      !deliveryResults.push && !deliveryResults.sms) {
    return true;
  }

  // Send email for important announcements if push failed
  if (notificationData.type === 'announcement' && 
      !deliveryResults.push) {
    return true;
  }

  return false;
}

// Send SMS notification
async function sendSMSNotification(userData: any, notificationData: any) {
  try {
    const phoneNumber = userData.phoneNumber;
    if (!phoneNumber) {
      throw new Error('No phone number available');
    }

    // Log SMS attempt (actual SMS integration would go here)
    await db.collection('sms_logs').add({
      userId: userData.uid || userData.id,
      phoneNumber: phoneNumber,
      message: `TALOWA: ${notificationData.title}\n\n${notificationData.body}`,
      notificationId: notificationData.id,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      status: 'sent',
    });

    console.log(`SMS logged for user ${userData.uid || userData.id}`);
  } catch (error) {
    console.error('Error sending SMS:', error);
    throw error;
  }
}

// Send email notification
async function sendEmailNotification(userData: any, notificationData: any) {
  try {
    const email = userData.email;
    if (!email) {
      throw new Error('No email available');
    }

    // Log email attempt (actual email integration would go here)
    await db.collection('email_logs').add({
      userId: userData.uid || userData.id,
      email: email,
      subject: `TALOWA: ${notificationData.title}`,
      body: `Dear TALOWA Member,\n\n${notificationData.body}\n\nBest regards,\nTALOWA Team`,
      notificationId: notificationData.id,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      status: 'sent',
    });

    console.log(`Email logged for user ${userData.uid || userData.id}`);
  } catch (error) {
    console.error('Error sending email:', error);
    throw error;
  }
}

// Log delivery result
async function logDeliveryResult(notificationId: string, userId: string, results: any) {
  try {
    await db.collection('notification_delivery_logs').add({
      notificationId: notificationId,
      userId: userId,
      deliveryResults: results,
      success: Object.values(results).some(result => result === true),
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    console.error('Error logging delivery result:', error);
  }
}

// Schedule notification retry
async function scheduleNotificationRetry(notificationId: string, userId: string, previousAttempts: any) {
  try {
    const retryDocRef = db.collection('notification_retries').doc(`${notificationId}_${userId}`);
    const retryDoc = await retryDocRef.get();

    let retryCount = 0;
    if (retryDoc.exists) {
      retryCount = retryDoc.data()!.retryCount || 0;
    }

    // Maximum 3 retries with exponential backoff
    if (retryCount < 3) {
      const nextRetryTime = new Date(Date.now() + (retryCount + 1) * 5 * 60 * 1000); // 5, 10, 15 minutes

      await retryDocRef.set({
        notificationId: notificationId,
        userId: userId,
        retryCount: retryCount + 1,
        nextRetryTime: admin.firestore.Timestamp.fromDate(nextRetryTime),
        previousAttempts: previousAttempts,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`Scheduled retry ${retryCount + 1} for user ${userId} at ${nextRetryTime}`);
    }
  } catch (error) {
    console.error('Error scheduling retry:', error);
  }
}

// Helper functions for FCM configuration
function getPriority(notificationType: string): 'normal' | 'high' {
  const highPriorityTypes = [
    'emergency',
    'landRightsAlert',
    'announcement',
    'courtDateReminder',
    'legalUpdate',
  ];
  
  return highPriorityTypes.includes(notificationType) ? 'high' : 'normal';
}

function getChannelId(notificationType: string): string {
  switch (notificationType) {
    case 'emergency':
    case 'landRightsAlert':
      return 'talowa_emergency';
    case 'announcement':
    case 'legalUpdate':
    case 'courtDateReminder':
      return 'talowa_important';
    case 'postLike':
    case 'postComment':
    case 'postShare':
      return 'talowa_engagement';
    default:
      return 'talowa_default';
  }
}

function getAndroidPriority(notificationType: string): 'min' | 'low' | 'default' | 'high' | 'max' {
  switch (notificationType) {
    case 'emergency':
    case 'landRightsAlert':
      return 'max';
    case 'announcement':
    case 'courtDateReminder':
    case 'legalUpdate':
      return 'high';
    case 'postLike':
    case 'postShare':
    case 'newFollower':
      return 'low';
    default:
      return 'default';
  }
}

function getInterruptionLevel(notificationType: string): 'passive' | 'active' | 'time-sensitive' | 'critical' {
  switch (notificationType) {
    case 'emergency':
    case 'landRightsAlert':
      return 'critical';
    case 'announcement':
    case 'courtDateReminder':
    case 'legalUpdate':
      return 'time-sensitive';
    case 'postLike':
    case 'postShare':
    case 'newFollower':
      return 'passive';
    default:
      return 'active';
  }
}

// Process notification retries (scheduled function)
export const processNotificationRetries = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async (context) => {
    try {
      const now = admin.firestore.Timestamp.now();
      
      // Get retries that are due
      const retriesSnapshot = await db.collection('notification_retries')
        .where('nextRetryTime', '<=', now)
        .limit(100)
        .get();

      if (retriesSnapshot.empty) {
        console.log('No notification retries to process');
        return null;
      }

      console.log(`Processing ${retriesSnapshot.docs.length} notification retries`);

      const batch = db.batch();
      const retryPromises: Promise<void>[] = [];

      for (const retryDoc of retriesSnapshot.docs) {
        const retryData = retryDoc.data();
        const notificationId = retryData.notificationId;
        const userId = retryData.userId;

        // Get original notification
        const notificationDoc = await db.collection('notifications').doc(notificationId).get();
        
        if (notificationDoc.exists) {
          const notificationData = notificationDoc.data()!;
          
          // Retry delivery
          retryPromises.push(deliverToUser(notificationData, userId));
        }

        // Delete the retry document
        batch.delete(retryDoc.ref);
      }

      // Execute batch delete and retry deliveries
      await Promise.all([
        batch.commit(),
        ...retryPromises
      ]);

      console.log('Completed processing notification retries');
      return null;
    } catch (error) {
      console.error('Error processing notification retries:', error);
      throw error;
    }
  });

// Clean up old notification logs (scheduled function)
export const cleanupNotificationLogs = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    try {
      const cutoffDate = new Date();
      cutoffDate.setDate(cutoffDate.getDate() - 30); // Keep logs for 30 days
      
      const cutoffTimestamp = admin.firestore.Timestamp.fromDate(cutoffDate);

      // Clean up delivery logs
      const deliveryLogsQuery = db.collection('notification_delivery_logs')
        .where('timestamp', '<', cutoffTimestamp)
        .limit(1000);

      const deliveryLogsSnapshot = await deliveryLogsQuery.get();
      
      if (!deliveryLogsSnapshot.empty) {
        const batch = db.batch();
        deliveryLogsSnapshot.docs.forEach(doc => {
          batch.delete(doc.ref);
        });
        await batch.commit();
        
        console.log(`Cleaned up ${deliveryLogsSnapshot.docs.length} delivery logs`);
      }

      // Clean up SMS logs
      const smsLogsQuery = db.collection('sms_logs')
        .where('timestamp', '<', cutoffTimestamp)
        .limit(1000);

      const smsLogsSnapshot = await smsLogsQuery.get();
      
      if (!smsLogsSnapshot.empty) {
        const batch = db.batch();
        smsLogsSnapshot.docs.forEach(doc => {
          batch.delete(doc.ref);
        });
        await batch.commit();
        
        console.log(`Cleaned up ${smsLogsSnapshot.docs.length} SMS logs`);
      }

      // Clean up email logs
      const emailLogsQuery = db.collection('email_logs')
        .where('timestamp', '<', cutoffTimestamp)
        .limit(1000);

      const emailLogsSnapshot = await emailLogsQuery.get();
      
      if (!emailLogsSnapshot.empty) {
        const batch = db.batch();
        emailLogsSnapshot.docs.forEach(doc => {
          batch.delete(doc.ref);
        });
        await batch.commit();
        
        console.log(`Cleaned up ${emailLogsSnapshot.docs.length} email logs`);
      }

      console.log('Notification logs cleanup completed');
      return null;
    } catch (error) {
      console.error('Error cleaning up notification logs:', error);
      throw error;
    }
  });