# TALOWA Messaging System Test Suite

This directory contains comprehensive tests for the TALOWA in-app communication system, covering all aspects of messaging, encryption, voice calling, and related functionality.

## Test Structure

### 1. Unit Tests (`services/messaging/`)
- **comprehensive_messaging_test.dart**: Core messaging service unit tests
- **security_layer_test.dart**: Encryption and security validation tests
- **offline_messaging_test.dart**: Offline functionality and synchronization tests
- **performance_optimization_test.dart**: Caching and performance optimization tests

### 2. Integration Tests (`integration/`)
- **messaging_e2e_test.dart**: End-to-end message flow and call setup tests

### 3. Load Tests (`performance/`)
- **messaging_load_test.dart**: Concurrent users and message throughput tests

### 4. Security Tests (`security/`)
- **messaging_security_test.dart**: Encryption validation, authentication, and vulnerability tests

### 5. Performance Tests (`performance/`)
- **messaging_performance_test.dart**: Message delivery speed and voice call quality tests

### 6. Test Suite Runner
- **comprehensive_messaging_test_suite.dart**: Orchestrates all tests and generates reports
- **test_config.dart**: Test configuration and utilities

## Test Coverage

### Messaging Components
- ✅ Real-time messaging with WebSocket connections
- ✅ Message encryption and decryption (AES-256, RSA-4096)
- ✅ Group messaging and management
- ✅ File sharing with security scanning
- ✅ Anonymous messaging and reporting
- ✅ Emergency broadcast system
- ✅ Offline messaging and synchronization
- ✅ Message validation and content filtering

### Voice Calling Components
- ✅ WebRTC voice call setup and teardown
- ✅ Call quality monitoring and adaptation
- ✅ Group voice calls
- ✅ Call history and missed call notifications
- ✅ TURN/STUN server integration

### Security Components
- ✅ End-to-end encryption validation
- ✅ Authentication and session management
- ✅ Rate limiting and abuse prevention
- ✅ Input validation and XSS protection
- ✅ SQL injection prevention
- ✅ File upload security scanning
- ✅ Anonymous messaging privacy protection
- ✅ Audit logging and integrity verification

### Performance Components
- ✅ Message delivery speed (< 2 seconds)
- ✅ Voice call setup time (< 10 seconds)
- ✅ Concurrent user handling (100+ users)
- ✅ Message throughput (1000+ messages/second)
- ✅ File upload/download performance
- ✅ Database query optimization
- ✅ Caching effectiveness

## Running Tests

### Run All Tests
```bash
flutter test test/comprehensive_messaging_test_suite.dart
```

### Run Specific Test Suites
```bash
# Unit tests only
flutter test test/services/messaging/

# Integration tests only
flutter test test/integration/

# Security tests only
flutter test test/security/

# Performance tests only
flutter test test/performance/
```

### Run with Verbose Output
```bash
flutter test test/comprehensive_messaging_test_suite.dart --verbose
```

### Generate Test Reports
Test reports are automatically generated in the `test_results/` directory:
- `messaging_test_report.txt`: Human-readable test results
- `messaging_test_report.json`: Machine-readable results for CI/CD

## Test Configuration

### Environment Variables
- `TEST_TIMEOUT`: Override default test timeout (default: 30 seconds)
- `LOAD_TEST_USERS`: Number of concurrent users for load tests (default: 50)
- `PERFORMANCE_THRESHOLD`: Performance threshold multiplier (default: 1.0)

### Test Data
Test data is automatically generated and cleaned up for each test run:
- Mock Firebase services (Firestore, Auth)
- Test users, groups, and conversations
- Sample messages and files
- Simulated network conditions

## Performance Benchmarks

### Message Delivery
- **Target**: < 2 seconds average delivery time
- **P95**: < 3 seconds
- **P99**: < 5 seconds
- **Throughput**: > 1000 messages/second

### Voice Calls
- **Setup Time**: < 10 seconds
- **Connection Quality**: > 70% good quality rate
- **Concurrent Calls**: Support 50+ simultaneous calls

### File Transfers
- **Upload Speed**: > 1 MB/second
- **Download Speed**: > 2 MB/second
- **Concurrent Transfers**: Support 20+ simultaneous transfers

### Security
- **Encryption**: AES-256-GCM with RSA-4096 key exchange
- **Rate Limiting**: 60 messages/minute, 10 burst limit
- **Authentication**: JWT tokens with 24-hour expiration

## Test Requirements Coverage

This test suite validates all requirements from the in-app communication specification:

