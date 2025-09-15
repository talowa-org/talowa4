import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_te.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('te')
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'TALOWA'**
  String get appTitle;

  /// The subtitle of the application
  ///
  /// In en, this message translates to:
  /// **'Land Rights Movement'**
  String get appSubtitle;

  /// Welcome message on the welcome screen
  ///
  /// In en, this message translates to:
  /// **'Welcome to TALOWA'**
  String get welcome;

  /// Welcome message description
  ///
  /// In en, this message translates to:
  /// **'Join the movement for land rights and social justice'**
  String get welcomeMessage;

  /// Login button text
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// Register button text
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// Phone number field label
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// Phone number field placeholder
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get enterPhoneNumber;

  /// PIN field label
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get pin;

  /// PIN field placeholder
  ///
  /// In en, this message translates to:
  /// **'Enter your 4-digit PIN'**
  String get enterPin;

  /// Full name field label
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// Full name field placeholder
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get enterFullName;

  /// Address section label
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// State field label
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get state;

  /// District field label
  ///
  /// In en, this message translates to:
  /// **'District'**
  String get district;

  /// Mandal field label
  ///
  /// In en, this message translates to:
  /// **'Mandal/Tehsil'**
  String get mandal;

  /// Village field label
  ///
  /// In en, this message translates to:
  /// **'Village/City'**
  String get village;

  /// Referral code field label
  ///
  /// In en, this message translates to:
  /// **'Referral Code'**
  String get referralCode;

  /// Referral code field placeholder
  ///
  /// In en, this message translates to:
  /// **'Enter referral code (optional)'**
  String get enterReferralCode;

  /// Home tab label
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Feed tab label
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get feed;

  /// Messages tab label
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// Network tab label
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get network;

  /// More tab label
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// Profile screen title
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Language setting label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Language selection screen title
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// English language option
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// Hindi language option
  ///
  /// In en, this message translates to:
  /// **'हिन्दी'**
  String get hindi;

  /// Telugu language option
  ///
  /// In en, this message translates to:
  /// **'తెలుగు'**
  String get telugu;

  /// Save button text
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Cancel button text
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// OK button text
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Yes button text
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No button text
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// Loading indicator text
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Error message title
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// Success message title
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// Warning message title
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warning;

  /// Information message title
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get info;

  /// Retry button text
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Close button text
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Back button text
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Next button text
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// Previous button text
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// Done button text
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// Skip button text
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// Continue button text
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continue_;

  /// Submit button text
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// Search field placeholder
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No search results message
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResults;

  /// Network error message
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection.'**
  String get networkError;

  /// Server error message
  ///
  /// In en, this message translates to:
  /// **'Server error. Please try again later.'**
  String get serverError;

  /// Invalid input error message
  ///
  /// In en, this message translates to:
  /// **'Invalid input. Please check your data.'**
  String get invalidInput;

  /// Required field validation message
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get requiredField;

  /// Invalid phone number validation message
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid phone number'**
  String get invalidPhoneNumber;

  /// Invalid PIN validation message
  ///
  /// In en, this message translates to:
  /// **'PIN must be 4 digits'**
  String get invalidPin;

  /// Logout button text
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// Logout confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get logoutConfirmation;

  /// Referral code section title
  ///
  /// In en, this message translates to:
  /// **'Referral Code'**
  String get myReferralCode;

  /// Share referral code button text
  ///
  /// In en, this message translates to:
  /// **'Share Referral Code'**
  String get shareReferralCode;

  /// Copy referral code button text
  ///
  /// In en, this message translates to:
  /// **'Copy Referral Code'**
  String get copyReferralCode;

  /// Referral code copied success message
  ///
  /// In en, this message translates to:
  /// **'Referral code copied to clipboard'**
  String get referralCodeCopied;

  /// Direct referrals count label
  ///
  /// In en, this message translates to:
  /// **'Direct Referrals'**
  String get directReferrals;

  /// Total team size count label
  ///
  /// In en, this message translates to:
  /// **'Total Team Size'**
  String get totalTeamSize;

  /// User role label
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get role;

  /// Member role
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get member;

  /// Coordinator role
  ///
  /// In en, this message translates to:
  /// **'Coordinator'**
  String get coordinator;

  /// AI Assistant feature title
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get aiAssistant;

  /// Ask AI Assistant button text
  ///
  /// In en, this message translates to:
  /// **'Ask AI Assistant'**
  String get askAIAssistant;

  /// AI Assistant input placeholder
  ///
  /// In en, this message translates to:
  /// **'Type your question...'**
  String get typeYourQuestion;

  /// Emergency actions section title
  ///
  /// In en, this message translates to:
  /// **'Emergency Actions'**
  String get emergencyActions;

  /// Report land grabbing button text
  ///
  /// In en, this message translates to:
  /// **'Report Land Grabbing'**
  String get reportLandGrabbing;

  /// Call for help button text
  ///
  /// In en, this message translates to:
  /// **'Call for Help'**
  String get callForHelp;

  /// Land records section title
  ///
  /// In en, this message translates to:
  /// **'Land Records'**
  String get landRecords;

  /// Legal cases section title
  ///
  /// In en, this message translates to:
  /// **'Legal Cases'**
  String get legalCases;

  /// Campaigns section title
  ///
  /// In en, this message translates to:
  /// **'Campaigns'**
  String get campaigns;

  /// Notifications screen title
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No notifications message
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get noNotifications;

  /// Mark all notifications as read button text
  ///
  /// In en, this message translates to:
  /// **'Mark All as Read'**
  String get markAllAsRead;

  /// About screen title
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// App version label
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// Privacy policy link text
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// Terms of service link text
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// Contact support link text
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get contactSupport;

  /// Help center link text
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get helpCenter;

  /// Feedback link text
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedback;

  /// Rate app link text
  ///
  /// In en, this message translates to:
  /// **'Rate App'**
  String get rateApp;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi', 'te'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'te':
      return AppLocalizationsTe();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
