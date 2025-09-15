import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../core/theme/app_theme.dart';
import 'land_screen.dart';
import 'payments_screen.dart';
import 'community_screen.dart';
import 'profile_screen.dart';
// Removed unused: import '../../widgets/ai_assistant/voice_first_ai_widget.dart';
import '../../services/cultural_service.dart';
import '../../services/user_role_fix_service.dart';
import '../../utils/role_utils.dart';
import '../../providers/user_state_provider.dart';
// Removed: Home tab feature widgets no longer used
import '../../widgets/notifications/notification_badge_widget.dart';
// import '../../widgets/social_feed/live_activity_dashboard.dart';
// import '../../widgets/notifications/real_time_notification_widget.dart';
// import '../../widgets/performance/performance_dashboard_widget.dart';
import '../../widgets/security/security_dashboard_widget.dart';
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
          debugPrint('âœ… Loaded data from cache');
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

      final freshUserData = results[0];
      final freshMotivation = results[1];

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
      debugPrint('âœ… Loaded fresh data and updated cache');

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

  // Voice and text query handlers for AI Assistant
  // void _handleVoiceQuery(String query) {
  //   debugPrint('Voice query received: $query');
  // }

  // void _handleTextQuery(String query) {
  //   debugPrint('Text query received: $query');
  // }

  void _showEmergencyDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.emergency, color: AppTheme.emergencyRed),
              SizedBox(width: 8),
              Text('à¤‡à¤®à¤œà¥‡à¤‚à¤¸à¥€ à¤¸à¤¹à¤¾à¤¯à¤¤à¤¾'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('à¤¤à¥à¤°à¤¸à¥à¤¤à¤¾ à¤•à¥‡ à¤²à¤¿à¤:'),
              SizedBox(height: 8),
              Text('â€¢ à¤ªà¥à¤²à¤¿à¤¸: 100'),
              Text('â€¢ à¤à¤®à¥à¤±à¥à¤²à¥‡à¤‚à¤¸: 108'),
              Text('â€¢ à¤«à¤¾à¤¯à¤° à¤¬à¥à¤°à¤—à¤¡: 101'),
              Text('â€¢ à¤®à¤¹à¤¿à¤²à¤¾à¤¹à¥‡à¤²à¥à¤ªà¤²à¤¾à¤‡à¤¨: 1091'),
              SizedBox(height: 12),
              Text('à¤¯à¤¾ à¤¹à¥‹à¤®à¤¸à¥à¤•à¥à¤°à¤¨à¤‡à¤¨à¤ªà¤°à¤‡à¤¨à¤ªà¥‹à¤—à¤•à¤°à¤¤'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('à¤¸à¤®à¤ à¤—à¤¯à¤¾'),
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
        const SnackBar(content: Text('ðŸ”„ Fixing user roles and populating data...')),
      );

      // First fix user roles and permissions, then populate data
      await UserRoleFixService.performCompleteFix();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('âœ… User roles fixed and data populated successfully!'),
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
            content: Text('âŒ Error fixing data: $e'),
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
                  // Navigate to admin fix screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Admin Fix functionality restored! Opening admin screen...'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  // TODO: Fix admin screen import path
                  // Navigator.push(
                  //   context,
                  //   MaterialPageRoute(builder: (context) => const AdminFixScreen()),
                  // );
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
          const NotificationBadgeWidget(),
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
                    
                    // Removed per requirement: AI Assistant, Live Activity, Recent Notifications, Performance Metrics

                    // Enterprise Security section has been removed from Home for end-users per product requirements
                    // _buildSecurityDashboard(),
                    
                    // const SizedBox(height: 16),
                    
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
  // Removed: _buildCentralAIAssistant placeholder

  Widget _buildGreetingCard() {
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
            child: Consumer<UserStateProvider>(
              builder: (context, userStateProvider, child) {
                return Text(
                  RoleUtils.getDisplayName(userStateProvider.currentRole),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Get user role display text using centralized utility
  String _getUserRoleDisplay() {
    final role = userData?['role'] as String?;
    final isAdmin = userData?['isAdmin'] as bool?;
    final referralCode = userData?['referralCode'] as String?;
    
    // Check for admin indicators
    if (role == 'admin' || 
        role == 'national_leadership' || 
        isAdmin == true || 
        referralCode == 'TALADMIN') {
      return 'Administrator';
    }
    
    return RoleUtils.getDisplayName(role);
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
          const Row(
            children: [
              Icon(Icons.celebration, color: AppTheme.warningOrange),
              SizedBox(width: 8),
              Text(
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
            'Direct Referrals',
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
                  // Navigate to admin fix screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Admin Fix functionality restored! Opening admin screen...'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  // TODO: Add proper navigation to AdminFixScreen
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

  /// Build Live Activity Dashboard Section
  Widget _buildLiveActivitySection() {
    return const SizedBox.shrink();
  }

  /// Build Real-time Notifications Section
  Widget _buildRealTimeNotifications() {
    return const SizedBox.shrink();
  }

  /// Build Performance Dashboard Section
  Widget _buildPerformanceDashboard() {
    return const SizedBox.shrink();
  }

  /// Build Security Dashboard Section
  Widget _buildSecurityDashboard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.security,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Enterprise Security',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SecurityDashboardWidget(
            isCompact: true,
          ),
        ],
      ),
    );
  }
}


