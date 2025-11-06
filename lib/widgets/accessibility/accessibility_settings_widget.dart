// Accessibility Settings Widget - Comprehensive accessibility configuration
// Complete accessibility settings interface for TALOWA platform

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../services/accessibility/accessibility_service.dart';

class AccessibilitySettingsWidget extends StatefulWidget {
  const AccessibilitySettingsWidget({super.key});

  @override
  State<AccessibilitySettingsWidget> createState() => _AccessibilitySettingsWidgetState();
}

class _AccessibilitySettingsWidgetState extends State<AccessibilitySettingsWidget> {
  AccessibilitySettings _settings = const AccessibilitySettings(
    isScreenReaderEnabled: false,
    isHighContrastEnabled: false,
    isLargeTextEnabled: false,
    isReducedMotionEnabled: false,
    isKeyboardNavigationEnabled: false,
    textScaleFactor: 1.0,
    colorScheme: AccessibilityColorScheme.standard,
  );

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      _settings = AccessibilityService.instance.getAccessibilitySettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AccessibilityService.instance.createAccessibleText(
          'Accessibility Settings',
          isHeader: true,
          headerLevel: 1,
        ),
        backgroundColor: _settings.isHighContrastEnabled 
            ? Colors.black 
            : AppTheme.primaryColor,
        foregroundColor: _settings.isHighContrastEnabled 
            ? Colors.white 
            : Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Vision Accessibility'),
            const SizedBox(height: 16),
            _buildScreenReaderSection(),
            const SizedBox(height: 16),
            _buildHighContrastSection(),
            const SizedBox(height: 16),
            _buildTextSizeSection(),
            const SizedBox(height: 24),
            
            _buildSectionHeader('Motor Accessibility'),
            const SizedBox(height: 16),
            _buildKeyboardNavigationSection(),
            const SizedBox(height: 16),
            _buildReducedMotionSection(),
            const SizedBox(height: 24),
            
            _buildSectionHeader('Color & Contrast'),
            const SizedBox(height: 16),
            _buildColorSchemeSection(),
            const SizedBox(height: 24),
            
