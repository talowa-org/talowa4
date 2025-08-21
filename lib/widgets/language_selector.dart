import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/localization_provider.dart';
import '../generated/l10n/app_localizations.dart';

class LanguageSelector extends StatelessWidget {
  final bool showTitle;
  final EdgeInsetsGeometry? padding;
  final Function(Locale)? onLanguageChanged;

  const LanguageSelector({
    super.key,
    this.showTitle = true,
    this.padding,
    this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalizationProvider>(
      builder: (context, localizationProvider, child) {
        final currentLocale = localizationProvider.currentLocale;
        final supportedLocales = localizationProvider.supportedLocales;
        final isLoading = localizationProvider.isLoading;

        return Container(
          padding: padding ?? const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showTitle) ...[
                Text(
                  AppLocalizations.of(context).selectLanguage ?? 'Select Language',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
              ],
              
              if (isLoading)
                const Center(
                  child: CircularProgressIndicator(),
                )
              else
                Column(
                  children: supportedLocales.map((locale) {
                    final isSelected = locale == currentLocale;
                    final displayName = localizationProvider.getLanguageDisplayName(locale);
                    
                    return Card(
                      elevation: isSelected ? 4 : 1,
                      color: isSelected 
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSelected 
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outline,
                          child: Text(
                            _getLanguageFlag(locale),
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                        title: Text(
                          displayName,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected 
                                ? Theme.of(context).colorScheme.onPrimaryContainer
                                : null,
                          ),
                        ),
                        subtitle: Text(
                          _getLanguageSubtitle(locale),
                          style: TextStyle(
                            color: isSelected 
                                ? Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7)
                                : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        trailing: isSelected 
                            ? Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                        onTap: isSelected ? null : () async {
                          await localizationProvider.changeLanguage(locale);
                          onLanguageChanged?.call(locale);
                        },
                      ),
                    );
                  }).toList(),
                ),
              
              const SizedBox(height: 16),
              
              // Reset to device language button
              TextButton.icon(
                onPressed: isLoading ? null : () async {
                  await localizationProvider.resetToDeviceLanguage();
                },
                icon: const Icon(Icons.phone_android),
                label: Text(
                  AppLocalizations.of(context).resetToDeviceLanguage ?? 'Use Device Language',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getLanguageFlag(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return '🇺🇸';
      case 'hi':
        return '🇮🇳';
      case 'te':
        return '🇮🇳';
      case 'ta':
        return '🇮🇳';
      default:
        return '🌐';
    }
  }

  String _getLanguageSubtitle(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return 'English (US)';
      case 'hi':
        return 'हिन्दी (भारत)';
      case 'te':
        return 'తెలుగు (భారతదేశం)';
      case 'ta':
        return 'தமிழ் (இந்தியா)';
      default:
        return locale.toString();
    }
  }
}

class LanguageSelectorDialog extends StatelessWidget {
  const LanguageSelectorDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        AppLocalizations.of(context).selectLanguage ?? 'Select Language',
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: LanguageSelector(
          showTitle: false,
          padding: EdgeInsets.zero,
          onLanguageChanged: (locale) {
            Navigator.of(context).pop();
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            AppLocalizations.of(context).close ?? 'Close',
          ),
        ),
      ],
    );
  }

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => const LanguageSelectorDialog(),
    );
  }
}

class LanguageSelectorBottomSheet extends StatelessWidget {
  const LanguageSelectorBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          LanguageSelector(
            onLanguageChanged: (locale) {
              Navigator.of(context).pop();
            },
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => const LanguageSelectorBottomSheet(),
    );
  }
}