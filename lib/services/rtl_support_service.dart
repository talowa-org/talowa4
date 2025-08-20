// RTL (Right-to-Left) Support Service for TALOWA
// Handles text direction, layout, and UI adjustments for Arabic and Urdu

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'localization_service.dart';

class RTLSupportService {
  static bool _isInitialized = false;
  
  /// Initialize RTL support service
  static Future<void> initialize() async {
    try {
      if (_isInitialized) return;
      
      _isInitialized = true;
      debugPrint('RTLSupportService initialized');
    } catch (e) {
      debugPrint('Error initializing RTLSupportService: $e');
    }
  }
  
  /// Check if current language is RTL
  static bool get isCurrentLanguageRTL => LocalizationService.isRTL;
  
  /// Get text direction for current language
  static TextDirection get currentTextDirection => 
      isCurrentLanguageRTL ? TextDirection.rtl : TextDirection.ltr;
  
  /// Get text direction for specific language
  static TextDirection getTextDirectionForLanguage(String languageCode) {
    return LocalizationService.rtlLanguages.contains(languageCode) 
        ? TextDirection.rtl 
        : TextDirection.ltr;
  }
  
  /// Get text alignment for current language
  static TextAlign get currentTextAlign => 
      isCurrentLanguageRTL ? TextAlign.right : TextAlign.left;
  
  /// Get text alignment for specific language
  static TextAlign getTextAlignForLanguage(String languageCode) {
    return LocalizationService.rtlLanguages.contains(languageCode)
        ? TextAlign.right
        : TextAlign.left;
  }
  
  /// Get edge insets with RTL support
  static EdgeInsets getDirectionalPadding({
    double start = 0.0,
    double top = 0.0,
    double end = 0.0,
    double bottom = 0.0,
  }) {
    if (isCurrentLanguageRTL) {
      return EdgeInsets.only(
        left: end,
        top: top,
        right: start,
        bottom: bottom,
      );
    } else {
      return EdgeInsets.only(
        left: start,
        top: top,
        right: end,
        bottom: bottom,
      );
    }
  }
  
  /// Get margin with RTL support
  static EdgeInsets getDirectionalMargin({
    double start = 0.0,
    double top = 0.0,
    double end = 0.0,
    double bottom = 0.0,
  }) {
    return getDirectionalPadding(
      start: start,
      top: top,
      end: end,
      bottom: bottom,
    );
  }
  
  /// Get border radius with RTL support
  static BorderRadius getDirectionalBorderRadius({
    double topStart = 0.0,
    double topEnd = 0.0,
    double bottomStart = 0.0,
    double bottomEnd = 0.0,
  }) {
    if (isCurrentLanguageRTL) {
      return BorderRadius.only(
        topLeft: Radius.circular(topEnd),
        topRight: Radius.circular(topStart),
        bottomLeft: Radius.circular(bottomEnd),
        bottomRight: Radius.circular(bottomStart),
      );
    } else {
      return BorderRadius.only(
        topLeft: Radius.circular(topStart),
        topRight: Radius.circular(topEnd),
        bottomLeft: Radius.circular(bottomStart),
        bottomRight: Radius.circular(bottomEnd),
      );
    }
  }
  
  /// Get icon alignment for current language
  static MainAxisAlignment get iconAlignment => 
      isCurrentLanguageRTL ? MainAxisAlignment.end : MainAxisAlignment.start;
  
  /// Get cross axis alignment for current language
  static CrossAxisAlignment get crossAxisAlignment => 
      isCurrentLanguageRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start;
  
  /// Get message bubble alignment for sender/receiver
  static CrossAxisAlignment getMessageAlignment({required bool isSender}) {
    if (isCurrentLanguageRTL) {
      return isSender ? CrossAxisAlignment.start : CrossAxisAlignment.end;
    } else {
      return isSender ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    }
  }
  
  /// Get message bubble border radius
  static BorderRadius getMessageBubbleBorderRadius({required bool isSender}) {
    const radius = 16.0;
    const smallRadius = 4.0;
    
    if (isCurrentLanguageRTL) {
      return isSender
          ? const BorderRadius.only(
              topLeft: Radius.circular(radius),
              topRight: Radius.circular(radius),
              bottomLeft: Radius.circular(radius),
              bottomRight: Radius.circular(smallRadius),
            )
          : const BorderRadius.only(
              topLeft: Radius.circular(radius),
              topRight: Radius.circular(radius),
              bottomLeft: Radius.circular(smallRadius),
              bottomRight: Radius.circular(radius),
            );
    } else {
      return isSender
          ? const BorderRadius.only(
              topLeft: Radius.circular(radius),
              topRight: Radius.circular(radius),
              bottomLeft: Radius.circular(smallRadius),
              bottomRight: Radius.circular(radius),
            )
          : const BorderRadius.only(
              topLeft: Radius.circular(radius),
              topRight: Radius.circular(radius),
              bottomLeft: Radius.circular(radius),
              bottomRight: Radius.circular(smallRadius),
            );
    }
  }
  
  /// Get navigation drawer alignment
  static Alignment get drawerAlignment => 
      isCurrentLanguageRTL ? Alignment.centerRight : Alignment.centerLeft;
  
  /// Get floating action button position
  static FloatingActionButtonLocation get fabLocation => 
      isCurrentLanguageRTL 
          ? FloatingActionButtonLocation.startFloat 
          : FloatingActionButtonLocation.endFloat;
  