            _buildSectionHeader('Quick Actions'),
            const SizedBox(height: 16),
            _buildQuickActionsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return AccessibilityService.instance.createAccessibleText(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: _settings.isHighContrastEnabled ? Colors.white : Colors.black87,
      ),
      isHeader: true,
      headerLevel: 2,
    );
  }

  Widget _buildScreenReaderSection() {
    return _buildSettingCard(
      icon: Icons.record_voice_over,
      title: 'Screen Reader Support',
      description: 'Enable voice announcements and screen reader compatibility',
      child: Switch(
        value: _settings.isScreenReaderEnabled,
        onChanged: (value) async {
          await AccessibilityService.instance.enableScreenReader(value);
          _loadSettings();
          
          if (value) {
            HapticFeedback.lightImpact();
          }
        },
        activeThumbColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildHighContrastSection() {
    return _buildSettingCard(
      icon: Icons.contrast,
      title: 'High Contrast Mode',
      description: 'Increase contrast for better visibility',
      child: Switch(
        value: _settings.isHighContrastEnabled,
        onChanged: (value) async {
          await AccessibilityService.instance.enableHighContrast(value);
          _loadSettings();
          HapticFeedback.lightImpact();
        },
        activeThumbColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildTextSizeSection() {
    return _buildSettingCard(
      icon: Icons.text_fields,
      title: 'Text Size',
      description: 'Adjust text size for better readability',
      child: Column(
        children: [
          Row(
            children: [
              AccessibilityService.instance.createAccessibleText(
                'A',
                style: TextStyle(
                  fontSize: 12 * _settings.textScaleFactor,
                  color: _settings.isHighContrastEnabled ? Colors.white : Colors.grey[600],
                ),
              ),
              Expanded(
                child: Slider(
                  value: _settings.textScaleFactor,
                  min: 0.8,
                  max: 2.0,
                  divisions: 12,
                  label: '${(_settings.textScaleFactor * 100).round()}%',
                  onChanged: (value) async {
                    await AccessibilityService.instance.setTextScaleFactor(value);
                    _loadSettings();
                    HapticFeedback.selectionClick();
                  },
                  activeColor: AppTheme.primaryColor,
                ),
              ),
              AccessibilityService.instance.createAccessibleText(
                'A',
                style: TextStyle(
                  fontSize: 20 * _settings.textScaleFactor,
                  color: _settings.isHighContrastEnabled ? Colors.white : Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTextSizeButton('Small', 0.8),
              _buildTextSizeButton('Normal', 1.0),
              _buildTextSizeButton('Large', 1.3),
              _buildTextSizeButton('Extra Large', 1.6),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextSizeButton(String label, double scale) {
    final isSelected = (_settings.textScaleFactor - scale).abs() < 0.1;
    
    return AccessibilityService.instance.createAccessibleButton(
      label: '$label text size',
      hint: isSelected ? 'Currently selected' : 'Tap to select',
      onPressed: () async {
        await AccessibilityService.instance.setTextScaleFactor(scale);
        _loadSettings();
        HapticFeedback.lightImpact();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected 
            ? AppTheme.primaryColor 
            : (_settings.isHighContrastEnabled ? Colors.grey[800] : Colors.grey[200]),
        foregroundColor: isSelected 
            ? Colors.white 
            : (_settings.isHighContrastEnabled ? Colors.white : Colors.black87),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12 * _settings.textScaleFactor),
      ),
    );
  }

  Widget _buildKeyboardNavigationSection() {
    return _buildSettingCard(
      icon: Icons.keyboard,
      title: 'Keyboard Navigation',
      description: 'Enable keyboard shortcuts and tab navigation',
      child: Column(
        children: [
          Switch(
            value: _settings.isKeyboardNavigationEnabled,
            onChanged: (value) async {
              await AccessibilityService.instance.enableKeyboardNavigation(value);
              _loadSettings();
              HapticFeedback.lightImpact();
            },
            activeThumbColor: AppTheme.primaryColor,
          ),
          if (_settings.isKeyboardNavigationEnabled) ...[
            const SizedBox(height: 12),
            _buildKeyboardShortcutsInfo(),
          ],
        ],
      ),
    );
  }

  Widget _buildKeyboardShortcutsInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _settings.isHighContrastEnabled 
            ? Colors.grey[800] 
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AccessibilityService.instance.createAccessibleText(
            'Keyboard Shortcuts:',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _buildShortcutRow('Tab', 'Navigate forward'),
          _buildShortcutRow('Shift + Tab', 'Navigate backward'),
          _buildShortcutRow('Enter/Space', 'Activate button'),
          _buildShortcutRow('Escape', 'Close dialog'),
        ],
      ),
    );
  }

  Widget _buildShortcutRow(String shortcut, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _settings.isHighContrastEnabled ? Colors.black : Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _settings.isHighContrastEnabled ? Colors.white : Colors.grey[300]!,
              ),
            ),
            child: AccessibilityService.instance.createAccessibleText(
              shortcut,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: _settings.isHighContrastEnabled ? Colors.white : Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AccessibilityService.instance.createAccessibleText(
              description,
              style: TextStyle(
                fontSize: 12,
                color: _settings.isHighContrastEnabled ? Colors.white70 : Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReducedMotionSection() {
    return _buildSettingCard(
      icon: Icons.motion_photos_off,
      title: 'Reduced Motion',
      description: 'Minimize animations and transitions',
      child: Switch(
        value: _settings.isReducedMotionEnabled,
        onChanged: (value) async {
          await AccessibilityService.instance.enableReducedMotion(value);
          _loadSettings();
          HapticFeedback.lightImpact();
        },
        activeThumbColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildColorSchemeSection() {
    return _buildSettingCard(
      icon: Icons.palette,
      title: 'Color Scheme',
      description: 'Choose a color scheme that works best for you',
      child: Column(
        children: AccessibilityColorScheme.values.map((scheme) {
          return RadioListTile<AccessibilityColorScheme>(
            title: AccessibilityService.instance.createAccessibleText(
              _getColorSchemeName(scheme),
            ),
            subtitle: AccessibilityService.instance.createAccessibleText(
              _getColorSchemeDescription(scheme),
              style: TextStyle(
                fontSize: 12,
                color: _settings.isHighContrastEnabled ? Colors.white70 : Colors.grey[600],
              ),
            ),
            value: scheme,
            groupValue: _settings.colorScheme,
            onChanged: (value) async {
              if (value != null) {
                await AccessibilityService.instance.setColorScheme(value);
                _loadSettings();
                HapticFeedback.selectionClick();
              }
            },
            activeColor: AppTheme.primaryColor,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      children: [
        _buildQuickActionButton(
          icon: Icons.refresh,
          label: 'Reset to Defaults',
          description: 'Reset all accessibility settings to default values',
          onPressed: _resetToDefaults,
        ),
        const SizedBox(height: 12),
        _buildQuickActionButton(
          icon: Icons.help_outline,
          label: 'Accessibility Guide',
          description: 'Learn more about accessibility features',
          onPressed: _showAccessibilityGuide,
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required String description,
    required VoidCallback onPressed,
  }) {
    return AccessibilityService.instance.createAccessibleWidget(
      semanticLabel: label,
      semanticHint: description,
      isButton: true,
      onTap: onPressed,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _settings.isHighContrastEnabled ? Colors.grey[800] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _settings.isHighContrastEnabled ? Colors.white : Colors.grey[300]!,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: _settings.isHighContrastEnabled ? Colors.white : AppTheme.primaryColor,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AccessibilityService.instance.createAccessibleText(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AccessibilityService.instance.createAccessibleText(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: _settings.isHighContrastEnabled ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: _settings.isHighContrastEnabled ? Colors.white54 : Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required String description,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _settings.isHighContrastEnabled ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: _settings.isHighContrastEnabled 
            ? Border.all(color: Colors.white, width: 1)
            : null,
        boxShadow: _settings.isHighContrastEnabled ? null : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: _settings.isHighContrastEnabled ? Colors.white : AppTheme.primaryColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AccessibilityService.instance.createAccessibleText(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AccessibilityService.instance.createAccessibleText(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: _settings.isHighContrastEnabled ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  String _getColorSchemeName(AccessibilityColorScheme scheme) {
    switch (scheme) {
      case AccessibilityColorScheme.standard:
        return 'Standard';
      case AccessibilityColorScheme.highContrast:
        return 'High Contrast';
      case AccessibilityColorScheme.darkMode:
        return 'Dark Mode';
      case AccessibilityColorScheme.protanopia:
        return 'Protanopia Friendly';
      case AccessibilityColorScheme.deuteranopia:
        return 'Deuteranopia Friendly';
      case AccessibilityColorScheme.tritanopia:
        return 'Tritanopia Friendly';
    }
  }

  String _getColorSchemeDescription(AccessibilityColorScheme scheme) {
    switch (scheme) {
      case AccessibilityColorScheme.standard:
        return 'Default color scheme';
      case AccessibilityColorScheme.highContrast:
        return 'High contrast colors for better visibility';
      case AccessibilityColorScheme.darkMode:
        return 'Dark background with light text';
      case AccessibilityColorScheme.protanopia:
        return 'Optimized for red-green color blindness';
      case AccessibilityColorScheme.deuteranopia:
        return 'Optimized for green color blindness';
      case AccessibilityColorScheme.tritanopia:
        return 'Optimized for blue-yellow color blindness';
    }
  }

  void _resetToDefaults() async {
    await AccessibilityService.instance.enableScreenReader(false);
    await AccessibilityService.instance.enableHighContrast(false);
    await AccessibilityService.instance.enableLargeText(false);
    await AccessibilityService.instance.enableReducedMotion(false);
    await AccessibilityService.instance.enableKeyboardNavigation(false);
    await AccessibilityService.instance.setTextScaleFactor(1.0);
    await AccessibilityService.instance.setColorScheme(AccessibilityColorScheme.standard);
    
    _loadSettings();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Accessibility settings reset to defaults'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showAccessibilityGuide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accessibility Guide'),
        content: const SingleChildScrollView(
          child: Text(
            'TALOWA is designed to be accessible to everyone. Here are some tips:\n\n'
            '• Enable Screen Reader for voice announcements\n'
            '• Use High Contrast mode for better visibility\n'
            '• Adjust text size for comfortable reading\n'
            '• Enable keyboard navigation for hands-free use\n'
            '• Choose color schemes that work best for you\n\n'
            'For more help, contact our support team.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}



