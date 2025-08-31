import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:flutter/rendering.dart';

/// Service for handling referral link sharing and QR code generation
class ReferralSharingService {
  
  /// Generate referral link for a given referral code
  static String generateReferralLink(String referralCode) {
    return 'https://talowa.web.app/join?ref=$referralCode';
  }

  /// Generate short referral link (could be enhanced with URL shortener)
  static String generateShortReferralLink(String referralCode) {
    // For now, return the same link. In production, you could use bit.ly or similar
    return generateReferralLink(referralCode);
  }

  /// Generate custom professional message for sharing
  static String _generateCustomMessage(String referralCode, String link, String? userName) {
    return '''
🌾 Join TALOWA - Land Rights Movement! 🌾

Hi! I'm inviting you to join TALOWA, a powerful platform that helps farmers and land owners protect their rights.

🔗 Use my referral code:
$referralCode

With TALOWA, you can:
🤝 Connect with other farmers and activists
📰 Stay informed about land rights issues
🆘 Get emergency help when needed

Together we can fight for our land rights! 💪

Join here: $link

#TALOWA #LandRights #FarmersUnity
''';
  }

  /// Copy referral code to clipboard
  static Future<void> copyReferralCode(String referralCode, BuildContext context) async {
    try {
      await Clipboard.setData(ClipboardData(text: referralCode));
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Referral code copied to clipboard!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error copying referral code: $e');
    }
  }

  /// Copy referral link to clipboard
  static Future<void> copyReferralLink(String referralCode, BuildContext context) async {
    try {
      final link = generateReferralLink(referralCode);
      await Clipboard.setData(ClipboardData(text: link));
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Referral link copied to clipboard!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error copying referral link: $e');
    }
  }

  /// Share referral link using native sharing
  static Future<void> shareReferralLink(String referralCode, {String? userName}) async {
    try {
      final link = generateReferralLink(referralCode);
      final message = _generateCustomMessage(referralCode, link, userName);
      
      // Try native sharing first
      try {
        await Share.share(
          message,
          subject: 'Join Talowa - Political Engagement Platform',
        );
        debugPrint('Share completed successfully');
      } catch (shareError) {
        debugPrint('Native sharing failed: $shareError');
        
        // Fallback for web: Use Web Share API or copy to clipboard
        if (html.window.navigator.share != null) {
          // Use Web Share API if available
          try {
            await html.window.navigator.share({
              'title': 'Join Talowa - Political Engagement Platform',
              'text': message,
              'url': link,
            });
            debugPrint('Web Share API completed successfully');
          } catch (webShareError) {
            debugPrint('Web Share API failed: $webShareError');
            // Final fallback: copy to clipboard
            await _fallbackCopyToClipboard(message);
          }
        } else {
          // Web Share API not available, copy to clipboard
          await _fallbackCopyToClipboard(message);
        }
      }
    } catch (e) {
      debugPrint('Error sharing referral link: $e');
      // Final fallback: copy to clipboard
      await _fallbackCopyToClipboard('Join Talowa using referral code: $referralCode\n\n${generateReferralLink(referralCode)}');
    }
  }

  /// Fallback method to copy message to clipboard when sharing fails
  static Future<void> _fallbackCopyToClipboard(String message) async {
    try {
      await Clipboard.setData(ClipboardData(text: message));
      debugPrint('Fallback: Message copied to clipboard');
      
      // Show a notification that it was copied
      // Note: This would need a BuildContext to show SnackBar
      // For now, just log it
      debugPrint('Message copied to clipboard as fallback');
    } catch (clipboardError) {
      debugPrint('Clipboard fallback also failed: $clipboardError');
    }
  }

