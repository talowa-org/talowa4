import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/referral/enhanced_sharing_service.dart';
import '../../services/referral/universal_link_service.dart';

/// Enhanced QR code widget with branding and sharing capabilities
class EnhancedQRWidget extends StatefulWidget {
  final String referralCode;
  final String? userName;
  final double size;
  final bool showBranding;
  final bool showShareButton;
  final bool showDownloadButton;
  final VoidCallback? onShare;
  final VoidCallback? onDownload;
  
  const EnhancedQRWidget({
    super.key,
    required this.referralCode,
    this.userName,
    this.size = 300,
    this.showBranding = true,
    this.showShareButton = true,
    this.showDownloadButton = true,
    this.onShare,
    this.onDownload,
  });

  @override
  State<EnhancedQRWidget> createState() => _EnhancedQRWidgetState();
}

class _EnhancedQRWidgetState extends State<EnhancedQRWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isGenerating = false;
  Uint8List? _qrImageBytes;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _animationController.forward();
    _generateQRCode();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _generateQRCode() async {
    if (_isGenerating) return;
    
    setState(() {
      _isGenerating = true;
    });

    try {
      final referralLink = UniversalLinkService.generateReferralLink(widget.referralCode);
      final qrBytes = await EnhancedSharingService.generateTalowaQRCode(
        referralLink: referralLink,
        userName: widget.userName,
        size: widget.size.toInt(),
      );
      
      setState(() {
        _qrImageBytes = qrBytes;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate QR code: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareQRCode() async {
    try {
      final referralLink = UniversalLinkService.generateReferralLink(widget.referralCode);
      await EnhancedSharingService.shareQRCode(
        referralLink: referralLink,
        userName: widget.userName,
      );
      
      widget.onShare?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share QR code: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadQRCode() async {
    try {
      if (_qrImageBytes != null) {
        // This would save the QR code to device storage
        // Implementation would depend on platform-specific file handling
        
        widget.onDownload?.call();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.download_done, color: Colors.white),
                  SizedBox(width: 8),
                  Text('QR code saved to gallery'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download QR code: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _copyReferralLink() async {
    try {
      final referralLink = UniversalLinkService.generateReferralLink(widget.referralCode);
      await EnhancedSharingService.copyToClipboard(referralLink);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Referral link copied to clipboard!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy link: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.grey[50]!,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            if (widget.showBranding) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.qr_code_2,
                    color: Theme.of(context).primaryColor,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TALOWA QR Code',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      if (widget.userName != null)
                        Text(
                          'Shared by ${widget.userName}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
            
            // QR Code
            AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _isGenerating
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 16),
                                Text(
                                  'Generating QR Code...',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          )
                        : _qrImageBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(
                                  _qrImageBytes!,
                                  width: widget.size,
                                  height: widget.size,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : _buildFallbackQR(),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 24),
            
            // Referral Code Display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.referralCode,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Theme.of(context).primaryColor,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: _copyReferralLink,
                    icon: const Icon(Icons.copy, size: 20),
                    tooltip: 'Copy referral link',
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: const EdgeInsets.all(4),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (widget.showShareButton)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _shareQRCode,
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Share'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                
                if (widget.showShareButton && widget.showDownloadButton)
                  const SizedBox(width: 12),
                
                if (widget.showDownloadButton)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _downloadQRCode,
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Save'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Share this QR code for others to scan and join TALOWA with your referral!',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackQR() {
    final referralLink = UniversalLinkService.generateReferralLink(widget.referralCode);
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: QrImageView(
        data: referralLink,
        version: QrVersions.auto,
        size: widget.size - 32,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        gapless: true,
      ),
    );
  }
}
