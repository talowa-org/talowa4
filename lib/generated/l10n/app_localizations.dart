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
    Locale('te'),
  ];

  /// The name of the application
  ///
  /// In en, this message translates to:
  /// **'TALOWA'**
  String get appName;

  /// Welcome message on login screen
  ///
  /// In en, this message translates to:
  /// **'Welcome Back!'**
  String get welcomeBack;

  /// Subtitle on login screen
  ///
  /// In en, this message translates to:
  /// **'Sign in to your account'**
  String get signInToYourAccount;

  /// Label for mobile number input field
  ///
  /// In en, this message translates to:
  /// **'Mobile Number'**
  String get mobileNumber;

  /// Label for PIN input field
  ///
  /// In en, this message translates to:
  /// **'6-Digit PIN'**
  String get sixDigitPin;

  /// Sign in button text
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// Register button text
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// Text before register link
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get dontHaveAccount;

  /// Success message after login
  ///
  /// In en, this message translates to:
  /// **'Login successful!'**
  String get loginSuccessful;

  /// Error message when login fails
  ///
  /// In en, this message translates to:
  /// **'Login failed. Please try again.'**
  String get loginFailed;

  /// Error message for invalid credentials
  ///
  /// In en, this message translates to:
  /// **'The supplied auth credential is incorrect, malformed or has expired.'**
  String get invalidCredentials;

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

  /// Morning greeting message
  ///
  /// In en, this message translates to:
  /// **'Good morning! How is your day?'**
  String get goodMorning;

  /// Welcome message for new users
  ///
  /// In en, this message translates to:
  /// **'Welcome to TALOWA'**
  String get welcomeToTalowa;

  /// Member badge text
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get member;

  /// Placeholder text for input field
  ///
  /// In en, this message translates to:
  /// **'Ask anything...'**
  String get askAnything;

  /// Land issues button text
  ///
  /// In en, this message translates to:
  /// **'Land Issues'**
  String get landIssues;

  /// My network button text
  ///
  /// In en, this message translates to:
  /// **'My Network'**
  String get myNetwork;

  /// Legal help button text
  ///
  /// In en, this message translates to:
  /// **'Legal Help'**
  String get legalHelp;

  /// Support button text
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// Header for daily inspiration section
  ///
  /// In en, this message translates to:
  /// **'Today\'s Inspiration Message'**
  String get todaysInspirationMessage;

  /// Inspiration message text
  ///
  /// In en, this message translates to:
  /// **'United we stand, let\'s protect our land together.'**
  String get unitedWeStandProtectOurLand;

  /// Victory story title
  ///
  /// In en, this message translates to:
  /// **'Sambuddha\'s Victory'**
  String get sambuddhaVictory;

  /// Victory story description
  ///
  /// In en, this message translates to:
  /// **'After 15 years, Telangana\'s Sambuddha finally got his land back.'**
  String get telanganaSambuddhaLandVictoryStory;

  /// Debug tools section header
  ///
  /// In en, this message translates to:
  /// **'Debug Tools'**
  String get debugTools;

  /// Create test user button
  ///
  /// In en, this message translates to:
  /// **'Create Test User'**
  String get createTestUser;

  /// Check user button
  ///
  /// In en, this message translates to:
  /// **'Check User'**
  String get checkUser;

  /// Test Firebase button
  ///
  /// In en, this message translates to:
  /// **'Test Firebase'**
  String get testFirebase;

  /// Fill test data button
  ///
  /// In en, this message translates to:
  /// **'Fill Test Data'**
  String get fillTestData;

  /// Main services section header
  ///
  /// In en, this message translates to:
  /// **'Main Services'**
  String get mainServices;

  /// My land service button
  ///
  /// In en, this message translates to:
  /// **'My Land'**
  String get myLand;

  /// My land service description
  ///
  /// In en, this message translates to:
  /// **'View land details'**
  String get viewLandDetails;

  /// Payments service button
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get payments;

  /// Payments service description
  ///
  /// In en, this message translates to:
  /// **'View transactions'**
  String get viewTransactions;

  /// Community service button
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get community;

  /// Community service description
  ///
  /// In en, this message translates to:
  /// **'Connect with people'**
  String get connectWithPeople;

  /// Profile service button
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// Profile service description
  ///
  /// In en, this message translates to:
  /// **'Account management'**
  String get accountManagement;

  /// My referrals stats label
  ///
  /// In en, this message translates to:
  /// **'My Referrals'**
  String get myReferrals;

  /// Team size stats label
  ///
  /// In en, this message translates to:
  /// **'Team Size'**
  String get teamSize;

  /// Land status stats label
  ///
  /// In en, this message translates to:
  /// **'Land Status'**
  String get landStatus;

  /// Active status text
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// Emergency services section header
  ///
  /// In en, this message translates to:
  /// **'Emergency Services'**
  String get emergencyServices;

  /// Report land grabbing button
  ///
  /// In en, this message translates to:
  /// **'Report Land Grabbing'**
  String get reportLandGrabbing;

  /// Language settings screen title
  ///
  /// In en, this message translates to:
  /// **'Language Settings'**
  String get languageSettings;

  /// Language selection instruction
  ///
  /// In en, this message translates to:
  /// **'Select your preferred language:'**
  String get selectPreferredLanguage;

  /// Apply changes button
  ///
  /// In en, this message translates to:
  /// **'Apply Changes'**
  String get applyChanges;

  /// Language preview section header
  ///
  /// In en, this message translates to:
  /// **'Language Preview'**
  String get languagePreview;

  /// Preview text for language selection
  ///
  /// In en, this message translates to:
  /// **'Welcome to TALOWA! Your land rights are protected.'**
  String get welcomeToTalowaPreview;

  /// Language change success message
  ///
  /// In en, this message translates to:
  /// **'Language changed to {language}'**
  String languageChangedTo(String language);

  /// Language change error message
  ///
  /// In en, this message translates to:
  /// **'Failed to change language: {error}'**
  String failedToChangeLanguage(String error);

  /// Afternoon greeting message
  ///
  /// In en, this message translates to:
  /// **'Good afternoon! Hope you\'re having a great day.'**
  String get goodAfternoon;

  /// Evening greeting message
  ///
  /// In en, this message translates to:
  /// **'Good evening! How was your day?'**
  String get goodEvening;

  /// Inspiration message about hard work
  ///
  /// In en, this message translates to:
  /// **'Your hard work will pay off. Together we stand strong!'**
  String get hardWorkWillPayOff;

  /// Inspiration message about unity
  ///
  /// In en, this message translates to:
  /// **'Together we will protect our land.'**
  String get togetherWeProtectLand;

  /// Inspiration message about rights
  ///
  /// In en, this message translates to:
  /// **'Your right, your land, your dignity.'**
  String get yourRightYourLand;

  /// Success story title
  ///
  /// In en, this message translates to:
  /// **'Rameshwar\'s Victory'**
  String get rameshwarVictory;

  /// Success story content
  ///
  /// In en, this message translates to:
  /// **'After 15 years, Telangana\'s Rameshwar finally got his land title.'**
  String get rameshwarVictoryStory;

  /// Success story title
  ///
  /// In en, this message translates to:
  /// **'Sunita\'s Land Rights'**
  String get sunitaLandRights;

  /// Success story content
  ///
  /// In en, this message translates to:
  /// **'Sunita from Karnataka successfully defended her 3-acre farm from illegal occupation.'**
  String get sunitaLandRightsStory;

  /// Full name input label
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// Village input label
  ///
  /// In en, this message translates to:
  /// **'Village/City'**
  String get village;

  /// Mandal input label
  ///
  /// In en, this message translates to:
  /// **'Mandal/Tehsil'**
  String get mandal;

  /// District input label
  ///
  /// In en, this message translates to:
  /// **'District'**
  String get district;

  /// State input label
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get state;

  /// Referral code input label
  ///
  /// In en, this message translates to:
  /// **'Referral Code (Optional)'**
  String get referralCode;

  /// Complete registration button
  ///
  /// In en, this message translates to:
  /// **'Complete Registration'**
  String get completeRegistration;

  /// Registration success message
  ///
  /// In en, this message translates to:
  /// **'Registration successful!'**
  String get registrationSuccessful;

  /// Registration error message
  ///
  /// In en, this message translates to:
  /// **'Registration failed. Please try again.'**
  String get registrationFailed;

  /// Phone already registered error
  ///
  /// In en, this message translates to:
  /// **'Phone number already registered'**
  String get phoneNumberAlreadyRegistered;

  /// Invalid phone number error
  ///
  /// In en, this message translates to:
  /// **'Invalid phone number format'**
  String get invalidPhoneNumber;

  /// PIN validation error
  ///
  /// In en, this message translates to:
  /// **'PIN must be at least 6 digits'**
  String get pinTooShort;

  /// Required field validation error
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get fieldRequired;

  /// Network error message
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection.'**
  String get networkError;

  /// Generic error message
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get somethingWentWrong;

  /// Loading indicator text
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Retry button text
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Cancel button text
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Save button text
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Edit button text
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Delete button text
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Confirm button text
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

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

  /// OK button text
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Close button text
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Search placeholder text
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No search results message
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResultsFound;

  /// Pull to refresh instruction
  ///
  /// In en, this message translates to:
  /// **'Pull to refresh'**
  String get pullToRefresh;

  /// Refreshing indicator text
  ///
  /// In en, this message translates to:
  /// **'Refreshing...'**
  String get refreshing;

  /// Offline status indicator
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// Online status indicator
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Notifications section title
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// Privacy section title
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// Security section title
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// About section title
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// Help section title
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// Contact support option
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get contactSupport;

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

  /// App version label
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// App build number label
  ///
  /// In en, this message translates to:
  /// **'Build'**
  String get buildNumber;

  /// Terms of service link
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// Privacy policy link
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// Share app option
  ///
  /// In en, this message translates to:
  /// **'Share App'**
  String get shareApp;

  /// Rate app option
  ///
  /// In en, this message translates to:
  /// **'Rate App'**
  String get rateApp;

  /// Send feedback option
  ///
  /// In en, this message translates to:
  /// **'Send Feedback'**
  String get sendFeedback;

  /// Report bug option
  ///
  /// In en, this message translates to:
  /// **'Report Bug'**
  String get reportBug;

  /// Check for updates option
  ///
  /// In en, this message translates to:
  /// **'Check for Updates'**
  String get checkForUpdates;

  /// App up to date message
  ///
  /// In en, this message translates to:
  /// **'App is up to date'**
  String get appUpToDate;

  /// Update available message
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateAvailable;

  /// Update now button
  ///
  /// In en, this message translates to:
  /// **'Update Now'**
  String get updateNow;

  /// Update later button
  ///
  /// In en, this message translates to:
  /// **'Update Later'**
  String get updateLater;
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
    'that was used.',
  );
}
