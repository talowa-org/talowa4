import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/referral/universal_link_service.dart';
import '../../services/referral/qr_code_service.dart';
import '../../widgets/referral/deep_link_handler.dart';

/// Demo screen showing how referral link auto-fill works
class ReferralLinkDemoScreen extends StatefulWidget {
  const ReferralLinkDemoScreen({super.key});

  @override
  State<ReferralLinkDemoScreen> createState() => _ReferralLinkDemoScreenState();
}

class _ReferralLinkDemoScreenState extends State<ReferralLinkDemoScreen> 
    with ReferralCodeHandler {
  final _referralCodeController = TextEditingController();
  final _testLinkController = TextEditingController();
  String? _lastReceivedCode;
  String? _generatedLink;
  
  @override
  void initState() {
    super.initState();
    
    // Check for pending referral code from deep link
    final pendingCode = UniversalLinkService.getPendingReferralCode();
    if (pendingCode != null) {
      _setReferralCode(pendingCode);
    }
    
    // Set example link
    _testLinkController.text = 'https://talowa.web.app/join?ref=TAL234567';
  }

  @override
  void onReferralCodeReceived(String referralCode) {
    _setReferralCode(referralCode);
    
    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('Referral code auto-filled: $referralCode'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _setReferralCode(String referralCode) {
    setState(() {
      _referralCodeController.text = referralCode;
      _lastReceivedCode = referralCode;
    });
  }

  @override
  void dispose() {
    _referralCodeController.dispose();
    _testLinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Referral Link Auto-Fill Demo'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: DeepLinkHandler(
        onReferralCodeReceived: onReferralCodeReceived,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoCard(),
              const SizedBox(height: 24),
              _buildTestSection(),
              const SizedBox(height: 24),
              _buildRegistrationFormDemo(),
              const SizedBox(height: 24),
              _buildLinkGeneratorSection(),
              const SizedBox(height: 24),
              _buildInstructionsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Auto-Fill System Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '✅ Deep link handling is active\n'
              '✅ Universal links are supported\n'
              '✅ QR code scanning is available\n'
              '✅ Auto-fill is enabled',
              style: TextStyle(fontSize: 14),
            ),
            if (_lastReceivedCode != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Last received code: $_lastReceivedCode',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTestSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Test Deep Link',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _testLinkController,
              decoration: InputDecoration(
                labelText: 'Test Link',
                hintText: 'https://talowa.web.app/join?ref=TAL234567',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.content_paste),
                  onPressed: _pasteFromClipboard,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _testDeepLink,
                    icon: const Icon(Icons.link),
                    label: const Text('Test Link'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _scanQRCode,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan QR'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationFormDemo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Registration Form (Demo)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This simulates how the referral code would auto-fill in the registration form:',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _referralCodeController,
              decoration: InputDecoration(
                labelText: 'Referral Code',
                hintText: 'Will auto-fill from deep links',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.people),
                suffixIcon: _referralCodeController.text.isNotEmpty
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
              ),
              readOnly: true,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/register');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Go to Real Registration'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkGeneratorSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Generate Referral Link',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _generateReferralLink,
              icon: const Icon(Icons.link),
              label: const Text('Generate Link for TAL234567'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            if (_generatedLink != null) ...[
              const SizedBox(height: 12),
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
                    const Text(
                      'Generated Link:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      _generatedLink!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => _copyToClipboard(_generatedLink!),
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy Link'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[600],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsSection() {
    return Card(
      color: Colors.amber[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber[800]),
                const SizedBox(width: 8),
                Text(
                  'How It Works',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '1. User clicks a referral link (e.g., https://talowa.web.app/join?ref=TAL234567)\n'
              '2. App opens and extracts the referral code from the URL\n'
              '3. Code is stored temporarily and auto-fills in registration forms\n'
              '4. User sees a notification that the code was auto-filled\n'
              '5. Registration proceeds with the referral relationship\n\n'
              'Supported link formats:\n'
              '• https://talowa.web.app/join?ref=CODE\n'
              '• https://talowa.web.app/join/CODE\n'
              '• QR codes containing referral links\n'
              '• Custom app schemes (talowa://join?ref=CODE)',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testDeepLink() async {
    final link = _testLinkController.text.trim();
    if (link.isEmpty) {
      _showError('Please enter a test link');
      return;
    }

    try {
      await UniversalLinkService.testReferralLink(link);
      _showSuccess('Deep link test completed successfully');
    } catch (e) {
      _showError('Failed to test deep link: $e');
    }
  }

  Future<void> _scanQRCode() async {
    try {
      final result = await QRCodeService.scanQRCode();
      if (result != null && result.isNotEmpty) {
        _testLinkController.text = result;
        await _testDeepLink();
      }
    } catch (e) {
      _showError('Failed to scan QR code: $e');
    }
  }

  Future<void> _generateReferralLink() async {
    try {
      final link = UniversalLinkService.generateReferralLink('TAL234567');
      setState(() {
        _generatedLink = link;
      });
      _showSuccess('Referral link generated successfully');
    } catch (e) {
      _showError('Failed to generate referral link: $e');
    }
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null) {
        _testLinkController.text = data!.text!;
      }
    } catch (e) {
      _showError('Failed to paste from clipboard: $e');
    }
  }

  Future<void> _copyToClipboard(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      _showSuccess('Link copied to clipboard');
    } catch (e) {
      _showError('Failed to copy to clipboard: $e');
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
