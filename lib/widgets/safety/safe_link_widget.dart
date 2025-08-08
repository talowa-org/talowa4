// Safe Link Widget for TALOWA
// Implements Task 19: Build user safety features - Safe Link Display

import 'package:flutter/material.dart';
import '../../services/safety/safe_browsing_service.dart';

class SafeLinkWidget extends StatefulWidget {
  final String url;
  final String? displayText;
  final TextStyle? style;
  final bool showWarningDialog;
  final VoidCallback? onTap;

  const SafeLinkWidget({
    Key? key,
    required this.url,
    this.displayText,
    this.style,
    this.showWarningDialog = true,
    this.onTap,
  }) : super(key: key);

  @override
  State<SafeLinkWidget> createState() => _SafeLinkWidgetState();
}

class _SafeLinkWidgetState extends State<SafeLinkWidget> {
  final SafeBrowsingService _safeBrowsingService = SafeBrowsingService();
  
  SafeBrowsingResult? _safetyResult;
  bool _isChecking = false;
  bool _hasChecked = false;

  @override
  void initState() {
    super.initState();
    _checkUrlSafety();
  }

  Future<void> _checkUrlSafety() async {
    if (_hasChecked) return;
    
    setState(() {
      _isChecking = true;
    });

    try {
      final result = await _safeBrowsingService.checkUrlSafety(widget.url);
      setState(() {
        _safetyResult = result;
        _isChecking = false;
        _hasChecked = true;
      });
    } catch (e) {
      setState(() {
        _isChecking = false;
        _hasChecked = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.displayText ?? widget.url,
            style: widget.style?.copyWith(color: Colors.grey) ?? 
                   TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(width: 4),
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () => _handleLinkTap(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.displayText ?? _formatUrl(widget.url),
            style: widget.style ?? TextStyle(
              color: _getLinkColor(),
              decoration: TextDecoration.underline,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            _getSafetyIcon(),
            size: 16,
            color: _getSafetyIconColor(),
          ),
        ],
      ),
    );
  }

  Color _getLinkColor() {
    if (_safetyResult == null) return Colors.blue;
    
    switch (_safetyResult!.riskLevel) {
      case RiskLevel.low:
        return Colors.blue;
      case RiskLevel.medium:
        return Colors.orange;
      case RiskLevel.high:
      case RiskLevel.critical:
        return Colors.red;
    }
  }

  IconData _getSafetyIcon() {
    if (_safetyResult == null) return Icons.link;
    
    if (_safetyResult!.isSafe) {
      return Icons.verified_user;
    } else {
      switch (_safetyResult!.riskLevel) {
        case RiskLevel.medium:
          return Icons.warning;
        case RiskLevel.high:
        case RiskLevel.critical:
          return Icons.dangerous;
        case RiskLevel.low:
          return Icons.info;
      }
    }
  }

  Color _getSafetyIconColor() {
    if (_safetyResult == null) return Colors.grey;
    
    if (_safetyResult!.isSafe) {
      return Colors.green;
    } else {
      switch (_safetyResult!.riskLevel) {
        case RiskLevel.medium:
          return Colors.orange;
        case RiskLevel.high:
        case RiskLevel.critical:
          return Colors.red;
        case RiskLevel.low:
          return Colors.blue;
      }
    }
  }

  String _formatUrl(String url) {
    if (url.length > 50) {
      return '${url.substring(0, 47)}...';
    }
    return url;
  }

  void _handleLinkTap(BuildContext context) {
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }

    if (_safetyResult == null) {
      _showLoadingDialog(context);
      return;
    }

    if (_safetyResult!.isSafe) {
      _launchUrl();
    } else if (widget.showWarningDialog) {
      _showSafetyWarningDialog(context);
    } else {
      _launchUrl();
    }
  }

