// PostCreationScreen Tests
// Part of Task 9: Build PostCreationScreen for coordinators

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:talowa/models/social_feed/post_model.dart';
import 'package:talowa/screens/social_feed/post_creation_screen.dart';

// Mock classes
class MockAuthService extends Mock {
  static User? get currentUser => null;
}

void main() {
  group('PostCreationScreen', () {
    testWidgets('should display post creation form', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PostCreationScreen(),
        ),
      );
      
      // Verify form elements are displayed
      expect(find.text('Create Post'), findsOneWidget);
      expect(find.text('Title (Optional)'), findsOneWidget);
      expect(find.text('Content'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Priority'), findsOneWidget);
      expect(find.text('Geographic Targeting'), findsOneWidget);
      expect(find.text('Visibility'), findsOneWidget);
    });
    
    testWidgets('should show role verification banner', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PostCreationScreen(),
        ),
      );
      
      // Should show some kind of role verification
      expect(find.byIcon(Icons.warning), findsOneWidget);
    });
    
    testWidgets('should validate required content field', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PostCreationScreen(),
        ),
      );
      
      // Try to publish without content
      final publishButton = find.text('Publish');
      expect(publishButton, findsOneWidget);
      
      // The button should be disabled when content is empty
      final button = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('Publish'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(button.onPressed, isNull);
    });
    
    testWidgets('should show character count', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PostCreationScreen(),
        ),
      );
      
      // Should show character count
      expect(find.text('0/2000'), findsOneWidget);
    });
    
    testWidgets('should display category options', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PostCreationScreen(),
        ),
      );
      
      // Should show category selection
      expect(find.text('General Discussion'), findsOneWidget);
      expect(find.text('Announcement'), findsOneWidget);
      expect(find.text('Success Story'), findsOneWidget);
    });
    
    testWidgets('should display priority options', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PostCreationScreen(),
        ),
      );
      
      // Should show priority dropdown
      expect(find.byType(DropdownButtonFormField<PostPriority>), findsOneWidget);
    });
    
    testWidgets('should display visibility options', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PostCreationScreen(),
        ),
      );
      
      // Should show visibility options
      expect(find.text('Public'), findsOneWidget);
      expect(find.text('Coordinators Only'), findsOneWidget);
      expect(find.text('Local Community'), findsOneWidget);
    });
    
    testWidgets('should show preview toggle', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PostCreationScreen(),
        ),
      );
      
      // Should show preview button
      expect(find.byIcon(Icons.preview), findsOneWidget);
    });
    
    testWidgets('should handle back button with confirmation', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PostCreationScreen(),
        ),
      );
      
      // Add some content
      await tester.enterText(
        find.byType(TextFormField).first,
        'Test content',
      );
      
      // Tap back button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      
      // Should show confirmation dialog
      expect(find.text('Discard Changes?'), findsOneWidget);
    });
    
    testWidgets('should initialize form for editing', (WidgetTester tester) async {
      final editingPost = PostModel(
        id: 'test_post',
        authorId: 'user_123',
        authorName: 'Test User',
        title: 'Test Title',
        content: 'Test content for editing',
        category: PostCategory.announcement,
        priority: PostPriority.high,
        createdAt: DateTime.now(),
      );
      
      await tester.pumpWidget(
        MaterialApp(
          home: PostCreationScreen(editingPost: editingPost),
        ),
      );
      
      // Should show edit mode
      expect(find.text('Edit Post'), findsOneWidget);
      expect(find.text('Update'), findsOneWidget);
      
      // Should populate form fields
      expect(find.text('Test Title'), findsOneWidget);
      expect(find.text('Test content for editing'), findsOneWidget);
    });
    
    testWidgets('should show media attachment section', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PostCreationScreen(),
        ),
      );
      
      // Should show media section
      expect(find.text('Media Attachments'), findsOneWidget);
    });
    
    testWidgets('should show hashtag input section', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PostCreationScreen(),
        ),
      );
      
      // Should show hashtag section
      expect(find.text('Hashtags'), findsOneWidget);
    });
  });
  
  group('PostCreationScreen Validation', () {
    testWidgets('should validate content length', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PostCreationScreen(),
        ),
      );
      
      // Enter content that exceeds limit
      final longContent = 'A' * 2001; // Exceeds 2000 character limit
      await tester.enterText(
        find.byType(TextFormField).last, // Content field
        longContent,
      );
      
      // Character count should show red
      expect(find.text('2001/2000'), findsOneWidget);
    });
    
    testWidgets('should validate title length', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PostCreationScreen(),
        ),
      );
      
      // Enter title that exceeds limit
      final longTitle = 'A' * 101; // Exceeds 100 character limit
      await tester.enterText(
        find.byType(TextFormField).first, // Title field
        longTitle,
      );
      
      // Should show character count
      expect(find.text('101/100'), findsOneWidget);
    });
  });
  
  group('PostCreationScreen Preview', () {
    testWidgets('should toggle preview mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PostCreationScreen(),
        ),
      );
      
      // Add some content first
      await tester.enterText(
        find.byType(TextFormField).last,
        'Test content for preview',
      );
      
      // Tap preview button
      await tester.tap(find.byIcon(Icons.preview));
      await tester.pumpAndSettle();
      
      // Should show preview mode
      expect(find.text('Post Preview'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);
    });
  });
}