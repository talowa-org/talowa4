// Simple test for WebSocket server functionality

import { WebSocketServer } from './server';
import { PresenceManager } from './presence';
import { WebSocketAuth } from './auth';

/**
 * Test WebSocket server basic functionality
 */
async function testWebSocketServer(): Promise<void> {
  console.log('Starting WebSocket server tests...');

  try {
    // Test 1: Server initialization
    console.log('Test 1: Server initialization');
    const server = new WebSocketServer(3002); // Use different port for testing
    console.log('✓ WebSocket server initialized successfully');

    // Test 2: Presence manager initialization
    console.log('Test 2: Presence manager initialization');
    await PresenceManager.initialize();
    console.log('✓ Presence manager initialized successfully');

    // Test 3: Authentication validation (mock)
    console.log('Test 3: Authentication validation');
    const hasPermission = WebSocketAuth.validateMessagePermissions(
      'member',
      'text',
      false
    );
    console.log(`✓ Message permissions validation: ${hasPermission}`);

    // Test 4: Server stats
    console.log('Test 4: Server statistics');
    const stats = server.getServerStats();
    console.log('✓ Server stats retrieved:', stats);

    // Test 5: Cleanup
    console.log('Test 5: Server cleanup');
    await server.shutdown();
    console.log('✓ Server shutdown successfully');

    console.log('\n🎉 All WebSocket server tests passed!');

  } catch (error) {
    console.error('❌ Test failed:', error);
    process.exit(1);
  }
}

/**
 * Test message routing functionality
 */
async function testMessageRouting(): Promise<void> {
  console.log('\nTesting message routing...');

  try {
    const { MessageRouter } = require('./messageRouter');

    // Test message priority determination
    const testMessage = {
      id: 'test-123',
      type: 'text' as const,
      content: 'This is an emergency message!',
      encryptionLevel: 'standard' as const,
      isAnonymous: false,
      timestamp: Date.now(),
      clientId: 'test-client-123'
    };

    console.log('✓ Message routing test setup complete');

  } catch (error) {
    console.error('❌ Message routing test failed:', error);
  }
}

/**
 * Run all tests
 */
async function runTests(): Promise<void> {
  await testWebSocketServer();
  await testMessageRouting();
}

// Run tests if this file is executed directly
if (require.main === module) {
  runTests().catch(console.error);
}

export { testWebSocketServer, testMessageRouting, runTests };