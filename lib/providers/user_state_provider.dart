import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth/auth_service.dart';
import '../services/referral/role_progression_service.dart';
import '../models/user_profile.dart';

/// Global user state provider that manages user data and role changes
/// Ensures UI synchronization across all tabs when user roles are updated
class UserStateProvider extends ChangeNotifier {
  static UserStateProvider? _instance;
  static UserStateProvider get instance => _instance ??= UserStateProvider._();
  
  UserStateProvider._();
  
  // User data
  UserProfile? _userProfile;
  String? _currentRole;
  int? _currentRoleLevel;
  Map<String, dynamic>? _userStats;
  
  // State
  bool _isLoading = false;
  String? _error;
  
  // Firestore listener
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  
  // Getters
  UserProfile? get userProfile => _userProfile;
  String? get currentRole => _currentRole;
  int? get currentRoleLevel => _currentRoleLevel;
  Map<String, dynamic>? get userStats => _userStats;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  /// Initialize user state and start listening to changes
  Future<void> initialize() async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) return;
    
    _setLoading(true);
    
    try {
      // Start listening to user document changes
      _startUserListener(currentUser.uid);
      
      // Load initial user data
      await _loadUserData(currentUser.uid);
      
    } catch (e) {
      _setError('Failed to initialize user state: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  /// Start listening to user document changes for real-time updates
  void _startUserListener(String userId) {
    _userSubscription?.cancel();
    
    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists) {
              _handleUserDataUpdate(snapshot.data()!);
            }
          },
          onError: (error) {
            _setError('Error listening to user changes: $error');
          },
        );
  }
  
  /// Handle user data updates from Firestore
  void _handleUserDataUpdate(Map<String, dynamic> userData) {
    final newRole = userData['role'] as String?;
    final newRoleLevel = userData['currentRoleLevel'] as int?;
    
    // Check if role has changed
    final roleChanged = newRole != _currentRole || newRoleLevel != _currentRoleLevel;
    
    // Update user data
    _currentRole = newRole;
    _currentRoleLevel = newRoleLevel;
    _userStats = {
      'directReferrals': userData['directReferrals'] ?? 0,
      'teamReferrals': userData['teamReferrals'] ?? 0,
      'teamSize': userData['teamReferrals'] ?? 0,
    };
    
    // Update user profile if we have one
    if (_userProfile != null) {
      _userProfile = _userProfile!.copyWith(
        role: newRole ?? _userProfile!.role,
        directReferrals: userData['directReferrals'] ?? _userProfile!.directReferrals,
        teamSize: userData['teamReferrals'] ?? _userProfile!.teamSize,
      );
    }
    
    // Notify listeners about the update
    notifyListeners();
    
    // Log role change for debugging
    if (roleChanged && kDebugMode) {
      print('🔄 Role updated: $_currentRole (Level $_currentRoleLevel)');
    }
  }
  
  /// Load initial user data
  Future<void> _loadUserData(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        _handleUserDataUpdate(userData);
        
        // Create user profile from data
        _userProfile = UserProfile(
          id: userData['id'] ?? '',
          name: userData['fullName'] ?? 'Unknown',
          email: userData['email'],
          phone: userData['phoneNumber'],
          role: userData['role'] ?? 'member',
          roleLevel: userData['roleLevel'] ?? 1,
          stats: Map<String, dynamic>.from(userData['stats'] ?? {}),
          directReferrals: userData['directReferrals'] ?? 0,
          teamSize: userData['teamReferrals'] ?? 0,
          createdAt: DateTime.fromMillisecondsSinceEpoch(userData['createdAt'] ?? 0),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(userData['updatedAt'] ?? DateTime.now().millisecondsSinceEpoch),
        );
      }
    } catch (e) {
      _setError('Failed to load user data: $e');
    }
  }
  
  /// Calculate goal progress based on current role requirements
  double _calculateGoalProgress(Map<String, dynamic> userData) {
    final currentRole = userData['role'] as String? ?? 'member';
    final directReferrals = userData['directReferrals'] as int? ?? 0;
    final teamSize = userData['teamReferrals'] as int? ?? 0;
    
    // Get next role requirements
    final nextRoleData = RoleProgressionService.getAllRoleDefinitions();
    final roleHierarchy = ['member', 'volunteer', 'team_leader', 'area_coordinator', 
                          'mandal_coordinator', 'constituency_coordinator', 'district_coordinator',
                          'zonal_regional_coordinator', 'state_coordinator'];
    
    final currentIndex = roleHierarchy.indexOf(currentRole);
    if (currentIndex == -1 || currentIndex >= roleHierarchy.length - 1) {
      return 1.0; // Already at highest role
    }
    
    final nextRole = roleHierarchy[currentIndex + 1];
    final nextRoleDefinition = nextRoleData[nextRole];
    
    if (nextRoleDefinition == null) return 1.0;
    
    final referralProgress = directReferrals / nextRoleDefinition.directReferralsRequired;
    final teamProgress = teamSize / nextRoleDefinition.teamSizeRequired;
    
    // Return the minimum progress (both requirements must be met)
    return (referralProgress + teamProgress) / 2;
  }
  
  /// Refresh user data manually
  Future<void> refreshUserData() async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) return;
    
    _setLoading(true);
    
    try {
      await _loadUserData(currentUser.uid);
      
      // Also check for role progression
      await checkRoleProgression();
      
    } catch (e) {
      _setError('Failed to refresh user data: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  /// Check for role progression and update if needed
  Future<void> checkRoleProgression() async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) return;
    
    try {
      final result = await RoleProgressionService.checkAndUpdateRoleRealTime(currentUser.uid);
      
      if (result['promoted'] == true) {
        // Role was updated, the listener will handle the UI update
        if (kDebugMode) {
          print('🎉 User promoted from ${result['previousRole']} to ${result['currentRole']}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking role progression: $e');
      }
    }
  }
  
  /// Set loading state
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }
  
  /// Set error state
  void _setError(String? error) {
    if (_error != error) {
      _error = error;
      notifyListeners();
    }
  }
  
  /// Clean up resources
  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }
  
  /// Reset state (for logout)
  void reset() {
    _userSubscription?.cancel();
    _userProfile = null;
    _currentRole = null;
    _currentRoleLevel = null;
    _userStats = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}