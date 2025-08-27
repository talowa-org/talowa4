import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'land_screen.dart';
import 'payments_screen.dart';
import 'community_screen.dart';
import 'profile_screen.dart';
import '../../widgets/ai_assistant/ai_assistant_widget.dart';
// Test imports removed for production
import '../../services/cultural_service.dart';
import '../../services/user_role_fix_service.dart';
import '../../generated/l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? userData;
  Map<String, dynamic>? dailyMotivation;
  bool isLoading = true;
  String get currentLanguage => 'en';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadDailyMotivation();
    
    // Listen for language changes
    // LocalizationService.addListener(_onLanguageChanged);
  }
  
  @override
  void dispose() {
    // LocalizationService.removeListener(_onLanguageChanged);
    super.dispose();
  }
  
  void _onLanguageChanged() {
    if (mounted) {
      setState(() {
        // Reload data when language changes
        _loadDailyMotivation();
      });
    }
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (doc.exists && mounted) {
          setState(() {
            userData = doc.data();
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _loadDailyMotivation() async {
    try {
      final motivation = await CulturalService.getDailyMotivation();
      if (mounted) {
        setState(() {
          dailyMotivation = motivation;
        });
      }
    } catch (e) {
      debugPrint('Error loading motivation: $e');
    }
  }

  void _handleVoiceQuery(String query) {
    // Handle voice queries and navigate accordingly
    final lowerQuery = query.toLowerCase();

    if (lowerQuery.contains('land') || lowerQuery.contains('जमीन') || lowerQuery.contains('भूमि')) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const LandScreen()));
    } else if (lowerQuery.contains('payment') || lowerQuery.contains('पेमेंट') || lowerQuery.contains('भुगतान')) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const PaymentsScreen()));
    } else if (lowerQuery.contains('community') || lowerQuery.contains('समुदाय') || lowerQuery.contains('लोग')) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const CommunityScreen()));
    } else if (lowerQuery.contains('profile') || lowerQuery.contains('प्रोफाइल')) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
    }
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
            backgroundColor: Colors.green,
          ),
        );

        // Reload daily motivation
        _loadDailyMotivation();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error fixing data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Talowa Home'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context, 
                  '/', 
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 30.0), // Extra bottom padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cultural Greeting
                  _buildGreetingCard(),
                  
                  const SizedBox(height: 16),
                  
                  // AI Assistant (New Implementation)
                  const AIAssistantWidget(),
                  
                  const SizedBox(height: 16),
                  
                  // Production ready - test features removed
                  
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
                  
                  const SizedBox(height: 16),
                  
                  // Production ready - test features removed
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _testDataPopulation,
        backgroundColor: Colors.green,
        tooltip: 'Populate Missing Data',
        child: const Icon(Icons.refresh, color: Colors.white),
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
          colors: [Colors.green.shade400, Colors.green.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
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
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              localizations.member,
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

  Widget _buildMotivationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.celebration, color: Colors.orange.shade600),
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
              color: Colors.orange.shade700,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
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
              color: Colors.grey,
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
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
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
                  color: color.withOpacity(0.1),
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
                  color: Colors.grey,
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
