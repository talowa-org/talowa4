// WebSocket function for Firebase Functions

import * as functions from 'firebase-functions';
import { WebSocketServer } from './server';

// Initialize WebSocket server instance
let wsServer: WebSocketServer | null = null;

/**
 * HTTP Cloud Function that initializes and manages WebSocket server
 * This function runs continuously to maintain WebSocket connections
 */
export const websocketServer = functions
  .runWith({
    memory: '1GB',
    timeoutSeconds: 540, // 9 minutes (max for HTTP functions)
  })
  .region('asia-south1')
  .https.onRequest(async (req, res) => {
    // Set CORS headers
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    try {
      // Handle different endpoints
      switch (req.path) {
        case '/start':
          if (!wsServer) {
            const port = parseInt(process.env.WEBSOCKET_PORT || '3001');
            wsServer = new WebSocketServer(port);
            res.json({ 
              status: 'started', 
              port,
              message: 'WebSocket server started successfully' 
            });
          } else {
            res.json({ 
              status: 'already_running', 
              message: 'WebSocket server is already running' 
            });
          }
          break;

        case '/stop':
          if (wsServer) {
            await wsServer.shutdown();
            wsServer = null;
            res.json({ 
              status: 'stopped', 
              message: 'WebSocket server stopped successfully' 
            });
          } else {
            res.json({ 
              status: 'not_running', 
              message: 'WebSocket server is not running' 
            });
          }
          break;

        case '/status':
          if (wsServer) {
            const stats = wsServer.getServerStats();
            res.json({ 
              status: 'running', 
              stats,
              message: 'WebSocket server is running' 
            });
          } else {
            res.json({ 
              status: 'stopped', 
              message: 'WebSocket server is not running' 
            });
          }
          break;

        case '/emergency-broadcast':
          if (req.method !== 'POST') {
            res.status(405).json({ error: 'Method not allowed' });
            return;
          }

          if (!wsServer) {
            res.status(503).json({ error: 'WebSocket server not running' });
            return;
          }

          const { title, content, locationLevel, locationIds, priority } = req.body;
          
          if (!title || !content || !locationLevel || !locationIds) {
            res.status(400).json({ error: 'Missing required fields' });
            return;
          }

          await wsServer.broadcastEmergencyMessage({
            title,
            content,
            locationLevel,
            locationIds,
            priority: priority || 'high'
          });

          res.json({ 
            status: 'sent', 
            message: 'Emergency broadcast sent successfully' 
          });
          break;

        default:
          res.status(404).json({ error: 'Endpoint not found' });
      }

    } catch (error) {
      console.error('WebSocket function error:', error);
      res.status(500).json({ 
        error: 'Internal server error',
        message: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  });

/**
 * Scheduled function to keep WebSocket server alive
 * Runs every 8 minutes to prevent function timeout
 */
export const keepWebSocketAlive = functions
  .region('asia-south1')
  .pubsub.schedule('every 8 minutes')
  .onRun(async (context) => {
    try {
      if (wsServer) {
        const stats = wsServer.getServerStats();
        console.log('WebSocket server health check:', stats);
        
        // If no connections for more than 30 minutes, consider shutting down
        if (stats.totalConnections === 0 && stats.uptime > 1800) {
          console.log('No connections for 30 minutes, considering shutdown...');
          // Could implement auto-shutdown logic here
        }
      } else {
        console.log('WebSocket server not running');
      }
    } catch (error) {
      console.error('WebSocket health check error:', error);
    }
  });

/**
 * Firestore trigger to handle offline message cleanup
 */
export const cleanupOfflineMessages = functions
  .region('asia-south1')
  .firestore.document('offline_messages/{messageId}')
  .onWrite(async (change, context) => {
    try {
      // Clean up delivered offline messages older than 7 days
      const sevenDaysAgo = new Date();
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

      const admin = require('firebase-admin');
      const db = admin.firestore();

      const oldMessages = await db.collection('offline_messages')
        .where('delivered', '==', true)
        .where('deliveredAt', '<', sevenDaysAgo)
        .limit(100)
        .get();

      const batch = db.batch();
      oldMessages.docs.forEach((doc: any) => {
        batch.delete(doc.ref);
      });

      if (oldMessages.docs.length > 0) {
        await batch.commit();
        console.log(`Cleaned up ${oldMessages.docs.length} old offline messages`);
      }

    } catch (error) {
      console.error('Error cleaning up offline messages:', error);
    }
  });

/**
 * HTTP function to get WebSocket connection info for clients
 */
export const getWebSocketInfo = functions
  .region('asia-south1')
  .https.onRequest((req, res) => {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    // Return WebSocket connection information
    const wsInfo = {
      url: process.env.WEBSOCKET_URL || 'ws://localhost:3001',
      transports: ['websocket', 'polling'],
      path: '/socket.io/',
      protocols: ['websocket'],
      heartbeatInterval: 25000,
      heartbeatTimeout: 60000
    };

    res.json(wsInfo);
  });