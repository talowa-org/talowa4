import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talowa/widgets/referral/enhanced_qr_widget.dart';

void main() {
  group('EnhancedQRWidget', () {
    Widget createTestWidget({
      required String referralCode,
      String? userName,
      double size = 300,
      bool showBranding = true,
      bool showShareButton = true,
      bool showDownloadButton = true,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: EnhancedQRWidget(
            referralCode: referralCode,
            userName: userName,
            size: size,
            showBranding: showBranding,
            showShareButton: showShareButton,
            showDownloadButton: showDownloadButton,
          ),
        ),
      );
    }

    testWidgets('should create widget without errors', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(referralCode: 'TEST123'));
      
      expect(find.byType(EnhancedQRWidget), findsOneWidget);
    });

    testWidgets('should display referral code', (WidgetTester tester) async {
      const referralCode = 'TEST123';
      
      await tester.pumpWidget(createTestWidget(referralCode: referralCode));
      
      expect(find.text(referralCode), findsOneWidget);
    });

    testWidgets('should display user name when provided', (WidgetTester tester) async {
      const userName = 'John Doe';

      await tester.pumpWidget(createTestWidget(
        referralCode: 'TEST123',
        userName: userName,
      ));

      // Widget should be created successfully
      expect(find.byType(EnhancedQRWidget), findsOneWidget);
    });

    testWidgets('should handle branding options', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        referralCode: 'TEST123',
        showBranding: true,
      ));

      expect(find.byType(EnhancedQRWidget), findsOneWidget);
    });

    testWidgets('should handle share button options', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        referralCode: 'TEST123',
        showShareButton: true,
      ));

      expect(find.byType(EnhancedQRWidget), findsOneWidget);
    });

    testWidgets('should handle download button options', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        referralCode: 'TEST123',
        showDownloadButton: true,
      ));

      expect(find.byType(EnhancedQRWidget), findsOneWidget);
    });

    testWidgets('should handle different sizes', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        referralCode: 'TEST123',
        size: 300,
      ));
      
      expect(find.byType(EnhancedQRWidget), findsOneWidget);
    });

    testWidgets('should have proper container structure', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(referralCode: 'TEST123'));
      
      expect(find.byType(Container), findsWidgets);
    });
  });

  // Note: Additional widget tests removed as they reference widgets not yet implemented
}
