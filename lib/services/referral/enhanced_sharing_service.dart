import 'dart:io';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Exception thrown when sharing operations fail
class SharingException implements Exception {
  final String message;
  final String code;
  final Map<String, dynamic>? context;
  
  const SharingException(this.message, [this.code = 'SHARING_FAILED', this.context]);
  
  @override
  String toString() => 'SharingException: $message';
}

/// Enhanced sharing service for referral codes and links
class EnhancedSharingService {
  static const String TALOWA_BRAND_COLOR = '#2E7D32'; // Green
  static const String TALOWA_ACCENT_COLOR = '#FF6B35'; // Orange
  
  /// Share referral code with native sharing
  static Future<void> shareReferralCode({
    required String referralCode,
    required String referralLink,
    String? userName,
    String? customMessage,
    Rect? sharePositionOrigin,
  }) async {
    try {
      final message = customMessage ?? _generateShareMessage(referralCode, referralLink, userName);
      
      if (sharePositionOrigin != null) {
        await Share.share(
          message,
          subject: 'Join TALOWA Movement',
          sharePositionOrigin: sharePositionOrigin,
        );
      } else {
        await Share.share(
          message,
          subject: 'Join TALOWA Movement',
        );
      }
    } catch (e) {
      throw SharingException(
        'Failed to share referral code: $e',
        'NATIVE_SHARE_FAILED',
        {'referralCode': referralCode, 'error': e.toString()}
      );
    }
  }
  
  /// Share referral code to specific platform
  static Future<void> shareToSpecificPlatform({
    required String platform,
    required String referralCode,
    required String referralLink,
    String? userName,
  }) async {
    try {
      final message = _generatePlatformSpecificMessage(platform, referralCode, referralLink, userName);
      
      switch (platform.toLowerCase()) {
        case 'whatsapp':
          await _shareToWhatsApp(message);
          break;
        case 'facebook':
          await _shareToFacebook(message, referralLink);
          break;
        case 'twitter':
          await _shareToTwitter(message);
          break;
        case 'linkedin':
          await _shareToLinkedIn(message, referralLink);
          break;
        case 'instagram':
          await _shareToInstagram(message);
          break;
        case 'telegram':
          await _shareToTelegram(message);
          break;
        default:
          await shareReferralCode(
            referralCode: referralCode,
            referralLink: referralLink,
            userName: userName,
            customMessage: message,
          );
      }
    } catch (e) {
      throw SharingException(
        'Failed to share to $platform: $e',
        'PLATFORM_SHARE_FAILED',
        {'platform': platform, 'referralCode': referralCode, 'error': e.toString()}
      );
    }
  }
  
  /// Generate high-quality branded QR code
  static Future<Uint8List> generateBrandedQRCode({
    required String referralLink,
    int size = 512,
    bool includeLogo = true,
    Color? backgroundColor,
    Color? foregroundColor,
  }) async {
    try {
      final painter = QrPainter(
        data: referralLink,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        dataModuleStyle: QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: foregroundColor ?? Colors.black,
        ),
        eyeStyle: QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: foregroundColor ?? Colors.black,
        ),
        gapless: true,
      );
      