  /// Get list tile leading/trailing positions
  static Widget? getListTileLeading(Widget? widget) {
    return isCurrentLanguageRTL ? null : widget;
  }
  
  static Widget? getListTileTrailing(Widget? widget) {
    return isCurrentLanguageRTL ? widget : null;
  }
  
  /// Format text with proper RTL markers
  static String formatRTLText(String text, String languageCode) {
    if (!LocalizationService.rtlLanguages.contains(languageCode)) {
      return text;
    }
    
    // Add RTL markers for proper text rendering
    const rtlMark = '\u200F'; // Right-to-Left Mark
    const ltrMark = '\u200E'; // Left-to-Right Mark
    
    // Handle mixed content (RTL text with LTR numbers/English)
    final mixedContentRegex = RegExp(r'[a-zA-Z0-9]+');
    
    return text.replaceAllMapped(mixedContentRegex, (match) {
      return '$ltrMark${match.group(0)}$rtlMark';
    });
  }
  
  /// Get keyboard type for RTL languages
  static TextInputType getKeyboardType(String languageCode) {
    if (LocalizationService.rtlLanguages.contains(languageCode)) {
      return TextInputType.multiline; // Better support for RTL text
    }
    return TextInputType.text;
  }
  
  /// Get text input action for RTL
  static TextInputAction get textInputAction => 
      isCurrentLanguageRTL ? TextInputAction.newline : TextInputAction.done;
  
  /// Create RTL-aware positioned widget
  static Widget createPositioned({
    required Widget child,
    double? start,
    double? end,
    double? top,
    double? bottom,
  }) {
    if (isCurrentLanguageRTL) {
      return Positioned(
        left: end,
        right: start,
        top: top,
        bottom: bottom,
        child: child,
      );
    } else {
      return Positioned(
        left: start,
        right: end,
        top: top,
        bottom: bottom,
        child: child,
      );
    }
  }
  
  /// Create RTL-aware row with proper spacing
  static Widget createDirectionalRow({
    required List<Widget> children,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    MainAxisSize mainAxisSize = MainAxisSize.max,
  }) {
    final adjustedAlignment = isCurrentLanguageRTL
        ? _reverseMainAxisAlignment(mainAxisAlignment)
        : mainAxisAlignment;
    
    final adjustedChildren = isCurrentLanguageRTL
        ? children.reversed.toList()
        : children;
    
    return Row(
      mainAxisAlignment: adjustedAlignment,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: adjustedChildren,
    );
  }
  
  /// Create RTL-aware app bar
  static AppBar createDirectionalAppBar({
    required String title,
    List<Widget>? actions,
    Widget? leading,
    bool automaticallyImplyLeading = true,
  }) {
    return AppBar(
      title: Text(
        title,
        textDirection: currentTextDirection,
        textAlign: currentTextAlign,
      ),
      leading: isCurrentLanguageRTL ? null : leading,
      actions: isCurrentLanguageRTL 
          ? (leading != null ? [leading] : null)
          : actions,
      automaticallyImplyLeading: automaticallyImplyLeading,
    );
  }
  
  /// Get RTL-aware icon data
  static IconData getDirectionalIcon(IconData ltrIcon, IconData rtlIcon) {
    return isCurrentLanguageRTL ? rtlIcon : ltrIcon;
  }
  
  /// Common directional icons
  static IconData get backIcon => 
      getDirectionalIcon(Icons.arrow_back, Icons.arrow_forward);
  
  static IconData get forwardIcon => 
      getDirectionalIcon(Icons.arrow_forward, Icons.arrow_back);
  
  static IconData get menuIcon => 
      getDirectionalIcon(Icons.menu, Icons.menu);
  
  static IconData get sendIcon => 
      getDirectionalIcon(Icons.send, Icons.send);
  
  /// Helper method to reverse main axis alignment
  static MainAxisAlignment _reverseMainAxisAlignment(MainAxisAlignment alignment) {
    switch (alignment) {
      case MainAxisAlignment.start:
        return MainAxisAlignment.end;
      case MainAxisAlignment.end:
        return MainAxisAlignment.start;
      case MainAxisAlignment.spaceBetween:
        return MainAxisAlignment.spaceBetween;
      case MainAxisAlignment.spaceAround:
        return MainAxisAlignment.spaceAround;
      case MainAxisAlignment.spaceEvenly:
        return MainAxisAlignment.spaceEvenly;
      case MainAxisAlignment.center:
        return MainAxisAlignment.center;
    }
  }
  
  /// Get font family for RTL languages
  static String? getFontFamily(String languageCode) {
    switch (languageCode) {
      case 'ar':
        return 'NotoSansArabic'; // Arabic font
      case 'ur':
        return 'NotoNastaliqUrdu'; // Urdu font
      default:
        return null; // Use default font
    }
  }
  
  /// Get text style with RTL support
  static TextStyle getTextStyle({
    required String languageCode,
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: getFontFamily(languageCode),
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }
  
  /// Create RTL-aware text widget
  static Widget createDirectionalText(
    String text, {
    String? languageCode,
    TextStyle? style,
    TextAlign? textAlign,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    final lang = languageCode ?? LocalizationService.currentLanguage;
    final direction = getTextDirectionForLanguage(lang);
    final align = textAlign ?? getTextAlignForLanguage(lang);
    
    return Text(
      formatRTLText(text, lang),
      textDirection: direction,
      textAlign: align,
      style: style?.copyWith(
        fontFamily: getFontFamily(lang),
      ) ?? getTextStyle(languageCode: lang),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}