### Requirement 1: Real-time Messaging
- ✅ Message delivery within 2 seconds
- ✅ Offline message queuing
- ✅ Delivery status tracking
- ✅ Typing indicators
- ✅ Connection retry logic
- ✅ End-to-end encryption

### Requirement 2: Group Management
- ✅ Groups up to 500 members
- ✅ Geographic member suggestions
- ✅ Group message delivery within 5 seconds
- ✅ Member addition/removal notifications
- ✅ Message throttling for large groups
- ✅ Group permission management

### Requirement 3: Voice Calling
- ✅ Call establishment within 10 seconds
- ✅ Audio quality < 150ms latency
- ✅ Automatic quality adjustment
- ✅ Missed call notifications
- ✅ Peer-to-peer calling
- ✅ End-to-end voice encryption

### Requirement 4: File Sharing
- ✅ Support for PDF, JPG, PNG up to 25MB
- ✅ Automatic land record linking
- ✅ Voice message compression
- ✅ File encryption during transmission
- ✅ GPS coordinate extraction
- ✅ Access control for group files

### Requirement 5: Emergency Broadcasting
- ✅ Delivery to all members within 30 seconds
- ✅ Priority message queuing
- ✅ Push notifications when app closed
- ✅ Delivery tracking and retry
- ✅ SMS fallback for critical messages
- ✅ Prominent visual/audio alerts

### Requirement 6: Anonymous Reporting
- ✅ Identity protection from recipients
- ✅ Unique case ID generation
- ✅ Encrypted proxy routing
- ✅ Anonymous response capability
- ✅ Location generalization
- ✅ Minimal metadata storage

### Requirement 7: Legal Case Integration
- ✅ Automatic participant invitation
- ✅ Highest level encryption (AES-256 + RSA-4096)
- ✅ Automatic case record linking
- ✅ Audit trail maintenance
- ✅ Unauthorized access blocking
- ✅ Conversation archiving

### Requirement 8: Offline Support
- ✅ Intermittent connectivity handling
- ✅ Message and media compression
- ✅ Offline message composition
- ✅ Text message prioritization
- ✅ Data usage controls
- ✅ 2G network optimization

### Requirement 9: Campaign Integration
- ✅ Automatic group chat creation
- ✅ Participant notifications
- ✅ Location-based messaging
- ✅ Calendar integration
- ✅ Volunteer coordination
- ✅ Activity report generation

### Requirement 10: Content Moderation
- ✅ Inappropriate content flagging within 1 hour
- ✅ Automatic spam/abuse limiting
- ✅ End-to-end encryption respect
- ✅ Graduated response system
- ✅ Legal request procedures
- ✅ Administrative action transparency

## Continuous Integration

### GitHub Actions Integration
```yaml
- name: Run Messaging Tests
  run: |
    flutter test test/comprehensive_messaging_test_suite.dart --coverage
    genhtml coverage/lcov.info -o coverage/html
```

### Test Result Artifacts
- Test reports (TXT and JSON formats)
- Coverage reports (HTML and LCOV)
- Performance metrics
- Security scan results

## Troubleshooting

### Common Issues

1. **Test Timeouts**
   - Increase timeout values in test configuration
   - Check network connectivity for integration tests
   - Verify Firebase emulator is running

2. **Mock Service Failures**
   - Ensure all mock services are properly initialized
   - Check for conflicting test data
   - Verify cleanup between tests

3. **Performance Test Failures**
   - Adjust performance thresholds for test environment
   - Check system resources during test execution
   - Verify network conditions are stable

### Debug Mode
Enable verbose logging by setting environment variable:
```bash
export FLUTTER_TEST_VERBOSE=true
flutter test test/comprehensive_messaging_test_suite.dart
```

## Contributing

When adding new tests:

1. Follow the existing test structure and naming conventions
2. Include both positive and negative test cases
3. Add performance benchmarks for new features
4. Update this README with new test coverage
5. Ensure tests are deterministic and can run in parallel

### Test Naming Convention
- Unit tests: `test_feature_functionality`
- Integration tests: `should_complete_end_to_end_flow`
- Performance tests: `should_meet_performance_requirements`
- Security tests: `should_prevent_security_vulnerability`

## Test Data Management

### Test Database
- Uses fake Firebase services for isolation
- Automatic cleanup between test runs
- Seeded with consistent test data
- No external dependencies

### File Uploads
- Mock file data generated in memory
- No actual file system operations
- Simulated virus scanning results
- Temporary file cleanup

### Network Simulation
- Configurable network conditions
- Latency and packet loss simulation
- Bandwidth throttling
- Connection failure scenarios

---

For questions or issues with the test suite, please refer to the main project documentation or create an issue in the project repository.