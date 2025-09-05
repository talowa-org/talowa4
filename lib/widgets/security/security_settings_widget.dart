// Security Settings Widget for TALOWA
// Allows administrators to configure security policies and thresholds

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/security/enterprise_security_service.dart';

class SecuritySettingsWidget extends StatefulWidget {
  final bool isAdminMode;
  
  const SecuritySettingsWidget({
    Key? key,
    this.isAdminMode = false,
  }) : super(key: key);
  
  @override
  State<SecuritySettingsWidget> createState() => _SecuritySettingsWidgetState();
}

class _SecuritySettingsWidgetState extends State<SecuritySettingsWidget>
    with TickerProviderStateMixin {
  final EnterpriseSecurityService _securityService = EnterpriseSecurityService();
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _sessionTimeoutController = TextEditingController();
  final _maxLoginAttemptsController = TextEditingController();
  final _passwordMinLengthController = TextEditingController();
  final _auditRetentionDaysController = TextEditingController();
  final _threatDetectionThresholdController = TextEditingController();
  
  // State
  bool _isLoading = true;
  bool _isSaving = false;
  SecurityConfiguration? _currentConfig;
  SecurityConfiguration? _editedConfig;
  
  // Settings categories
  int _selectedCategoryIndex = 0;
  final List<String> _categories = [
    'Authentication',
    'Session Management',
    'Audit & Logging',
    'Threat Detection',
    'Compliance',
    'Data Protection',
  ];
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadSecurityConfiguration();
  }
  
  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeController.forward();
    _slideController.forward();
  }
  
  Future<void> _loadSecurityConfiguration() async {
    try {
      // In a real implementation, this would load from the security service
      await Future.delayed(const Duration(seconds: 1));
      
      final config = SecurityConfiguration(
        sessionTimeoutMinutes: 30,
        maxLoginAttempts: 5,
        passwordMinLength: 8,
        requireSpecialCharacters: true,
        requireNumbers: true,
        requireUppercase: true,
        auditRetentionDays: 90,
        enableThreatDetection: true,
        threatDetectionThreshold: 0.7,
        enableDeviceFingerprinting: true,
        enableGeoBlocking: false,
        allowedCountries: ['US', 'CA', 'GB'],
        enableDataEncryption: true,
        encryptionAlgorithm: 'AES-256',
        enableComplianceReporting: true,
        complianceStandards: ['SOC2', 'GDPR'],
      );
      
      if (mounted) {
        setState(() {
          _currentConfig = config;
          _editedConfig = config.copyWith();
          _isLoading = false;
          _populateControllers();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Failed to load security configuration: $e');
      }
    }
  }
  
  void _populateControllers() {
    if (_editedConfig != null) {
      _sessionTimeoutController.text = _editedConfig!.sessionTimeoutMinutes.toString();
      _maxLoginAttemptsController.text = _editedConfig!.maxLoginAttempts.toString();
      _passwordMinLengthController.text = _editedConfig!.passwordMinLength.toString();
      _auditRetentionDaysController.text = _editedConfig!.auditRetentionDays.toString();
      _threatDetectionThresholdController.text = _editedConfig!.threatDetectionThreshold.toString();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              if (_isLoading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_editedConfig != null) ...[
                _buildCategoryTabs(),
                const SizedBox(height: 20),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: _buildSettingsContent(),
                  ),
                ),
                const SizedBox(height: 20),
                _buildActionButtons(),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.security,
            color: Colors.red,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Security Settings',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.isAdminMode
                    ? 'Configure enterprise security policies'
                    : 'View security configuration (Read-only)',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        if (widget.isAdminMode && _hasUnsavedChanges())
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.edit,
                  size: 16,
                  color: Colors.orange[700],
                ),
                const SizedBox(width: 4),
                Text(
                  'Unsaved',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange[700],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
  
  Widget _buildCategoryTabs() {
    return Container(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final isSelected = index == _selectedCategoryIndex;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategoryIndex = index;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.grey.withOpacity(0.3),
                ),
              ),
              child: Center(
                child: Text(
                  _categories[index],
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[700],
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildSettingsContent() {
    switch (_selectedCategoryIndex) {
      case 0:
        return _buildAuthenticationSettings();
      case 1:
        return _buildSessionSettings();
      case 2:
        return _buildAuditSettings();
      case 3:
        return _buildThreatDetectionSettings();
      case 4:
        return _buildComplianceSettings();
      case 5:
        return _buildDataProtectionSettings();
      default:
        return const SizedBox();
    }
  }
  
  Widget _buildAuthenticationSettings() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Password Policy'),
          const SizedBox(height: 16),
          
          _buildNumberField(
            'Minimum Password Length',
            _passwordMinLengthController,
            'characters',
            (value) {
              _editedConfig = _editedConfig!.copyWith(
                passwordMinLength: int.tryParse(value) ?? 8,
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          _buildSwitchTile(
            'Require Special Characters',
            'Password must contain special characters (!@#\$%^&*)',
            _editedConfig!.requireSpecialCharacters,
            (value) {
              setState(() {
                _editedConfig = _editedConfig!.copyWith(
                  requireSpecialCharacters: value,
                );
              });
            },
          ),
          
          _buildSwitchTile(
            'Require Numbers',
            'Password must contain at least one number',
            _editedConfig!.requireNumbers,
            (value) {
              setState(() {
                _editedConfig = _editedConfig!.copyWith(
                  requireNumbers: value,
                );
              });
            },
          ),
          
          _buildSwitchTile(
            'Require Uppercase Letters',
            'Password must contain at least one uppercase letter',
            _editedConfig!.requireUppercase,
            (value) {
              setState(() {
                _editedConfig = _editedConfig!.copyWith(
                  requireUppercase: value,
                );
              });
            },
          ),
          
          const SizedBox(height: 24),
          _buildSectionTitle('Login Security'),
          const SizedBox(height: 16),
          
          _buildNumberField(
            'Maximum Login Attempts',
            _maxLoginAttemptsController,
            'attempts before lockout',
            (value) {
              _editedConfig = _editedConfig!.copyWith(
                maxLoginAttempts: int.tryParse(value) ?? 5,
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildSessionSettings() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Session Management'),
          const SizedBox(height: 16),
          
          _buildNumberField(
            'Session Timeout',
            _sessionTimeoutController,
            'minutes of inactivity',
            (value) {
              _editedConfig = _editedConfig!.copyWith(
                sessionTimeoutMinutes: int.tryParse(value) ?? 30,
              );
            },
          ),
          
          const SizedBox(height: 24),
          _buildSectionTitle('Device Security'),
          const SizedBox(height: 16),
          
          _buildSwitchTile(
            'Device Fingerprinting',
            'Track and identify devices for enhanced security',
            _editedConfig!.enableDeviceFingerprinting,
            (value) {
              setState(() {
                _editedConfig = _editedConfig!.copyWith(
                  enableDeviceFingerprinting: value,
                );
              });
            },
          ),
          
          _buildSwitchTile(
            'Geographic Blocking',
            'Restrict access based on geographic location',
            _editedConfig!.enableGeoBlocking,
            (value) {
              setState(() {
                _editedConfig = _editedConfig!.copyWith(
                  enableGeoBlocking: value,
                );
              });
            },
          ),
          
          if (_editedConfig!.enableGeoBlocking) ...[
            const SizedBox(height: 16),
            _buildCountrySelector(),
          ],
        ],
      ),
    );
  }
  
  Widget _buildAuditSettings() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Audit Configuration'),
          const SizedBox(height: 16),
          
          _buildNumberField(
            'Audit Log Retention',
            _auditRetentionDaysController,
            'days to keep audit logs',
            (value) {
              _editedConfig = _editedConfig!.copyWith(
                auditRetentionDays: int.tryParse(value) ?? 90,
              );
            },
          ),
          
          const SizedBox(height: 24),
          _buildSectionTitle('Logging Levels'),
          const SizedBox(height: 16),
          
          _buildInfoCard(
            'Current audit events being logged:',
            [
              'User authentication events',
              'Data access and modifications',
              'System configuration changes',
              'Security threats and violations',
              'Compliance report generation',
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildThreatDetectionSettings() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Threat Detection'),
          const SizedBox(height: 16),
          
          _buildSwitchTile(
            'Enable Threat Detection',
            'Automatically detect and respond to security threats',
            _editedConfig!.enableThreatDetection,
            (value) {
              setState(() {
                _editedConfig = _editedConfig!.copyWith(
                  enableThreatDetection: value,
                );
              });
            },
          ),
          
          if (_editedConfig!.enableThreatDetection) ...[
            const SizedBox(height: 16),
            _buildSliderField(
              'Detection Sensitivity',
              'Higher values detect more potential threats',
              _editedConfig!.threatDetectionThreshold,
              0.1,
              1.0,
              (value) {
                setState(() {
                  _editedConfig = _editedConfig!.copyWith(
                    threatDetectionThreshold: value,
                  );
                  _threatDetectionThresholdController.text = value.toStringAsFixed(2);
                });
              },
            ),
          ],
          
          const SizedBox(height: 24),
          _buildSectionTitle('Threat Types'),
          const SizedBox(height: 16),
          
          _buildInfoCard(
            'Currently monitoring for:',
            [
              'Brute force attacks',
              'Suspicious login patterns',
              'Unusual data access',
              'Geographic anomalies',
              'Device fingerprint violations',
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildComplianceSettings() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Compliance Reporting'),
          const SizedBox(height: 16),
          
          _buildSwitchTile(
            'Enable Compliance Reporting',
            'Generate automated compliance reports',
            _editedConfig!.enableComplianceReporting,
            (value) {
              setState(() {
                _editedConfig = _editedConfig!.copyWith(
                  enableComplianceReporting: value,
                );
              });
            },
          ),
          
          const SizedBox(height: 24),
          _buildSectionTitle('Compliance Standards'),
          const SizedBox(height: 16),
          
          _buildComplianceStandardsSelector(),
          
          const SizedBox(height: 24),
          _buildSectionTitle('Report Schedule'),
          const SizedBox(height: 16),
          
          _buildInfoCard(
            'Automated reports are generated:',
            [
              'Daily security summaries',
              'Weekly compliance reports',
              'Monthly audit summaries',
              'Quarterly risk assessments',
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildDataProtectionSettings() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Data Encryption'),
          const SizedBox(height: 16),
          
          _buildSwitchTile(
            'Enable Data Encryption',
            'Encrypt sensitive data at rest and in transit',
            _editedConfig!.enableDataEncryption,
            (value) {
              setState(() {
                _editedConfig = _editedConfig!.copyWith(
                  enableDataEncryption: value,
                );
              });
            },
          ),
          
          if (_editedConfig!.enableDataEncryption) ...[
            const SizedBox(height: 16),
            _buildDropdownField(
              'Encryption Algorithm',
              _editedConfig!.encryptionAlgorithm,
              ['AES-256', 'AES-128', 'ChaCha20'],
              (value) {
                setState(() {
                  _editedConfig = _editedConfig!.copyWith(
                    encryptionAlgorithm: value,
                  );
                });
              },
            ),
          ],
          
          const SizedBox(height: 24),
          _buildSectionTitle('Data Protection Features'),
          const SizedBox(height: 16),
          
          _buildInfoCard(
            'Active protection measures:',
            [
              'End-to-end encryption for messages',
              'Encrypted database storage',
              'Secure file uploads',
              'Protected API communications',
              'Anonymized analytics data',
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).primaryColor,
      ),
    );
  }
  
  Widget _buildNumberField(
    String label,
    TextEditingController controller,
    String suffix,
    Function(String) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: widget.isAdminMode,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            suffixText: suffix,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'This field is required';
            }
            final intValue = int.tryParse(value);
            if (intValue == null || intValue <= 0) {
              return 'Please enter a valid positive number';
            }
            return null;
          },
          onChanged: onChanged,
        ),
      ],
    );
  }
  
  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: widget.isAdminMode ? onChanged : null,
          ),
        ],
      ),
    );
  }
  
  Widget _buildSliderField(
    String label,
    String description,
    double value,
    double min,
    double max,
    Function(double) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.withOpacity(0.2),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Low ($min)'),
                  Text(
                    value.toStringAsFixed(2),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text('High ($max)'),
                ],
              ),
              Slider(
                value: value,
                min: min,
                max: max,
                divisions: 20,
                onChanged: widget.isAdminMode ? onChanged : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildDropdownField(
    String label,
    String value,
    List<String> options,
    Function(String) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: options.map((option) => DropdownMenuItem<String>(
                value: option,
                child: Text(option),
              )).toList(),
              onChanged: widget.isAdminMode ? (newValue) {
                if (newValue != null) {
                  onChanged(newValue);
                }
              } : null,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildCountrySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Allowed Countries',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _editedConfig!.allowedCountries.map((country) {
              return Chip(
                label: Text(country),
                deleteIcon: widget.isAdminMode ? const Icon(Icons.close, size: 16) : null,
                onDeleted: widget.isAdminMode ? () {
                  setState(() {
                    final updatedCountries = List<String>.from(_editedConfig!.allowedCountries);
                    updatedCountries.remove(country);
                    _editedConfig = _editedConfig!.copyWith(
                      allowedCountries: updatedCountries,
                    );
                  });
                } : null,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
  
  Widget _buildComplianceStandardsSelector() {
    final availableStandards = ['SOC2', 'GDPR', 'HIPAA', 'PCI-DSS', 'ISO27001'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Active Compliance Standards',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: availableStandards.map((standard) {
              final isSelected = _editedConfig!.complianceStandards.contains(standard);
              return CheckboxListTile(
                title: Text(standard),
                value: isSelected,
                enabled: widget.isAdminMode,
                onChanged: widget.isAdminMode ? (value) {
                  setState(() {
                    final updatedStandards = List<String>.from(_editedConfig!.complianceStandards);
                    if (value == true) {
                      updatedStandards.add(standard);
                    } else {
                      updatedStandards.remove(standard);
                    }
                    _editedConfig = _editedConfig!.copyWith(
                      complianceStandards: updatedStandards,
                    );
                  });
                } : null,
                dense: true,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
  
  Widget _buildInfoCard(String title, List<String> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.blue[700],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 16,
                  color: Colors.green[600],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
  
  Widget _buildActionButtons() {
    return Row(
      children: [
        if (widget.isAdminMode && _hasUnsavedChanges()) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: _isSaving ? null : _resetChanges,
              child: const Text('Reset'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveConfiguration,
              child: _isSaving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Configuration'),
            ),
          ),
        ] else ...[
          Expanded(
            child: ElevatedButton(
              onPressed: () => _loadSecurityConfiguration(),
              child: const Text('Refresh'),
            ),
          ),
        ],
      ],
    );
  }
  
  bool _hasUnsavedChanges() {
    return _currentConfig != null && _editedConfig != null && _currentConfig != _editedConfig;
  }
  
  void _resetChanges() {
    setState(() {
      _editedConfig = _currentConfig?.copyWith();
      _populateControllers();
    });
  }
  
  Future<void> _saveConfiguration() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      // In a real implementation, this would save to the security service
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        setState(() {
          _currentConfig = _editedConfig?.copyWith();
          _isSaving = false;
        });
        
        _showSuccessSnackBar('Security configuration saved successfully');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        _showErrorSnackBar('Failed to save configuration: $e');
      }
    }
  }
  
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  void _showErrorSnackBar(String message) {
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
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _sessionTimeoutController.dispose();
    _maxLoginAttemptsController.dispose();
    _passwordMinLengthController.dispose();
    _auditRetentionDaysController.dispose();
    _threatDetectionThresholdController.dispose();
    super.dispose();
  }
}

// Security Configuration Model
class SecurityConfiguration {
  final int sessionTimeoutMinutes;
  final int maxLoginAttempts;
  final int passwordMinLength;
  final bool requireSpecialCharacters;
  final bool requireNumbers;
  final bool requireUppercase;
  final int auditRetentionDays;
  final bool enableThreatDetection;
  final double threatDetectionThreshold;
  final bool enableDeviceFingerprinting;
  final bool enableGeoBlocking;
  final List<String> allowedCountries;
  final bool enableDataEncryption;
  final String encryptionAlgorithm;
  final bool enableComplianceReporting;
  final List<String> complianceStandards;
  
  const SecurityConfiguration({
    required this.sessionTimeoutMinutes,
    required this.maxLoginAttempts,
    required this.passwordMinLength,
    required this.requireSpecialCharacters,
    required this.requireNumbers,
    required this.requireUppercase,
    required this.auditRetentionDays,
    required this.enableThreatDetection,
    required this.threatDetectionThreshold,
    required this.enableDeviceFingerprinting,
    required this.enableGeoBlocking,
    required this.allowedCountries,
    required this.enableDataEncryption,
    required this.encryptionAlgorithm,
    required this.enableComplianceReporting,
    required this.complianceStandards,
  });
  
  SecurityConfiguration copyWith({
    int? sessionTimeoutMinutes,
    int? maxLoginAttempts,
    int? passwordMinLength,
    bool? requireSpecialCharacters,
    bool? requireNumbers,
    bool? requireUppercase,
    int? auditRetentionDays,
    bool? enableThreatDetection,
    double? threatDetectionThreshold,
    bool? enableDeviceFingerprinting,
    bool? enableGeoBlocking,
    List<String>? allowedCountries,
    bool? enableDataEncryption,
    String? encryptionAlgorithm,
    bool? enableComplianceReporting,
    List<String>? complianceStandards,
  }) {
    return SecurityConfiguration(
      sessionTimeoutMinutes: sessionTimeoutMinutes ?? this.sessionTimeoutMinutes,
      maxLoginAttempts: maxLoginAttempts ?? this.maxLoginAttempts,
      passwordMinLength: passwordMinLength ?? this.passwordMinLength,
      requireSpecialCharacters: requireSpecialCharacters ?? this.requireSpecialCharacters,
      requireNumbers: requireNumbers ?? this.requireNumbers,
      requireUppercase: requireUppercase ?? this.requireUppercase,
      auditRetentionDays: auditRetentionDays ?? this.auditRetentionDays,
      enableThreatDetection: enableThreatDetection ?? this.enableThreatDetection,
      threatDetectionThreshold: threatDetectionThreshold ?? this.threatDetectionThreshold,
      enableDeviceFingerprinting: enableDeviceFingerprinting ?? this.enableDeviceFingerprinting,
      enableGeoBlocking: enableGeoBlocking ?? this.enableGeoBlocking,
      allowedCountries: allowedCountries ?? this.allowedCountries,
      enableDataEncryption: enableDataEncryption ?? this.enableDataEncryption,
      encryptionAlgorithm: encryptionAlgorithm ?? this.encryptionAlgorithm,
      enableComplianceReporting: enableComplianceReporting ?? this.enableComplianceReporting,
      complianceStandards: complianceStandards ?? this.complianceStandards,
    );
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SecurityConfiguration &&
        other.sessionTimeoutMinutes == sessionTimeoutMinutes &&
        other.maxLoginAttempts == maxLoginAttempts &&
        other.passwordMinLength == passwordMinLength &&
        other.requireSpecialCharacters == requireSpecialCharacters &&
        other.requireNumbers == requireNumbers &&
        other.requireUppercase == requireUppercase &&
        other.auditRetentionDays == auditRetentionDays &&
        other.enableThreatDetection == enableThreatDetection &&
        other.threatDetectionThreshold == threatDetectionThreshold &&
        other.enableDeviceFingerprinting == enableDeviceFingerprinting &&
        other.enableGeoBlocking == enableGeoBlocking &&
        other.allowedCountries.toString() == allowedCountries.toString() &&
        other.enableDataEncryption == enableDataEncryption &&
        other.encryptionAlgorithm == encryptionAlgorithm &&
        other.enableComplianceReporting == enableComplianceReporting &&
        other.complianceStandards.toString() == complianceStandards.toString();
  }
  
  @override
  int get hashCode {
    return Object.hash(
      sessionTimeoutMinutes,
      maxLoginAttempts,
      passwordMinLength,
      requireSpecialCharacters,
      requireNumbers,
      requireUppercase,
      auditRetentionDays,
      enableThreatDetection,
      threatDetectionThreshold,
      enableDeviceFingerprinting,
      enableGeoBlocking,
      allowedCountries,
      enableDataEncryption,
      encryptionAlgorithm,
      enableComplianceReporting,
      complianceStandards,
    );
  }
}