      final picData = await painter.toImageData(size.toDouble());
      return picData!.buffer.asUint8List();
    } catch (e) {
      throw SharingException(
        'Failed to generate QR code: $e',
        'QR_GENERATION_FAILED',
        {'referralLink': referralLink, 'size': size}
      );
    }
  }
  
  /// Generate branded QR code with TALOWA branding
  static Future<Uint8List> generateTalowaQRCode({
    required String referralLink,
    String? userName,
    int size = 512,
  }) async {
    try {
      // Create a custom painter for branded QR code
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint();
      
      // Background
      paint.color = Colors.white;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()), paint);
      
      // QR Code area (80% of total size)
      final qrSize = (size * 0.8).toInt();
      final qrOffset = (size - qrSize) / 2;
      
      // Generate QR code
      final qrBytes = await generateBrandedQRCode(
        referralLink: referralLink,
        size: qrSize,
        backgroundColor: Colors.white,
        foregroundColor: Color(int.parse(TALOWA_BRAND_COLOR.substring(1), radix: 16) + 0xFF000000),
      );
      
      // Draw QR code
      final qrImage = await _bytesToImage(qrBytes);
      canvas.drawImage(qrImage, Offset(qrOffset, qrOffset), paint);
      
      // Add TALOWA branding
      await _addTalowaBranding(canvas, size, userName);
      
      final picture = recorder.endRecording();
      final img = await picture.toImage(size, size);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      
      return byteData!.buffer.asUint8List();
    } catch (e) {
      throw SharingException(
        'Failed to generate TALOWA QR code: $e',
        'BRANDED_QR_FAILED',
        {'referralLink': referralLink, 'userName': userName}
      );
    }
  }
  
  /// Copy text to clipboard with confirmation
  static Future<void> copyToClipboard(String text, {String? confirmationMessage}) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (e) {
      throw SharingException(
        'Failed to copy to clipboard: $e',
        'CLIPBOARD_FAILED',
        {'text': text}
      );
    }
  }
  
  /// Share QR code image
  static Future<void> shareQRCode({
    required String referralLink,
    String? userName,
    String? customMessage,
  }) async {
    try {
      final qrBytes = await generateTalowaQRCode(
        referralLink: referralLink,
        userName: userName,
      );
      
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/talowa_qr_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(qrBytes);
      
      final message = customMessage ?? 'Scan this QR code to join TALOWA with my referral!';
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: message,
        subject: 'Join TALOWA Movement',
      );
      
      // Clean up temp file after a delay
      Future.delayed(const Duration(minutes: 5), () {
        if (file.existsSync()) {
          file.deleteSync();
        }
      });
    } catch (e) {
      throw SharingException(
        'Failed to share QR code: $e',
        'QR_SHARE_FAILED',
        {'referralLink': referralLink}
      );
    }
  }
  
  /// Get available sharing platforms
  static List<String> getAvailablePlatforms() {
    final platforms = <String>['whatsapp', 'facebook', 'twitter', 'linkedin', 'telegram'];
    
    if (Platform.isIOS) {
      platforms.add('imessage');
    }
    
    if (Platform.isAndroid) {
      platforms.add('sms');
    }
    
    return platforms;
  }
  
  /// Check if specific platform is available
  static Future<bool> isPlatformAvailable(String platform) async {
    try {
      // This would require platform-specific checks
      // For now, return true for common platforms
      final availablePlatforms = getAvailablePlatforms();
      return availablePlatforms.contains(platform.toLowerCase());
    } catch (e) {
      return false;
    }
  }
  
  /// Generate share message for referral
  static String _generateShareMessage(String referralCode, String referralLink, String? userName) {
    final userPart = userName != null ? '$userName invites you to join ' : 'Join ';
    
    return '''🌟 ${userPart}TALOWA - India's Land Rights Movement!

Use referral code: $referralCode
Or click: $referralLink

Together we can secure land rights for all! 🏡

#TALOWA #LandRights #India #JoinTheMovement''';
  }
  
  /// Generate platform-specific message
  static String _generatePlatformSpecificMessage(String platform, String referralCode, String referralLink, String? userName) {
    switch (platform.toLowerCase()) {
      case 'whatsapp':
        return '''🌟 Join TALOWA Movement! 🌟

${userName != null ? '$userName invited you to' : 'You\'re invited to'} join India's largest land rights platform.

🔗 Use code: *$referralCode*
📱 Or click: $referralLink

Together for land rights! 🏡 #TALOWA''';
        
      case 'twitter':
        return '''🌟 Joining @TALOWA_Official - India's land rights movement! 

Use code: $referralCode
$referralLink

#TALOWA #LandRights #India''';
        
      case 'facebook':
        return '''🌟 Join TALOWA - India's Land Rights Movement!

I'm inviting you to be part of something bigger - securing land rights for all Indians.

Use my referral code: $referralCode
Or click this link: $referralLink

Together, we can make a difference! 🏡

#TALOWA #LandRights #India #JoinTheMovement''';
        
      case 'linkedin':
        return '''I'm excited to invite you to join TALOWA - India's premier land rights advocacy platform.

As someone passionate about social justice and land rights, I believe you'd be interested in this movement that's working to secure land ownership for millions of Indians.

Join using my referral code: $referralCode
Or visit: $referralLink

#TALOWA #LandRights #SocialJustice #India''';
        
      default:
        return _generateShareMessage(referralCode, referralLink, userName);
    }
  }
  
  /// Share to WhatsApp
  static Future<void> _shareToWhatsApp(String message) async {
    final encodedMessage = Uri.encodeComponent(message);
    // final url = 'whatsapp://send?text=$encodedMessage';
    // This would use url_launcher to open WhatsApp
    // await launchUrl(Uri.parse(url));

    // For now, just validate the message is encoded
    assert(encodedMessage.isNotEmpty);
  }
  
  /// Share to Facebook
  static Future<void> _shareToFacebook(String message, String link) async {
    final encodedMessage = Uri.encodeComponent(message);
    final encodedLink = Uri.encodeComponent(link);
    // final url = 'https://www.facebook.com/sharer/sharer.php?u=$encodedLink&quote=$encodedMessage';
    // This would use url_launcher to open Facebook
    // await launchUrl(Uri.parse(url));

    // For now, just validate the parameters are encoded
    assert(encodedMessage.isNotEmpty && encodedLink.isNotEmpty);
  }

  /// Share to Twitter
  static Future<void> _shareToTwitter(String message) async {
    final encodedMessage = Uri.encodeComponent(message);
    // final url = 'https://twitter.com/intent/tweet?text=$encodedMessage';
    // This would use url_launcher to open Twitter
    // await launchUrl(Uri.parse(url));

    // For now, just validate the message is encoded
    assert(encodedMessage.isNotEmpty);
  }

  /// Share to LinkedIn
  static Future<void> _shareToLinkedIn(String message, String link) async {
    final encodedLink = Uri.encodeComponent(link);
    // final url = 'https://www.linkedin.com/sharing/share-offsite/?url=$encodedLink';
    // This would use url_launcher to open LinkedIn
    // await launchUrl(Uri.parse(url));

    // For now, just validate the link is encoded
    assert(encodedLink.isNotEmpty && message.isNotEmpty);
  }

  /// Share to Instagram
  static Future<void> _shareToInstagram(String message) async {
    // Instagram doesn't support direct text sharing, would need to share as story
    assert(message.isNotEmpty);
    throw const SharingException('Instagram sharing requires image/story format', 'INSTAGRAM_TEXT_NOT_SUPPORTED');
  }

  /// Share to Telegram
  static Future<void> _shareToTelegram(String message) async {
    final encodedMessage = Uri.encodeComponent(message);
    // final url = 'https://t.me/share/url?text=$encodedMessage';
    // This would use url_launcher to open Telegram
    // await launchUrl(Uri.parse(url));

    // For now, just validate the message is encoded
    assert(encodedMessage.isNotEmpty);
  }
  
  /// Convert bytes to image
  static Future<ui.Image> _bytesToImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }
  
  /// Add TALOWA branding to canvas
  static Future<void> _addTalowaBranding(Canvas canvas, int size, String? userName) async {
    // final paint = Paint(); // Not used in current implementation
    
    // Add TALOWA logo/text at bottom
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'TALOWA',
        style: TextStyle(
          fontSize: size * 0.06,
          fontWeight: FontWeight.bold,
          color: Color(int.parse(TALOWA_BRAND_COLOR.substring(1), radix: 16) + 0xFF000000),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    final textOffset = Offset(
      (size - textPainter.width) / 2,
      size * 0.9,
    );
    textPainter.paint(canvas, textOffset);
    
    // Add user name if provided
    if (userName != null) {
      final userTextPainter = TextPainter(
        text: TextSpan(
          text: 'Shared by $userName',
          style: TextStyle(
            fontSize: size * 0.03,
            color: Colors.grey[600],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      userTextPainter.layout();
      final userTextOffset = Offset(
        (size - userTextPainter.width) / 2,
        size * 0.05,
      );
      userTextPainter.paint(canvas, userTextOffset);
    }
  }
}
