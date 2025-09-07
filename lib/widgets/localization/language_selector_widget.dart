// Language Selector Widget - Multi-language selection interface
// Complete language selection for TALOWA platform

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../services/localization/localization_service.dart';

class LanguageSelectorWidget extends StatefulWidget {
  final Function(String)? onLanguageChanged;
  final bool showAsBottomSheet;
  final bool showCurrentLanguageFirst;

  const LanguageSelectorWidget({
    super.key,
    this.onLanguageChanged,
    this.showAsBottomSheet = false,
    this.showCurrentLanguageFirst = true,
  });

  @override
  State<LanguageSelectorWidget> createState() => _LanguageSelectorWidgetState();
}

class _LanguageSelectorWidgetState extends State<LanguageSelectorWidget>
    with TickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  String _currentLanguage = 'en';
  Map<String, String> _availableLanguages = {};
  bool _isChangingLanguage = false;
  
  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _loadLanguageData();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _loadLanguageData() {
    setState(() {
      _currentLanguage = LocalizationService.instance.currentLanguage;
      _availableLanguages = LocalizationService.instance.getAvailableLanguages();
    });
  }

  Future<void> _changeLanguage(String languageCode) async {
    if (_currentLanguage == languageCode || _isChangingLanguage) return;

    setState(() => _isChangingLanguage = true);
    
    // Add haptic feedback
    HapticFeedback.selectionClick();

    try {
      await LocalizationService.instance.changeLanguage(languageCode);
      
      setState(() {
        _currentLanguage = languageCode;
        _isChangingLanguage = false;
      });

      // Notify parent widget
      if (widget.onLanguageChanged != null) {
        widget.onLanguageChanged!(languageCode);
      }

      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Language changed to ${_availableLanguages[languageCode]}',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: AppTheme.primaryColor,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }

    } catch (e) {
      setState(() => _isChangingLanguage = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to change language: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showAsBottomSheet) {
      return _buildBottomSheet();
    }
    
    return _buildLanguageList();
  }

  Widget _buildBottomSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBottomSheetHeader(),
          Flexible(child: _buildLanguageList()),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildBottomSheetHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.2),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.language,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Language',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'Choose your preferred language',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageList() {
    final sortedLanguages = _getSortedLanguages();
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ListView.builder(
          shrinkWrap: true,
          physics: widget.showAsBottomSheet 
              ? const BouncingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: sortedLanguages.length,
          itemBuilder: (context, index) {
            final entry = sortedLanguages[index];
            final languageCode = entry.key;
            final languageName = entry.value;
            
            return _buildLanguageItem(languageCode, languageName, index);
          },
        ),
      ),
    );
  }

  List<MapEntry<String, String>> _getSortedLanguages() {
    final languages = _availableLanguages.entries.toList();
    
    if (widget.showCurrentLanguageFirst) {
      // Move current language to top
      languages.sort((a, b) {
        if (a.key == _currentLanguage) return -1;
        if (b.key == _currentLanguage) return 1;
        return a.value.compareTo(b.value);
      });
    } else {
      // Sort alphabetically by display name
      languages.sort((a, b) => a.value.compareTo(b.value));
    }
    
    return languages;
  }

  Widget _buildLanguageItem(String languageCode, String languageName, int index) {
    final isSelected = languageCode == _currentLanguage;
    final isChanging = _isChangingLanguage && languageCode == _currentLanguage;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected 
            ? AppTheme.primaryColor.withValues(alpha: 0.2)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected 
              ? AppTheme.primaryColor.withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.2),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: isChanging ? null : () => _changeLanguage(languageCode),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildLanguageIcon(languageCode),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      languageName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? AppTheme.primaryColor : Colors.black87,
                      ),
                    ),
                    Text(
                      _getLanguageNativeName(languageCode),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (isChanging)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  ),
                )
              else if (isSelected)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                )
              else
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageIcon(String languageCode) {
    // Language-specific icons or flags
    final languageIcons = {
      'en': 'ðŸ‡ºðŸ‡¸',
      'hi': 'ðŸ‡®ðŸ‡³',
      'bn': 'ðŸ‡§ðŸ‡©',
      'te': 'ðŸ‡®ðŸ‡³',
      'ta': 'ðŸ‡®ðŸ‡³',
      'mr': 'ðŸ‡®ðŸ‡³',
      'gu': 'ðŸ‡®ðŸ‡³',
      'kn': 'ðŸ‡®ðŸ‡³',
      'ml': 'ðŸ‡®ðŸ‡³',
      'pa': 'ðŸ‡®ðŸ‡³',
      'or': 'ðŸ‡®ðŸ‡³',
      'as': 'ðŸ‡®ðŸ‡³',
    };

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Text(
          languageIcons[languageCode] ?? 'ðŸŒ',
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }

  String _getLanguageNativeName(String languageCode) {
    final nativeNames = {
      'en': 'English',
      'hi': 'à¤¹à¤¿à¤‚à¤¦à¥€',
      'bn': 'à¦¬à¦¾à¦‚à¦²à¦¾',
      'te': 'à°¤à±†à°²à±à°—à±',
      'ta': 'à®¤à®®à®¿à®´à¯',
      'mr': 'à¤®à¤°à¤¾à¤ à¥€',
      'gu': 'àª—à«àªœàª°àª¾àª¤à«€',
      'kn': 'à²•à²¨à³à²¨à²¡',
      'ml': 'à´®à´²à´¯à´¾à´³à´‚',
      'pa': 'à¨ªà©°à¨œà¨¾à¨¬à©€',
      'or': 'à¬“à¬¡à¬¼à¬¿à¬†',
      'as': 'à¦…à¦¸à¦®à§€à¦¯à¦¼à¦¾',
    };

    return nativeNames[languageCode] ?? languageCode.toUpperCase();
  }

  /// Show language selector as bottom sheet
  static Future<String?> showLanguageSelector(BuildContext context) async {
    return await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => LanguageSelectorWidget(
          showAsBottomSheet: true,
          onLanguageChanged: (languageCode) {
            Navigator.of(context).pop(languageCode);
          },
        ),
      ),
    );
  }
}