  void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Checking link safety...'),
          ],
        ),
      ),
    );

    // Wait for safety check to complete
    _checkUrlSafety().then((_) {
      Navigator.pop(context);
      _handleLinkTap(context);
    });
  }

  void _showSafetyWarningDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning,
              color: _getSafetyIconColor(),
            ),
            const SizedBox(width: 8),
            const Text('Link Safety Warning'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This link may not be safe to visit:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                widget.url,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Risk Level: ${_getRiskLevelText(_safetyResult!.riskLevel)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _getSafetyIconColor(),
              ),
            ),
            if (_safetyResult!.warnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Warnings:', style: TextStyle(fontWeight: FontWeight.bold)),
              ..._safetyResult!.warnings.map((warning) => 
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Text('• $warning', style: const TextStyle(fontSize: 12)),
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Do you still want to visit this link?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => _reportMaliciousLink(context),
            child: const Text('Report Link'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _launchUrl();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Visit Anyway'),
          ),
        ],
      ),
    );
  }

  void _reportMaliciousLink(BuildContext context) {
    Navigator.pop(context); // Close warning dialog
    
    showDialog(
      context: context,
      builder: (context) => ReportLinkDialog(url: widget.url),
    );
  }

  String _getRiskLevelText(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return 'Low';
      case RiskLevel.medium:
        return 'Medium';
      case RiskLevel.high:
        return 'High';
      case RiskLevel.critical:
        return 'Critical';
    }
  }

  void _launchUrl() async {
    try {
      await _safeBrowsingService.launchUrlSafely(widget.url, forceCheck: false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open link: $e')),
      );
    }
  }
}

class ReportLinkDialog extends StatefulWidget {
  final String url;

  const ReportLinkDialog({Key? key, required this.url}) : super(key: key);

  @override
  State<ReportLinkDialog> createState() => _ReportLinkDialogState();
}

class _ReportLinkDialogState extends State<ReportLinkDialog> {
  final SafeBrowsingService _safeBrowsingService = SafeBrowsingService();
  final TextEditingController _reasonController = TextEditingController();
  
  String _selectedReason = 'malware';
  bool _isSubmitting = false;

  final Map<String, String> _reportReasons = {
    'malware': 'Malware or virus',
    'phishing': 'Phishing or scam',
    'inappropriate': 'Inappropriate content',
    'spam': 'Spam or unwanted content',
    'other': 'Other safety concern',
  };

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report Malicious Link'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('URL: ${widget.url}'),
          const SizedBox(height: 16),
          const Text('Why are you reporting this link?'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedReason,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Reason',
            ),
            items: _reportReasons.entries.map((entry) {
              return DropdownMenuItem(
                value: entry.key,
                child: Text(entry.value),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedReason = value!;
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Additional details (optional)',
              hintText: 'Describe the issue...',
            ),
            maxLines: 3,
            maxLength: 500,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Submit Report'),
        ),
      ],
    );
  }

  Future<void> _submitReport() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      await _safeBrowsingService.reportMaliciousUrl(
        url: widget.url,
        reporterId: 'current_user', // Replace with actual user ID
        reason: _selectedReason,
        description: _reasonController.text.trim().isEmpty 
            ? null 
            : _reasonController.text.trim(),
      );

      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link reported successfully. Thank you for helping keep TALOWA safe!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error reporting link: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }
}

// Helper function to create safe links from text
class SafeTextWidget extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final bool enableSafeLinks;

  const SafeTextWidget({
    Key? key,
    required this.text,
    this.style,
    this.enableSafeLinks = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!enableSafeLinks) {
      return Text(text, style: style);
    }

    final safeBrowsingService = SafeBrowsingService();
    final urls = safeBrowsingService.extractUrlsFromText(text);
    
    if (urls.isEmpty) {
      return Text(text, style: style);
    }

    return RichText(
      text: _buildTextSpan(text, urls),
    );
  }

  TextSpan _buildTextSpan(String text, List<String> urls) {
    final spans = <TextSpan>[];
    int lastIndex = 0;

    for (final url in urls) {
      final urlIndex = text.indexOf(url, lastIndex);
      
      // Add text before URL
      if (urlIndex > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, urlIndex),
          style: style,
        ));
      }

      // Add safe link widget (simplified as text span for RichText)
      spans.add(TextSpan(
        text: url,
        style: style?.copyWith(
          color: Colors.blue,
          decoration: TextDecoration.underline,
        ) ?? const TextStyle(
          color: Colors.blue,
          decoration: TextDecoration.underline,
        ),
      ));

      lastIndex = urlIndex + url.length;
    }

    // Add remaining text
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: style,
      ));
    }

    return TextSpan(children: spans);
  }
}