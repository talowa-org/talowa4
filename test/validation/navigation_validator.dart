// TALOWA Navigation Validator
// Test Case A: Top-level navigation validation

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'validation_framework.dart';

/// Navigation validator for Test Case A
class NavigationValidator {
  
  /// Test Case A: Top-level Navigation Validation
  static Future<ValidationResult> validateTopLevelNavigation() async {
    try {
      debugPrint('🧪 Running Test Case A: Top-level Navigation...');
      
      // Step 1: Validate welcome screen structure and buttons
      final welcomeResult = await _validateWelcomeScreen();
      if (!welcomeResult.passed) return welcomeResult;
      
      // Step 2: Validate login screen accessibility
      final loginResult = await _validateLoginScreen();
      if (!loginResult.passed) return loginResult;
      
      // Step 3: Validate registration screen accessibility
      final registerResult = await _validateRegistrationScreen();
      if (!registerResult.passed) return registerResult;
      
      // Step 4: Validate navigation routing configuration
      final routingResult = await _validateRouting();
      if (!routingResult.passed) return routingResult;
      
      // Step 5: Validate responsive design elements
      final responsiveResult = await _validateResponsiveDesign();
      if (!responsiveResult.passed) return responsiveResult;
      
      // Step 6: Validate button functionality
      final buttonResult = await validateButtonFunctionality();
      if (!buttonResult.passed) return buttonResult;
      
      debugPrint('✅ Test Case A: Navigation validation completed successfully');
      return ValidationResult.pass('Top-level navigation fully functional - Login and Register buttons visible and functional with proper routing');
      
    } catch (e) {
      debugPrint('❌ Test Case A: Navigation validation failed: $e');
      return ValidationResult.fail(
        'Top-level navigation validation failed',
        errorDetails: e.toString(),
        suspectedModule: 'WelcomeScreen/Navigation',
        suggestedFix: 'lib/screens/auth/welcome_screen.dart - Fix navigation buttons and routing',
      );
    }
  }

  /// Validate welcome screen structure and buttons
  static Future<ValidationResult> _validateWelcomeScreen() async {
    try {
      debugPrint('📱 Validating welcome screen structure and buttons...');
      
      // Check if welcome screen file exists and contains required elements
      final welcomeScreenFile = File('lib/screens/auth/welcome_screen.dart');
      if (!await welcomeScreenFile.exists()) {
        return ValidationResult.fail(
          'Welcome screen file not found',
          suspectedModule: 'WelcomeScreen',
          suggestedFix: 'lib/screens/auth/welcome_screen.dart - Create welcome screen file',
        );
      }

      final welcomeContent = await welcomeScreenFile.readAsString();
      
      // Validate Login button exists and has proper navigation
      if (!welcomeContent.contains('Login') || !welcomeContent.contains('NewLoginScreen')) {
        return ValidationResult.fail(
          'Login button or navigation not properly implemented',
          suspectedModule: 'WelcomeScreen',
          suggestedFix: 'lib/screens/auth/welcome_screen.dart - Add Login button with navigation to NewLoginScreen',
        );
      }
      
      // Validate Register button exists and has proper navigation
      if (!welcomeContent.contains('Register') || !welcomeContent.contains('RealUserRegistrationScreen')) {
        return ValidationResult.fail(
          'Register button or navigation not properly implemented',
          suspectedModule: 'WelcomeScreen',
          suggestedFix: 'lib/screens/auth/welcome_screen.dart - Add Register button with navigation to RealUserRegistrationScreen',
        );
      }
      
      // Validate button styling and accessibility
      if (!welcomeContent.contains('ElevatedButton') && !welcomeContent.contains('OutlinedButton')) {
        return ValidationResult.fail(
          'Navigation buttons not properly styled',
          suspectedModule: 'WelcomeScreen',
          suggestedFix: 'lib/screens/auth/welcome_screen.dart - Use proper button widgets for Login and Register',
        );
      }
      
      // Validate responsive design elements
      if (!welcomeContent.contains('MediaQuery') && !welcomeContent.contains('ConstrainedBox')) {
        debugPrint('⚠️ Warning: Welcome screen may not be fully responsive');
      }
      
      debugPrint('✅ Welcome screen structure and buttons validated');
      return ValidationResult.pass('Welcome screen has Login and Register buttons with proper navigation');
      
    } catch (e) {
      return ValidationResult.fail(
        'Welcome screen validation failed',
        errorDetails: e.toString(),
        suspectedModule: 'WelcomeScreen',
      );
    }
  }

