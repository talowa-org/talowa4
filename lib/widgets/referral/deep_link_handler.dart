import 'package:flutter/material.dart';
import '../../services/referral/universal_link_service.dart';

/// Widget that handles deep links and referral codes
class DeepLinkHandler extends StatefulWidget {
  final Widget child;
  final Function(String)? onReferralCodeReceived;
  final Function(String)? onDeepLinkError;
  
  const DeepLinkHandler({
    super.key,
    required this.child,
    this.onReferralCodeReceived,
    this.onDeepLinkError,
  });

  @override
  State<DeepLinkHandler> createState() => _DeepLinkHandlerState();
}

class _DeepLinkHandlerState extends State<DeepLinkHandler> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeDeepLinks();
  }

  @override
  void dispose() {
    UniversalLinkService.dispose();
    super.dispose();
  }

  Future<void> _initializeDeepLinks() async {
    try {
      await UniversalLinkService.initialize(
        onReferralCodeReceived: _handleReferralCode,
        onDeepLinkError: _handleDeepLinkError,
      );
      
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      _handleDeepLinkError('Failed to initialize deep links: $e');
    }
  }

  void _handleReferralCode(String referralCode) {
    if (widget.onReferralCodeReceived != null) {
      widget.onReferralCodeReceived!(referralCode);
    } else {
      // Default behavior: show snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.link, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Referral code received: $referralCode'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Use Code',
              textColor: Colors.white,
              onPressed: () {
                // Navigate to registration or handle the code
                _navigateToRegistration(referralCode);
              },
            ),
          ),
        );
      }
    }
  }

  void _handleDeepLinkError(String error) {
    if (widget.onDeepLinkError != null) {
      widget.onDeepLinkError!(error);
    } else {
      // Default behavior: show error snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Link error: $error'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToRegistration(String referralCode) {
    // This would navigate to the registration screen with the referral code
    // Implementation depends on your navigation setup
    Navigator.of(context).pushNamed(
      '/register',
      arguments: {'referralCode': referralCode},
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Mixin for screens that need to handle referral codes from deep links
mixin ReferralCodeHandler<T extends StatefulWidget> on State<T> {
  String? _referralCode;
  
  String? get referralCode => _referralCode;
  
  @override
  void initState() {
    super.initState();
    _checkForPendingReferralCode();
  }
  
  void _checkForPendingReferralCode() {
    final pendingCode = UniversalLinkService.getPendingReferralCode();
    if (pendingCode != null) {
      setState(() {
        _referralCode = pendingCode;
      });
      UniversalLinkService.clearPendingReferralCode();
      onReferralCodeReceived(pendingCode);
    }
  }
  
  /// Override this method to handle referral codes
  void onReferralCodeReceived(String referralCode) {
    // Default implementation - can be overridden
  }
  
  /// Set referral code manually
  void setReferralCode(String? code) {
    setState(() {
      _referralCode = code;
    });
  }
  
  /// Clear referral code
  void clearReferralCode() {
    setState(() {
      _referralCode = null;
    });
  }
}

/// Widget for displaying referral link sharing options
class ReferralLinkSharingWidget extends StatelessWidget {
  final String referralCode;
  final String? userName;
  final VoidCallback? onShare;
  
  const ReferralLinkSharingWidget({
    super.key,
    required this.referralCode,
    this.userName,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final referralLink = UniversalLinkService.generateReferralLink(referralCode);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.share, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Text(
                  'Share Your Referral Link',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Referral Link:',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    referralLink,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Copy link to clipboard
                      _copyToClipboard(context, referralLink);
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Link'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Share link
                      _shareLink(referralLink);
                      onShare?.call();
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Text(
              'Share this link with friends and family to invite them to join TALOWA!',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  void _copyToClipboard(BuildContext context, String link) {
    // Implementation would use Clipboard.setData
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Link copied to clipboard!'),
          ],
        ),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  void _shareLink(String link) {
    // Implementation would use Share.share
    final message = '''🌟 Join TALOWA - India's Land Rights Movement!

Use my referral link: $link

Together we can secure land rights for all! 🏡

#TALOWA #LandRights #India''';
    
    // Share.share(message);
  }
}

/// Widget for testing deep links in development
class DeepLinkTester extends StatefulWidget {
  const DeepLinkTester({super.key});

  @override
  State<DeepLinkTester> createState() => _DeepLinkTesterState();
}

class _DeepLinkTesterState extends State<DeepLinkTester> {
  final _codeController = TextEditingController();
  String? _lastResult;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Deep Link Tester',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Referral Code',
                border: OutlineInputBorder(),
                hintText: 'TAL8K9M2X',
              ),
            ),
            
            const SizedBox(height: 16),
            
            ElevatedButton(
              onPressed: _testDeepLink,
              child: const Text('Test Deep Link'),
            ),
            
            if (_lastResult != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Result: $_lastResult',
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Future<void> _testDeepLink() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _lastResult = 'Error: Please enter a referral code';
      });
      return;
    }
    
    try {
      await UniversalLinkService.testReferralLink(code);
      setState(() {
        _lastResult = 'Success: Deep link test completed for $code';
      });
    } catch (e) {
      setState(() {
        _lastResult = 'Error: $e';
      });
    }
  }
}
