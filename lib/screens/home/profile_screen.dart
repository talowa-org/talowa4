import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import '../../services/navigation/navigation_guard_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.phoneNumber != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.phoneNumber)
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('My Profile'),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : userData == null
                ? const Center(child: Text('No profile data found'))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfileCard(),
                        const SizedBox(height: 16),
                        _buildAddressCard(),
                        const SizedBox(height: 16),
                        _buildReferralCard(),
                      ],
                    ),
                  ),
    );
  }

  Widget _buildProfileCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Personal Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Full Name', userData?['fullName'] ?? 'N/A'),
            _buildInfoRow('Phone', userData?['phone'] ?? 'N/A'),
            _buildInfoRow('Email', userData?['email'] ?? 'Not provided'),
            _buildInfoRow('Date of Birth', userData?['dob'] ?? 'Not provided'),
            _buildInfoRow('Member ID', userData?['memberId'] ?? 'N/A'),
            _buildInfoRow('Role', userData?['role'] ?? 'Member'),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressCard() {
    final address = userData?['address'] as Map<String, dynamic>?;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Address Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('House No', address?['houseNo'] ?? 'Not provided'),
            _buildInfoRow('Street', address?['street'] ?? 'Not provided'),
            _buildInfoRow('Village/City', address?['villageCity'] ?? 'N/A'),
            _buildInfoRow('Mandal', address?['mandal'] ?? 'N/A'),
            _buildInfoRow('District', address?['district'] ?? 'N/A'),
            _buildInfoRow('State', address?['state'] ?? 'N/A'),
            _buildInfoRow('Pincode', address?['pincode'] ?? 'Not provided'),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Referral Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('My Referral Code', userData?['referralCode'] ?? 'N/A'),
            _buildInfoRow('Referred By', userData?['referredBy'] ?? 'Direct signup'),
            _buildInfoRow('Direct Referrals', '${userData?['directReferrals'] ?? 0}'),
            _buildInfoRow('Team Referrals', '${userData?['teamReferrals'] ?? 0}'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}