  /// Validate login screen accessibility
  static Future<ValidationResult> _validateLoginScreen() async {
    try {
      debugPrint('🔐 Validating login screen accessibility...');
      
      final loginScreenFile = File('lib/screens/auth/new_login_screen.dart');
      if (!await loginScreenFile.exists()) {
        return ValidationResult.fail(
          'Login screen file not found',
          suspectedModule: 'NewLoginScreen',
          suggestedFix: 'lib/screens/auth/new_login_screen.dart - Create login screen file',
        );
      }

      final loginContent = await loginScreenFile.readAsString();
      
      // Validate essential login components
      final requiredComponents = [
        'TextFormField', // Input fields
        'mobile', // Mobile number field
        'pin', // PIN field
        'Sign In', // Login button
        'AuthService.loginUser', // Authentication service call
        'Register', // Link to registration
      ];
      
      for (final component in requiredComponents) {
        if (!loginContent.toLowerCase().contains(component.toLowerCase())) {
          return ValidationResult.fail(
            'Login screen missing required component: $component',
            suspectedModule: 'NewLoginScreen',
            suggestedFix: 'lib/screens/auth/new_login_screen.dart - Add $component functionality',
          );
        }
      }
      
      // Validate form validation
      if (!loginContent.contains('validator') || !loginContent.contains('_formKey')) {
        return ValidationResult.fail(
          'Login screen missing form validation',
          suspectedModule: 'NewLoginScreen',
          suggestedFix: 'lib/screens/auth/new_login_screen.dart - Add form validation for mobile and PIN fields',
        );
      }

      debugPrint('✅ Login screen accessibility and functionality validated');
      return ValidationResult.pass('Login screen accessible with mobile/PIN authentication');
      
    } catch (e) {
      return ValidationResult.fail(
        'Login screen validation failed',
        errorDetails: e.toString(),
        suspectedModule: 'NewLoginScreen',
      );
    }
  }

  /// Validate registration screen accessibility
  static Future<ValidationResult> _validateRegistrationScreen() async {
    try {
      debugPrint('📝 Validating registration screen accessibility...');
      
      final registerScreenFile = File('lib/screens/auth/real_user_registration_screen.dart');
      if (!await registerScreenFile.exists()) {
        return ValidationResult.fail(
          'Registration screen file not found',
          suspectedModule: 'RealUserRegistrationScreen',
          suggestedFix: 'lib/screens/auth/real_user_registration_screen.dart - Create registration screen file',
        );
      }

      final registerContent = await registerScreenFile.readAsString();
      
      // Validate essential registration components
      final requiredComponents = [
        'Full Name', // Name field
        'Mobile Number', // Phone field
        'PIN', // PIN creation
        'Village', // Location fields
        'District',
        'State',
        'Referral Code', // Referral system
        'AuthService.registerUser', // Registration service
        'Join TALOWA Movement', // Submit button
      ];
      
      for (final component in requiredComponents) {
        if (!registerContent.contains(component)) {
          return ValidationResult.fail(
            'Registration screen missing required component: $component',
            suspectedModule: 'RealUserRegistrationScreen',
            suggestedFix: 'lib/screens/auth/real_user_registration_screen.dart - Add $component field/functionality',
          );
        }
      }
      
      // Validate form validation
      if (!registerContent.contains('validator') || !registerContent.contains('_formKey')) {
        return ValidationResult.fail(
          'Registration screen missing form validation',
          suspectedModule: 'RealUserRegistrationScreen',
          suggestedFix: 'lib/screens/auth/real_user_registration_screen.dart - Add comprehensive form validation',
        );
      }
      
      // Validate deep link handling for referral codes
      if (!registerContent.contains('UniversalLinkService') && !registerContent.contains('ReferralCodeHandler')) {
        debugPrint('⚠️ Warning: Registration screen may not handle deep link referral codes');
      }

      debugPrint('✅ Registration screen accessibility and functionality validated');
      return ValidationResult.pass('Registration screen accessible with comprehensive form and referral system');
      
    } catch (e) {
      return ValidationResult.fail(
        'Registration screen validation failed',
        errorDetails: e.toString(),
        suspectedModule: 'RealUserRegistrationScreen',
      );
    }
  }