  /// Share with fallback dialog for better user experience
  static Future<void> _shareWithFallback(BuildContext context, String referralCode, {String? userName}) async {
    final link = generateReferralLink(referralCode);
    final message = _generateCustomMessage(referralCode, link, userName);
    
    try {
      // Try native sharing first
      await Share.share(
        message,
        subject: 'Join Talowa - Political Engagement Platform',
      );
      debugPrint('Share completed successfully');
    } catch (shareError) {
      debugPrint('Native sharing failed: $shareError');
      
      // Show fallback dialog with options
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.share, color: Colors.orange),
                SizedBox(width: 8),
                Text('Share Referral'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Choose how to share your referral:'),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: SelectableText(
                    message,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await copyReferralLink(referralCode, context);
                          Navigator.pop(dialogContext);
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy Message'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          await shareViaWhatsApp(referralCode, userName: userName);
                        },
                        icon: const Icon(Icons.chat),
                        label: const Text('WhatsApp'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: const BorderSide(color: Colors.green),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    }
  }

  /// Share referral link via WhatsApp
  static Future<void> shareViaWhatsApp(String referralCode, {String? userName}) async {
    try {
      final link = generateReferralLink(referralCode);
      final message = _generateCustomMessage(referralCode, link, userName);
      
      debugPrint('Original message: $message');
      
      // Try multiple WhatsApp URL formats for better compatibility
      final whatsappUrls = [
        // Format 1: Standard WhatsApp Web URL
        'https://wa.me/?text=${Uri.encodeQueryComponent(message)}',
        // Format 2: Alternative encoding
        'https://api.whatsapp.com/send?text=${Uri.encodeQueryComponent(message)}',
        // Format 3: Simple encoding
        'whatsapp://send?text=${Uri.encodeQueryComponent(message)}',
      ];
      
      bool shared = false;
      
      for (final whatsappUrl in whatsappUrls) {
        try {
          debugPrint('Trying WhatsApp URL: $whatsappUrl');
          
          if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
            await launchUrl(
              Uri.parse(whatsappUrl), 
              mode: LaunchMode.externalApplication,
              webOnlyWindowName: '_blank',
            );
            shared = true;
            debugPrint('Successfully launched WhatsApp with URL: $whatsappUrl');
            break;
          }
        } catch (urlError) {
          debugPrint('Failed to launch URL $whatsappUrl: $urlError');
          continue;
        }
      }
      
      if (!shared) {
        debugPrint('All WhatsApp URLs failed, falling back to regular share');
        await shareReferralLink(referralCode, userName: userName);
      }
      
    } catch (e) {
      debugPrint('Error sharing via WhatsApp: $e');
      // Fallback to regular sharing on error
      try {
        await shareReferralLink(referralCode, userName: userName);
      } catch (fallbackError) {
        debugPrint('Fallback sharing also failed: $fallbackError');
      }
    }
  }

  /// Share referral link via Telegram
  static Future<void> shareViaTelegram(String referralCode, {String? userName}) async {
    try {
      final link = generateReferralLink(referralCode);
      final message = _generateCustomMessage(referralCode, link, userName);
      
      // Use proper URL encoding for Telegram
      final encodedUrl = Uri.encodeQueryComponent(link);
      final encodedText = Uri.encodeQueryComponent(message);
      final telegramUrl = 'https://t.me/share/url?url=$encodedUrl&text=$encodedText';
      
      debugPrint('Telegram URL: $telegramUrl');
      
      if (await canLaunchUrl(Uri.parse(telegramUrl))) {
        await launchUrl(
          Uri.parse(telegramUrl), 
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: '_blank',
        );
      } else {
        debugPrint('Cannot launch Telegram URL, falling back to regular share');
        // Fallback to regular sharing
        await shareReferralLink(referralCode, userName: userName);
      }
    } catch (e) {
      debugPrint('Error sharing via Telegram: $e');
      // Fallback to regular sharing on error
      try {
        await shareReferralLink(referralCode, userName: userName);
      } catch (fallbackError) {
        debugPrint('Fallback sharing also failed: $fallbackError');
      }
    }
  }

  /// Generate QR code widget for referral link
  static Widget generateQRCode(String referralCode, {double size = 200.0}) {
    final link = generateReferralLink(referralCode);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrImageView(
            data: link,
            version: QrVersions.auto,
            size: size,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            errorCorrectionLevel: QrErrorCorrectLevel.M,
          ),
          const SizedBox(height: 12),
          Text(
            'Scan to join with code: $referralCode',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Download QR code as image (Web only)
  static Future<void> downloadQRCode(String referralCode, {String? fileName}) async {
    try {
      final link = generateReferralLink(referralCode);
      final qrValidationResult = QrValidator.validate(
        data: link,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      );

      if (qrValidationResult.status == QrValidationStatus.valid) {
        final qrCode = qrValidationResult.qrCode!;
        final painter = QrPainter.withQr(
          qr: qrCode,
          color: const Color(0xFF000000),
          emptyColor: const Color(0xFFFFFFFF),
          gapless: false,
        );

        final picData = await painter.toImageData(300, format: ui.ImageByteFormat.png);
        if (picData != null) {
          final bytes = picData.buffer.asUint8List();
          
          // Create download link for web
          final blob = html.Blob([bytes]);
          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.document.createElement('a') as html.AnchorElement
            ..href = url
            ..style.display = 'none'
            ..download = fileName ?? 'talowa_referral_$referralCode.png';
          html.document.body?.children.add(anchor);
          anchor.click();
          html.document.body?.children.remove(anchor);
          html.Url.revokeObjectUrl(url);
          
          debugPrint('QR code downloaded successfully');
        }
      }
    } catch (e) {
      debugPrint('Error downloading QR code: $e');
    }
  }

  /// Show QR code in a dialog with download option
  static Future<void> showQRCodeDialog(BuildContext context, String referralCode, {String? userName}) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Share QR Code',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                generateQRCode(referralCode, size: 250),
                const SizedBox(height: 16),
                if (userName != null) ...[
                  Text(
                    '$userName\'s Referral',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  'Code: $referralCode',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          copyReferralLink(referralCode, context);
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy Link'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await downloadQRCode(referralCode);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('QR code downloaded!'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.download),
                        label: const Text('Download'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      shareReferralLink(referralCode, userName: userName);
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Share Link'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Show sharing options bottom sheet
  static Future<void> showSharingOptions(BuildContext context, String referralCode, {String? userName}) async {
    return showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Share Your Referral',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Code: $referralCode',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildSharingOption(
                    context,
                    icon: Icons.copy,
                    label: 'Copy Code',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      copyReferralCode(referralCode, context);
                    },
                  ),
                  _buildSharingOption(
                    context,
                    icon: Icons.link,
                    label: 'Copy Link',
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(context);
                      copyReferralLink(referralCode, context);
                    },
                  ),
                  _buildSharingOption(
                    context,
                    icon: Icons.qr_code,
                    label: 'QR Code',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pop(context);
                      showQRCodeDialog(context, referralCode, userName: userName);
                    },
                  ),
                  _buildSharingOption(
                    context,
                    icon: Icons.share,
                    label: 'Share',
                    color: Colors.orange,
                    onTap: () async {
                      Navigator.pop(context);
                      await _shareWithFallback(context, referralCode, userName: userName);
                    },
                  ),
                  _buildSharingOption(
                    context,
                    icon: Icons.chat,
                    label: 'WhatsApp',
                    color: Colors.green[700]!,
                    onTap: () {
                      Navigator.pop(context);
                      shareViaWhatsApp(referralCode, userName: userName);
                    },
                  ),
                  _buildSharingOption(
                    context,
                    icon: Icons.send,
                    label: 'Telegram',
                    color: Colors.blue[600]!,
                    onTap: () {
                      Navigator.pop(context);
                      shareViaTelegram(referralCode, userName: userName);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  /// Build sharing option widget
  static Widget _buildSharingOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}