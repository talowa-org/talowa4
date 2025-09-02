import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/theme/app_theme.dart';
import 'land_screen.dart';
import 'payments_screen.dart';
import 'community_screen.dart';
import 'profile_screen.dart';
// import '../../widgets/ai_assistant/voice_first_ai_widget.dart';
// import '../../services/ai_assistant/voice_command_handler.dart';
// import '../admin/admin_fix_screen.dart';
// Test imports removed for production
import '../../services/cultural_service.dart';
import '../../services/user_role_fix_service.dart';
// import '../../services/auth/auth_state_manager.dart';
// import '../../generated/l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? userData;
  Map<String, dynamic>? dailyMotivation;
  bool isLoading = true;
  bool isDataCached = false;
  String get currentLanguage => 'en';

  // Cache keys for SharedPreferences
  static const String _userDataCacheKey = 'home_user_data';
  static const String _motivationCacheKey = 'home_daily_motivation';
  static const String _lastUpdateKey = 'home_last_update';

  @override
  void initState() {
    super.initState();
    _loadDataWithCaching();
    
    // Listen for language changes
    // LocalizationService.addListener(_onLanguageChanged);
  }
  
  @override
  void dispose() {
    // LocalizationService.removeListener(_onLanguageChanged);
    super.dispose();
  }
  


  /// Load data with caching for better performance
  Future<void> _loadDataWithCaching() async {
    try {
      // First, try to load from cache
      await _loadFromCache();
      
      // Then load fresh data in background
      await _loadFreshData();
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  /// Load cached data for immediate display
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdate = prefs.getInt(_lastUpdateKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Cache is valid for 1 hour
      if (now - lastUpdate < 3600000) {
        final cachedUserData = prefs.getString(_userDataCacheKey);
        final cachedMotivation = prefs.getString(_motivationCacheKey);
        
        if (cachedUserData != null && cachedMotivation != null) {
          if (mounted) {
            setState(() {
              userData = json.decode(cachedUserData);
              dailyMotivation = json.decode(cachedMotivation);
              isLoading = false;
              isDataCached = true;
            });
          }
          debugPrint('✅ Loaded data from cache');
          return;
        }
      }
    } catch (e) {
      debugPrint('Cache loading error: $e');
    }
  }

  /// Load fresh data from Firebase and update cache
  Future<void> _loadFreshData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Load both user data and motivation in parallel
      final results = await Future.wait([
        _fetchUserData(user.uid),
        _fetchDailyMotivation(),
      ]);

      final freshUserData = results[0] as Map<String, dynamic>?;
      final freshMotivation = results[1] as Map<String, dynamic>?;

      if (mounted) {
        setState(() {
          if (freshUserData != null) userData = freshUserData;
          if (freshMotivation != null) dailyMotivation = freshMotivation;
          isLoading = false;
          isDataCached = false;
        });
      }

      // Update cache
      await _updateCache(freshUserData, freshMotivation);
      debugPrint('✅ Loaded fresh data and updated cache');

    } catch (e) {
      debugPrint('Fresh data loading error: $e');
      if (mounted && !isDataCached) {
        setState(() => isLoading = false);
      }
    }
  }

  /// Fetch user data from Firestore
  Future<Map<String, dynamic>?> _fetchUserData(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      
      return doc.exists ? doc.data() : null;
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      return null;
    }
  }

  /// Fetch daily motivation
  Future<Map<String, dynamic>?> _fetchDailyMotivation() async {
    try {
      return await CulturalService.getDailyMotivation();
    } catch (e) {
      debugPrint('Error fetching motivation: $e');
      return null;
    }
  }

  /// Update cache with fresh data
  Future<void> _updateCache(Map<String, dynamic>? userData, Map<String, dynamic>? motivation) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (userData != null) {
        await prefs.setString(_userDataCacheKey, json.encode(userData));
      }
      
      if (motivation != null) {
        await prefs.setString(_motivationCacheKey, json.encode(motivation));
      }
      
      await prefs.setInt(_lastUpdateKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Cache update error: $e');
    }
  }

  /// Manual refresh for pull-to-refresh
  Future<void> _refreshData() async {
    setState(() {
      isLoading = true;
      isDataCached = false;
    });
    
    // Clear cache to force fresh data load
    await _clearCache();
    await _loadFreshData();
  }
  
  /// Clear cached data
  Future<void> _clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('home_user_data');
      await prefs.remove('home_motivation_data');
      await prefs.remove('home_cache_timestamp');
      debugPrint('Cache cleared successfully');
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  void _handleVoiceQuery(String query) async {
    // TODO: Implement voice command handling
    debugPrint('Voice query: $query');
    /*
    try {
      final voiceHandler = VoiceCommandHandler();
      final response = await voiceHandler.processCommand(query);
      
      // Show response message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: AppTheme.talowaGreen,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      // Execute action
      switch (response.action) {
        case VoiceCommandAction.navigateToLand:
          Navigator.push(context, MaterialPageRoute(builder: (context) => const LandScreen()));
          break;
        case VoiceCommandAction.navigateToPayments:
          Navigator.push(context, MaterialPageRoute(builder: (context) => const PaymentsScreen()));
          break;
        case VoiceCommandAction.navigateToCommunity:
          Navigator.push(context, MaterialPageRoute(builder: (context) => const CommunityScreen()));
          break;
        case VoiceCommandAction.navigateToProfile:
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
          break;
        case VoiceCommandAction.showEmergencyHelp:
          _showEmergencyDialog();
          break;
        case VoiceCommandAction.showMessage:
        case VoiceCommandAction.showError:
          // Message already shown via SnackBar
          break;
        default:
          break;
      }
    } catch (e) {
      debugPrint('Error handling voice query: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('वॉइस कमांड प्रोसेस करने में त्रुटि।'),
            backgroundColor: AppTheme.emergencyRed,
          ),
        );
      }
    }
    */
  }

  void _showEmergencyDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.emergency, color: AppTheme.emergencyRed),
              SizedBox(width: 8),
              Text('इमरजेंसी सहायता'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('तुरंत सहायता के लिए:'),
              SizedBox(height: 8),
              Text('• पुलिस: 100'),
              Text('• एम्बुलेंस: 108'),
              Text('• फायर ब्रिगेड: 101'),
              Text('• महिला हेल्पलाइन: 1091'),
              SizedBox(height: 12),
              Text('या होम स्क्रीन पर इमरजेंसी बटन का उपयोग करें।'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('समझ गया'),
            ),
          ],
        );
      },
    );
  }

  // Debug method to test data population and fix user roles
  Future<void> _testDataPopulation() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🔄 Fixing user roles and populating data...')),
      );

      // First fix user roles and permissions, then populate data
      await UserRoleFixService.performCompleteFix();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ User roles fixed and data populated successfully!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );

        // Reload data
        _refreshData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error fixing data: $e'),
            backgroundColor: AppTheme.emergencyRed,
          ),
        );
      }
    }
  }

  // Show logout confirmation dialog
  Future<bool?> _showLogoutConfirmation() async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text(
            'Are you sure you want to logout? You will need to login again to access your account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emergencyRed,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  // Show system actions menu
  void _showSystemActionsMenu() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'System Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.refresh, color: AppTheme.talowaGreen),
                title: const Text('Populate Missing Data'),
                subtitle: const Text('Fix user roles and populate system data'),
                onTap: () {
                  Navigator.pop(context);
                  _testDataPopulation();
                },
              ),
              ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: Colors.orange),
                title: const Text('Fix Admin Configuration'),
                subtitle: const Text('Fix admin role and referral code issues'),
                onTap: () async {
                  Navigator.pop(context);
                  // TODO: Navigate to admin screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Admin functionality coming soon')),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Talowa Home'),
        backgroundColor: AppTheme.talowaGreen,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Remove automatic back button
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              // Show confirmation dialog for explicit logout
              final shouldLogout = await _showLogoutConfirmation();
              if (shouldLogout == true) {
                // Use Firebase Auth for logout
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context, 
                    '/welcome', 
                    (route) => false,
                  );
                }
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: isLoading && !isDataCached
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(), // Enable pull-to-refresh
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 30.0), // Extra bottom padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Show cache indicator
                    if (isDataCached) _buildCacheIndicator(),
                    
                    // AI Assistant - Central Feature (Always Visible)
                    _buildCentralAIAssistant(),
                    
                    const SizedBox(height: 24),
                    
                    // Cultural Greeting
                    _buildGreetingCard(),
                    
                    const SizedBox(height: 16),
                    
                    // Daily Motivation
                    if (dailyMotivation != null) _buildMotivationCard(),
                    
                    const SizedBox(height: 16),
                    
                    // Quick Stats
                    _buildQuickStats(),
                    
                    const SizedBox(height: 16),
                    
                    // Dashboard Grid
                    const Text(
                      'Main Services', // Using English directly for now
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.1,
                      children: [
                        _buildDashboardCard(
                          icon: Icons.landscape,
                          title: 'My Land',
                          subtitle: 'View land details',
                          color: Colors.green,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LandScreen()),
                          ),
                        ),
                        _buildDashboardCard(
                          icon: Icons.account_balance_wallet,
                          title: 'Payments',
                          subtitle: 'View transactions',
                          color: Colors.blue,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const PaymentsScreen()),
                          ),
                        ),
                        _buildDashboardCard(
                          icon: Icons.people,
                          title: 'Community',
                          subtitle: 'Connect with people',
                          color: Colors.orange,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const CommunityScreen()),
                          ),
                        ),
                        _buildDashboardCard(
                          icon: Icons.person,
                          title: 'Profile',
                          subtitle: 'Account management',
                          color: Colors.purple,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ProfileScreen()),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Emergency Actions
                    _buildEmergencyActions(),
                    
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showSystemActionsMenu,
        backgroundColor: AppTheme.talowaGreen,
        tooltip: 'System Actions',
        child: const Icon(Icons.build, color: Colors.white),
      ),
    );
  }

  /// Cache indicator to show when data is from cache
  Widget _buildCacheIndicator() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cached, size: 16, color: Colors.blue.shade600),
          const SizedBox(width: 8),
          Text(
            'Showing cached data - Pull down to refresh',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue.shade600,
            ),
          ),
        ],
      ),
    );
  }

  /// Central AI Assistant - Always Visible, Voice-First Feature
  Widget _buildCentralAIAssistant() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.talowaGreen.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with prominent branding
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.talowaGreen, Color(0xFF2D7D32)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.smart_toy,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TALOWA AI Assistant',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Your voice-first legal & land rights companion',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.mic,
                        color: Colors.white,
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Voice-First • English • हिंदी • తెలుగు',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // AI Assistant Widget - Always Expanded
          // TODO: Add AI Assistant Widget
          Container(
            height: 100,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: const Center(
              child: Text(
                '🤖 AI Assistant Coming Soon',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGreetingCard() {
    final localizations = AppLocalizations.of(context);
    final userName = userData?['fullName'] ?? 'User';
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.talowaGreen.withValues(alpha: 0.8), AppTheme.talowaGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.talowaGreen.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome $userName',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Welcome to TALOWA',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getUserRoleDisplay(),
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Get user role display text
  String _getUserRoleDisplay() {
    final role = userData?['role'] as String?;
    final isAdmin = userData?['isAdmin'] as bool?;
    final referralCode = userData?['referralCode'] as String?;
    
    // Check for admin indicators
    if (role == 'admin' || 
        role == 'national_leadership' || 
        isAdmin == true || 
        referralCode == 'TALADMIN') {
      return 'Admin';
    }
    
    // Map other roles to display names
    switch (role?.toLowerCase()) {
      case 'regional_coordinator':
        return 'Regional Coordinator';
      case 'coordinator':
        return 'Coordinator';
      case 'organizer':
        return 'Organizer';
      case 'activist':
        return 'Activist';
      case 'member':
      default:
        return 'Member';
    }
  }

  Widget _buildMotivationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warningOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warningOrange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.celebration, color: AppTheme.warningOrange),
              const SizedBox(width: 8),
              const Text(
                "Today's Inspiration",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'United we stand, let us protect our land together.',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.warningOrange.withValues(alpha: 0.8),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Success Story',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'After 15 years, Rameshwar from Telangana finally got his land patta.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'My Referrals',
            '${userData?['directReferrals'] ?? 0}',
            Icons.people,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Team Size',
            '${userData?['teamReferrals'] ?? 0}',
            Icons.groups,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Land Status',
            userData?['landStatus'] ?? 'Active',
            Icons.landscape,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.secondaryText,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Emergency Services',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildEmergencyButton(
                'Report Land Grabbing',
                Icons.report_problem,
                Colors.red,
                () {
                  // Navigate to incident reporting
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildEmergencyButton(
                'Legal Help',
                Icons.gavel,
                Colors.blue,
                () {
                  // Navigate to legal help
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildEmergencyButton(
                'Fix Admin Config',
                Icons.admin_panel_settings,
                Colors.orange,
                () async {
                  // TODO: Navigate to admin screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Admin functionality coming soon')),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmergencyButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Test services button removed for production

  Widget _buildDashboardCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.secondaryText,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