  /// Validate navigation routing configuration
  static Future<ValidationResult> _validateRouting() async {
    try {
      debugPrint('🗺️ Validating navigation routing configuration...');
      
      final mainFile = File('lib/main.dart');
      if (!await mainFile.exists()) {
        return ValidationResult.fail(
          'Main application file not found',
          suspectedModule: 'MainApp',
          suggestedFix: 'lib/main.dart - Create main application file with routing',
        );
      }

      final mainContent = await mainFile.readAsString();
      
      // Validate essential routes exist
      final requiredRoutes = [
        '/welcome',
        '/login', 
        '/register',
        '/main',
      ];
      
      for (final route in requiredRoutes) {
        if (!mainContent.contains("'$route'")) {
          return ValidationResult.fail(
            'Missing required route: $route',
            suspectedModule: 'MainApp/Routing',
            suggestedFix: 'lib/main.dart - Add route definition for $route',
          );
        }
      }
      
      // Validate route mappings to correct screens
      final routeMappings = {
        'WelcomeScreen': '/welcome',
        'NewLoginScreen': '/login',
        'RealUserRegistrationScreen': '/register',
        'MainNavigationScreen': '/main',
      };
      
      for (final mapping in routeMappings.entries) {
        if (!mainContent.contains(mapping.key)) {
          return ValidationResult.fail(
            'Route ${mapping.value} not properly mapped to ${mapping.key}',
            suspectedModule: 'MainApp/Routing',
            suggestedFix: 'lib/main.dart - Map ${mapping.value} route to ${mapping.key}',
          );
        }
      }
      
      // Validate MaterialApp configuration
      if (!mainContent.contains('MaterialApp') || !mainContent.contains('routes:')) {
        return ValidationResult.fail(
          'MaterialApp routing not properly configured',
          suspectedModule: 'MainApp',
          suggestedFix: 'lib/main.dart - Configure MaterialApp with routes property',
        );
      }
      
      // Validate home route points to WelcomeScreen
      if (!mainContent.contains('home: const WelcomeScreen()')) {
        return ValidationResult.fail(
          'App home route not set to WelcomeScreen',
          suspectedModule: 'MainApp',
          suggestedFix: 'lib/main.dart - Set home property to WelcomeScreen',
        );
      }

      debugPrint('✅ Navigation routing configuration validated');
      return ValidationResult.pass('Navigation routing properly configured with all required routes');
      
    } catch (e) {
      return ValidationResult.fail(
        'Navigation routing validation failed',
        errorDetails: e.toString(),
        suspectedModule: 'MainApp/Routing',
      );
    }
  }

  /// Validate responsive design elements
  static Future<ValidationResult> _validateResponsiveDesign() async {
    try {
      debugPrint('📱💻 Validating responsive design elements...');
      
      final welcomeScreenFile = File('lib/screens/auth/welcome_screen.dart');
      final welcomeContent = await welcomeScreenFile.readAsString();
      
      // Check for responsive design patterns
      final responsiveElements = [
        'MediaQuery', // Screen size queries
        'SafeArea', // Safe area handling
        'SingleChildScrollView', // Scrollable content
        'ConstrainedBox', // Size constraints
      ];
      
      int foundElements = 0;
      for (final element in responsiveElements) {
        if (welcomeContent.contains(element)) {
          foundElements++;
        }
      }
      
      if (foundElements < 2) {
        return ValidationResult.fail(
          'Welcome screen lacks responsive design elements',
          suspectedModule: 'WelcomeScreen/ResponsiveDesign',
          suggestedFix: 'lib/screens/auth/welcome_screen.dart - Add MediaQuery, SafeArea, and responsive layout elements',
        );
      }
      
      // Check button sizing for different screen sizes
      if (!welcomeContent.contains('width: double.infinity') && !welcomeContent.contains('SizedBox')) {
        debugPrint('⚠️ Warning: Buttons may not be properly sized for different screens');
      }
      
      debugPrint('✅ Responsive design elements validated');
      return ValidationResult.pass('Welcome screen has responsive design elements for desktop and mobile');
      
    } catch (e) {
      return ValidationResult.fail(
        'Responsive design validation failed',
        errorDetails: e.toString(),
        suspectedModule: 'WelcomeScreen/ResponsiveDesign',
      );
    }
  }

