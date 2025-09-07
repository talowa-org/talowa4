// Accessibility Service - Comprehensive accessibility support for TALOWA platform
// Complete accessibility features including screen reader, keyboard navigation, and compliance

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccessibilityService {
  static AccessibilityService? _instance;
  static AccessibilityService get instance => _instance ??= AccessibilityService._internal();
  
  AccessibilityService._internal();
  
  SharedPreferences? _prefs;
  bool _isInitialized = false;
  
  // Accessibility settings
  bool _isScreenReaderEnabled = false;
  bool _isHighContrastEnabled = false;
  bool _isLargeTextEnabled = false;
  bool _isReducedMotionEnabled = false;
  bool _isKeyboardNavigationEnabled = false;
  double _textScaleFactor = 1.0;
  AccessibilityColorScheme _colorScheme = AccessibilityColorScheme.standard;
  
  // Keyboard navigation
  final Map<String, FocusNode> _focusNodes = {};
  final List<String> _focusOrder = [];
  int _currentFocusIndex = -1;
  
  // Screen reader announcements
  final StreamController<String> _announcementController = StreamController<String>.broadcast();
  Stream<String> get announcements => _announcementController.stream;
  
  /// Initialize accessibility service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      debugPrint('â™¿ Initializing Accessibility Service...');
      
      _prefs = await SharedPreferences.getInstance();
      
      // Load accessibility settings
      await _loadAccessibilitySettings();
      
      // Setup system accessibility detection
      await _detectSystemAccessibilitySettings();
      
      // Initialize keyboard navigation
      _initializeKeyboardNavigation();
      
      _isInitialized = true;
      debugPrint('âœ… Accessibility Service initialized');
      
    } catch (e) {
      debugPrint('âŒ Failed to initialize accessibility service: $e');
    }
  }
  
  /// Enable screen reader support
  Future<void> enableScreenReader(bool enabled) async {
    try {
      _isScreenReaderEnabled = enabled;
      await _prefs?.setBool('screen_reader_enabled', enabled);
      
      if (enabled) {
        debugPrint('ðŸ”Š Screen reader enabled');
        await announceToScreenReader('Screen reader enabled');
      } else {
        debugPrint('ðŸ”‡ Screen reader disabled');
      }
      
    } catch (e) {
      debugPrint('âŒ Failed to toggle screen reader: $e');
    }
  }
  
  /// Enable high contrast mode
  Future<void> enableHighContrast(bool enabled) async {
    try {
      _isHighContrastEnabled = enabled;
      await _prefs?.setBool('high_contrast_enabled', enabled);
      
      debugPrint('ðŸŽ¨ High contrast ${enabled ? 'enabled' : 'disabled'}');
      
    } catch (e) {
      debugPrint('âŒ Failed to toggle high contrast: $e');
    }
  }
  
  /// Enable large text
  Future<void> enableLargeText(bool enabled) async {
    try {
      _isLargeTextEnabled = enabled;
      _textScaleFactor = enabled ? 1.3 : 1.0;
      
      await _prefs?.setBool('large_text_enabled', enabled);
      await _prefs?.setDouble('text_scale_factor', _textScaleFactor);
      
      debugPrint('ðŸ“ Large text ${enabled ? 'enabled' : 'disabled'}');
      
    } catch (e) {
      debugPrint('âŒ Failed to toggle large text: $e');
    }
  }
  
  /// Enable reduced motion
  Future<void> enableReducedMotion(bool enabled) async {
    try {
      _isReducedMotionEnabled = enabled;
      await _prefs?.setBool('reduced_motion_enabled', enabled);
      
      debugPrint('ðŸŽ¬ Reduced motion ${enabled ? 'enabled' : 'disabled'}');
      
    } catch (e) {
      debugPrint('âŒ Failed to toggle reduced motion: $e');
    }
  }
  
  /// Enable keyboard navigation
  Future<void> enableKeyboardNavigation(bool enabled) async {
    try {
      _isKeyboardNavigationEnabled = enabled;
      await _prefs?.setBool('keyboard_navigation_enabled', enabled);
      
      if (enabled) {
        _setupKeyboardShortcuts();
      }
      
      debugPrint('âŒ¨ï¸ Keyboard navigation ${enabled ? 'enabled' : 'disabled'}');
      
    } catch (e) {
      debugPrint('âŒ Failed to toggle keyboard navigation: $e');
    }
  }
  
  /// Set text scale factor
  Future<void> setTextScaleFactor(double factor) async {
    try {
      _textScaleFactor = factor.clamp(0.8, 2.0);
      await _prefs?.setDouble('text_scale_factor', _textScaleFactor);
      
      debugPrint('ðŸ“ Text scale factor set to: $_textScaleFactor');
      
    } catch (e) {
      debugPrint('âŒ Failed to set text scale factor: $e');
    }
  }
  
  /// Set accessibility color scheme
  Future<void> setColorScheme(AccessibilityColorScheme scheme) async {
    try {
      _colorScheme = scheme;
      await _prefs?.setString('color_scheme', scheme.name);
      
      debugPrint('ðŸŽ¨ Color scheme set to: ${scheme.name}');
      
    } catch (e) {
      debugPrint('âŒ Failed to set color scheme: $e');
    }
  }
  
  /// Announce text to screen reader
  Future<void> announceToScreenReader(String text) async {
    try {
      if (!_isScreenReaderEnabled) return;
      
      // Add to announcement stream
      _announcementController.add(text);
      
      // Use system accessibility announcement
      await SystemChannels.accessibility.invokeMethod('announce', text);
      
      debugPrint('ðŸ“¢ Screen reader announcement: $text');
      
    } catch (e) {
      debugPrint('âŒ Failed to announce to screen reader: $e');
    }
  }
  
  /// Create accessible widget wrapper
  Widget createAccessibleWidget({
    required Widget child,
    required String semanticLabel,
    String? semanticHint,
    bool isButton = false,
    bool isHeader = false,
    bool isLink = false,
    VoidCallback? onTap,
    String? focusKey,
  }) {
    Widget accessibleChild = child;
    
    // Add semantic information
    accessibleChild = Semantics(
      label: semanticLabel,
      hint: semanticHint,
      button: isButton,
      header: isHeader,
      link: isLink,
      onTap: onTap,
      child: accessibleChild,
    );
    
    // Add focus support for keyboard navigation
    if (_isKeyboardNavigationEnabled && focusKey != null) {
      final focusNode = _getFocusNode(focusKey);
      
      accessibleChild = Focus(
        focusNode: focusNode,
        onFocusChange: (hasFocus) {
          if (hasFocus) {
            announceToScreenReader('Focused on $semanticLabel');
          }
        },
        child: accessibleChild,
      );
    }
    
    // Add high contrast support
    if (_isHighContrastEnabled) {
      accessibleChild = _applyHighContrastTheme(accessibleChild);
    }
    
    return accessibleChild;
  }
  
  /// Create accessible text widget
  Widget createAccessibleText(
    String text, {
    TextStyle? style,
    String? semanticLabel,
    bool isHeader = false,
    int? headerLevel,
  }) {
    final accessibleStyle = (style ?? const TextStyle()).copyWith(
      fontSize: (style?.fontSize ?? 14) * _textScaleFactor,
    );
    
    return Semantics(
      label: semanticLabel ?? text,
      header: isHeader,
      child: Text(
        text,
        style: _isHighContrastEnabled 
            ? _applyHighContrastTextStyle(accessibleStyle)
            : accessibleStyle,
      ),
    );
  }
  
  /// Create accessible button
  Widget createAccessibleButton({
    required String label,
    required VoidCallback onPressed,
    Widget? child,
    String? hint,
    ButtonStyle? style,
    String? focusKey,
  }) {
    return createAccessibleWidget(
      semanticLabel: label,
      semanticHint: hint,
      isButton: true,
      onTap: onPressed,
      focusKey: focusKey,
      child: ElevatedButton(
        onPressed: onPressed,
        style: _isHighContrastEnabled 
            ? _applyHighContrastButtonStyle(style)
            : style,
        child: child ?? Text(label),
      ),
    );
  }
  
  /// Navigate to next focusable element
  void navigateToNext() {
    if (!_isKeyboardNavigationEnabled || _focusOrder.isEmpty) return;
    
    _currentFocusIndex = (_currentFocusIndex + 1) % _focusOrder.length;
    final nextKey = _focusOrder[_currentFocusIndex];
    final nextNode = _focusNodes[nextKey];
    
    nextNode?.requestFocus();
    
    debugPrint('âŒ¨ï¸ Navigated to: $nextKey');
  }
  
  /// Navigate to previous focusable element
  void navigateToPrevious() {
    if (!_isKeyboardNavigationEnabled || _focusOrder.isEmpty) return;
    
    _currentFocusIndex = _currentFocusIndex <= 0 
        ? _focusOrder.length - 1 
        : _currentFocusIndex - 1;
    
    final previousKey = _focusOrder[_currentFocusIndex];
    final previousNode = _focusNodes[previousKey];
    
    previousNode?.requestFocus();
    
    debugPrint('âŒ¨ï¸ Navigated to: $previousKey');
  }
  
  /// Get accessibility settings
  AccessibilitySettings getAccessibilitySettings() {
    return AccessibilitySettings(
      isScreenReaderEnabled: _isScreenReaderEnabled,
      isHighContrastEnabled: _isHighContrastEnabled,
      isLargeTextEnabled: _isLargeTextEnabled,
      isReducedMotionEnabled: _isReducedMotionEnabled,
      isKeyboardNavigationEnabled: _isKeyboardNavigationEnabled,
      textScaleFactor: _textScaleFactor,
      colorScheme: _colorScheme,
    );
  }
  
  /// Load accessibility settings from preferences
  Future<void> _loadAccessibilitySettings() async {
    if (_prefs == null) return;
    
    _isScreenReaderEnabled = _prefs!.getBool('screen_reader_enabled') ?? false;
    _isHighContrastEnabled = _prefs!.getBool('high_contrast_enabled') ?? false;
    _isLargeTextEnabled = _prefs!.getBool('large_text_enabled') ?? false;
    _isReducedMotionEnabled = _prefs!.getBool('reduced_motion_enabled') ?? false;
    _isKeyboardNavigationEnabled = _prefs!.getBool('keyboard_navigation_enabled') ?? false;
    _textScaleFactor = _prefs!.getDouble('text_scale_factor') ?? 1.0;
    
    final colorSchemeName = _prefs!.getString('color_scheme') ?? 'standard';
    _colorScheme = AccessibilityColorScheme.values.firstWhere(
      (scheme) => scheme.name == colorSchemeName,
      orElse: () => AccessibilityColorScheme.standard,
    );
    
    debugPrint('ðŸ“‹ Accessibility settings loaded');
  }
  
  /// Detect system accessibility settings
  Future<void> _detectSystemAccessibilitySettings() async {
    try {
      // This would integrate with platform-specific accessibility APIs
      // For now, we'll use Flutter's built-in accessibility detection
      
      final mediaQuery = MediaQueryData.fromView(WidgetsBinding.instance.window);
      
      if (mediaQuery.accessibleNavigation) {
        await enableScreenReader(true);
      }
      
      if (mediaQuery.highContrast) {
        await enableHighContrast(true);
      }
      
      if (mediaQuery.disableAnimations) {
        await enableReducedMotion(true);
      }
      
      if (mediaQuery.textScaleFactor > 1.0) {
        await setTextScaleFactor(mediaQuery.textScaleFactor);
      }
      
      debugPrint('ðŸ” System accessibility settings detected');
      
    } catch (e) {
      debugPrint('âŒ Failed to detect system accessibility settings: $e');
    }
  }
  
  /// Initialize keyboard navigation
  void _initializeKeyboardNavigation() {
    // This would be expanded based on the app's navigation structure
    debugPrint('âŒ¨ï¸ Keyboard navigation initialized');
  }
  
  /// Setup keyboard shortcuts
  void _setupKeyboardShortcuts() {
    // This would define app-specific keyboard shortcuts
    debugPrint('âŒ¨ï¸ Keyboard shortcuts setup');
  }
  
  /// Get or create focus node
  FocusNode _getFocusNode(String key) {
    if (!_focusNodes.containsKey(key)) {
      _focusNodes[key] = FocusNode();
      _focusOrder.add(key);
    }
    return _focusNodes[key]!;
  }
  
  /// Apply high contrast theme
  Widget _applyHighContrastTheme(Widget child) {
    return Theme(
      data: ThemeData.from(
        colorScheme: const ColorScheme.highContrast(),
      ),
      child: child,
    );
  }
  
  /// Apply high contrast text style
  TextStyle _applyHighContrastTextStyle(TextStyle style) {
    return style.copyWith(
      color: Colors.white,
      backgroundColor: Colors.black,
      fontWeight: FontWeight.bold,
    );
  }
  
  /// Apply high contrast button style
  ButtonStyle? _applyHighContrastButtonStyle(ButtonStyle? style) {
    return ElevatedButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: Colors.black,
      side: const BorderSide(color: Colors.white, width: 2),
    );
  }
  
  /// Dispose resources
  void dispose() {
    _announcementController.close();
    
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    _focusNodes.clear();
    _focusOrder.clear();
    
    debugPrint('ðŸ—‘ï¸ Accessibility Service disposed');
  }
}

// Data Classes and Enums

class AccessibilitySettings {
  final bool isScreenReaderEnabled;
  final bool isHighContrastEnabled;
  final bool isLargeTextEnabled;
  final bool isReducedMotionEnabled;
  final bool isKeyboardNavigationEnabled;
  final double textScaleFactor;
  final AccessibilityColorScheme colorScheme;

  const AccessibilitySettings({
    required this.isScreenReaderEnabled,
    required this.isHighContrastEnabled,
    required this.isLargeTextEnabled,
    required this.isReducedMotionEnabled,
    required this.isKeyboardNavigationEnabled,
    required this.textScaleFactor,
    required this.colorScheme,
  });
}

enum AccessibilityColorScheme {
  standard,
  highContrast,
  darkMode,
  protanopia,
  deuteranopia,
  tritanopia,
}

