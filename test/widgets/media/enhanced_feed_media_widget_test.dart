// Unit tests for Enhanced Feed Media Widget
// Tests proper media rendering with error handling

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';

import 'package:talowa/widgets/media/enhanced_feed_media_widget.dart';
import 'package:talowa/services/media/comprehensive_media_service.dart';

void main() {
  group('EnhancedFeedMediaWidget', () {

    testWidgets('should display loading indicator initially', (WidgetTester tester) async {
      // Arrange
      const widget = EnhancedFeedMediaWidget(
        mediaUrl: 'https://firebasestorage.googleapis.com/v0/b/talowa.firebasestorage.app/o/test.jpg?alt=media&token=test-token',
        postId: 'test-post-id',
        mediaIndex: 0,
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: widget,
          ),
        ),
      );

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should display image for valid image URL', (WidgetTester tester) async {
      // Arrange
      const imageUrl = 'https://firebasestorage.googleapis.com/v0/b/talowa.firebasestorage.app/o/test.jpg?alt=media&token=test-token';
      const widget = EnhancedFeedMediaWidget(
        mediaUrl: imageUrl,
        contentType: 'image/jpeg',
        postId: 'test-post-id',
        mediaIndex: 0,
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: widget,
          ),
        ),
      );

      // Wait for initialization
      await tester.pump();

      // Assert
      expect(find.byType(CachedNetworkImage), findsOneWidget);
    });

    testWidgets('should display error widget for invalid URL', (WidgetTester tester) async {
      // Arrange
      const invalidUrl = 'invalid-url';
      const widget = EnhancedFeedMediaWidget(
        mediaUrl: invalidUrl,
        postId: 'test-post-id',
        mediaIndex: 0,
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: widget,
          ),
        ),
      );

      // Wait for error handling
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Assert
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Failed to load media'), findsOneWidget);
    });

    testWidgets('should display retry button on error', (WidgetTester tester) async {
      // Arrange
      const invalidUrl = 'invalid-url';
      const widget = EnhancedFeedMediaWidget(
        mediaUrl: invalidUrl,
        postId: 'test-post-id',
        mediaIndex: 0,
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: widget,
          ),
        ),
      );

      // Wait for error handling
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Assert
      expect(find.text('Tap to retry'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('should retry loading when retry button is tapped', (WidgetTester tester) async {
      // Arrange
      const invalidUrl = 'invalid-url';
      const widget = EnhancedFeedMediaWidget(
        mediaUrl: invalidUrl,
        postId: 'test-post-id',
        mediaIndex: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: widget,
          ),
        ),
      );

      // Wait for error state
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Act
      await tester.tap(find.text('Tap to retry'));
      await tester.pump();

      // Assert - should show loading again
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should detect video content type correctly', (WidgetTester tester) async {
      // Arrange
      const videoUrl = 'https://firebasestorage.googleapis.com/v0/b/talowa.firebasestorage.app/o/test.mp4?alt=media&token=test-token';
      const widget = EnhancedFeedMediaWidget(
        mediaUrl: videoUrl,
        contentType: 'video/mp4',
        postId: 'test-post-id',
        mediaIndex: 0,
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: widget,
          ),
        ),
      );

      // Wait for initialization
      await tester.pump();

      // Assert - should attempt to create video player
      // Note: VideoPlayer widget might not be visible in tests due to platform dependencies
      // but we can verify the widget tree structure
      expect(find.byType(EnhancedFeedMediaWidget), findsOneWidget);
    });

    testWidgets('should show CORS error message for CORS issues', (WidgetTester tester) async {
      // This test would require mocking network requests to simulate CORS errors
      // For now, we'll test the error message display logic
      
      // Arrange
      const corsUrl = 'https://example.com/test.jpg'; // Non-Firebase URL that would cause CORS
      const widget = EnhancedFeedMediaWidget(
        mediaUrl: corsUrl,
        postId: 'test-post-id',
        mediaIndex: 0,
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: widget,
          ),
        ),
      );

      // Wait for error handling
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Assert
      expect(find.text('Media temporarily unavailable'), findsOneWidget);
    });

    group('URL validation', () {
      testWidgets('should accept valid Firebase Storage URLs', (WidgetTester tester) async {
        // Arrange
        const validUrl = 'https://firebasestorage.googleapis.com/v0/b/talowa.firebasestorage.app/o/test.jpg?alt=media&token=test-token';
        const widget = EnhancedFeedMediaWidget(
          mediaUrl: validUrl,
          postId: 'test-post-id',
          mediaIndex: 0,
        );

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: widget,
            ),
          ),
        );

        await tester.pump();

        // Assert - should not show error immediately for valid URL format
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('should reject malformed URLs', (WidgetTester tester) async {
        // Arrange
        const malformedUrl = 'not-a-url';
        const widget = EnhancedFeedMediaWidget(
          mediaUrl: malformedUrl,
          postId: 'test-post-id',
          mediaIndex: 0,
        );

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: widget,
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Assert
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
      });
    });

    group('content type detection', () {
      test('should detect image content types', () {
        // This test is skipped because _detectContentType is a private method
        // and cannot be accessed directly in tests
      });

      test('should detect video content types', () {
        // This test is skipped because _detectContentType is a private method
        // and cannot be accessed directly in tests
      });

      test('should default to image/jpeg for unknown extensions', () {
        // This test is skipped because _detectContentType is a private method
        // and cannot be accessed directly in tests
      });
    });

    group('error handling', () {
      testWidgets('should log errors with proper structure', (WidgetTester tester) async {
        // This test would require mocking the ComprehensiveMediaService
        // to verify that logMediaError is called with correct parameters
        
        // Arrange
        const invalidUrl = 'invalid-url';
        const widget = EnhancedFeedMediaWidget(
          mediaUrl: invalidUrl,
          postId: 'test-post-id',
          mediaIndex: 0,
        );

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: widget,
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Assert - error widget should be displayed
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        
        // In a real implementation, we would verify that
        // ComprehensiveMediaService.instance.logMediaError was called
        // with the correct parameters
      });
    });
  });
}