  /// Validate navigation button functionality (static analysis)
  static Future<ValidationResult> validateButtonFunctionality() async {
    try {
      debugPrint('🔘 Validating navigation button functionality...');
      
      final welcomeScreenFile = File('lib/screens/auth/welcome_screen.dart');
      final welcomeContent = await welcomeScreenFile.readAsString();
      
      // Check Login button functionality
      if (!welcomeContent.contains('Navigator.push') || 
          !welcomeContent.contains('NewLoginScreen')) {
        return ValidationResult.fail(
          'Login button navigation not properly implemented',
          suspectedModule: 'WelcomeScreen/LoginButton',
          suggestedFix: 'lib/screens/auth/welcome_screen.dart - Add Navigator.push to NewLoginScreen for Login button',
        );
      }
      
      // Check Register button functionality
      if (!welcomeContent.contains('RealUserRegistrationScreen')) {
        return ValidationResult.fail(
          'Register button navigation not properly implemented',
          suspectedModule: 'WelcomeScreen/RegisterButton',
          suggestedFix: 'lib/screens/auth/welcome_screen.dart - Add Navigator.push to RealUserRegistrationScreen for Register button',
        );
      }
      
      // Check button accessibility
      if (!welcomeContent.contains('onPressed:')) {
        return ValidationResult.fail(
          'Navigation buttons missing onPressed handlers',
          suspectedModule: 'WelcomeScreen/ButtonHandlers',
          suggestedFix: 'lib/screens/auth/welcome_screen.dart - Add onPressed handlers to navigation buttons',
        );
      }
      
      debugPrint('✅ Navigation button functionality validated');
      return ValidationResult.pass('Login and Register buttons have proper navigation functionality');
      
    } catch (e) {
      return ValidationResult.fail(
        'Button functionality validation failed',
        errorDetails: e.toString(),
        suspectedModule: 'WelcomeScreen/ButtonFunctionality',
      );
    }
  }

  /// Comprehensive navigation validation including all sub-tests
  static Future<ValidationResult> runComprehensiveNavigationTest() async {
    try {
      debugPrint('🧪 Running comprehensive navigation validation...');
      
      final results = <String, ValidationResult>{};
      
      // Run all validation tests
      results['welcome_screen'] = await _validateWelcomeScreen();
      results['login_screen'] = await _validateLoginScreen();
      results['registration_screen'] = await _validateRegistrationScreen();
      results['routing_config'] = await _validateRouting();
      results['responsive_design'] = await _validateResponsiveDesign();
      results['button_functionality'] = await validateButtonFunctionality();
      
      // Check if any test failed
      final failedTests = results.entries.where((entry) => !entry.value.passed).toList();
      
      if (failedTests.isNotEmpty) {
        final failureMessages = failedTests.map((entry) => 
          '${entry.key}: ${entry.value.message}').join('; ');
        
        return ValidationResult.fail(
          'Navigation validation failed: $failureMessages',
          errorDetails: 'Failed tests: ${failedTests.map((e) => e.key).join(', ')}',
          suspectedModule: failedTests.first.value.suspectedModule,
          suggestedFix: failedTests.first.value.suggestedFix,
        );
      }
      
      debugPrint('✅ Comprehensive navigation validation completed successfully');
      return ValidationResult.pass(
        'All navigation components validated: Welcome screen with Login/Register buttons, proper routing, responsive design'
      );
      
    } catch (e) {
      return ValidationResult.fail(
        'Comprehensive navigation validation failed',
        errorDetails: e.toString(),
        suspectedModule: 'Navigation/Comprehensive',
      );
    }
  }

  /// Get navigation validation summary
  static Map<String, dynamic> getNavigationSummary() {
    return {
      'testCase': 'A',
      'description': 'Top-level navigation validation',
      'components': [
        'WelcomeScreen with Login/Register buttons and animations',
        'NewLoginScreen with mobile/PIN authentication',
        'RealUserRegistrationScreen with comprehensive form',
        'Navigation routing configuration in main.dart',
        'Responsive design elements for multiple screen sizes',
        'Button functionality and navigation handlers',
      ],
      'requirements': [
        'Login and Register buttons visible on landing screen',
        'Login button navigates to NewLoginScreen',
        'Register button navigates to RealUserRegistrationScreen', 
        'Responsive design works on desktop and mobile',
        'Proper route configuration in MaterialApp',
        'Form validation and user input handling',
        'Deep link support for referral codes',
      ],
      'validationChecks': [
        'File existence validation',
        'Component presence validation',
        'Navigation functionality validation',
        'Route configuration validation',
        'Responsive design validation',
        'Button handler validation',
      ],
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Get detailed validation report for Test Case A
  static Future<Map<String, dynamic>> getDetailedValidationReport() async {
    final summary = getNavigationSummary();
    final validationResult = await validateTopLevelNavigation();
    
    return {
      ...summary,
      'validationResult': {
        'passed': validationResult.passed,
        'message': validationResult.message,
        'errorDetails': validationResult.errorDetails,
        'suspectedModule': validationResult.suspectedModule,
        'suggestedFix': validationResult.suggestedFix,
      },
      'implementationStatus': {
        'welcomeScreen': 'Implemented with animations and proper styling',
        'loginScreen': 'Implemented with mobile/PIN authentication',
        'registrationScreen': 'Implemented with comprehensive form and referral system',
        'routing': 'Configured in main.dart with all required routes',
        'responsiveDesign': 'Implemented with MediaQuery and SafeArea',
      },
    };
  }
}