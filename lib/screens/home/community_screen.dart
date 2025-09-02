import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import '../../services/navigation/navigation_guard_service.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  List<Map<String, dynamic>> communityMembers = [];
  bool isLoading = true;
  String? currentUserPhone;

  @override
  void initState() {
    super.initState();
    currentUserPhone = FirebaseAuth.instance.currentUser?.phoneNumber;
    _loadCommunityMembers();
  }

  Future<void> _loadCommunityMembers() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      if (mounted) {
        setState(() {
          communityMembers = querySnapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading community: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Community'),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() => isLoading = true);
                _loadCommunityMembers();
              },
            ),
          ],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildStatsCard(),
                  Expanded(child: _buildMembersList()),
                ],
              ),
      ),
    );
  }

  Widget _buildStatsCard() {
    final totalMembers = communityMembers.length;
    // Check for multiple admin role indicators
    final rootAdmins = communityMembers.where((m) => 
      m['role'] == 'Root Administrator' || 
      m['role'] == 'admin' || 
      m['role'] == 'national_leadership' ||
      m['referralCode'] == 'TALADMIN' ||
      m['isAdmin'] == true
    ).length;
    final regularMembers = totalMembers - rootAdmins;

    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Community Stats',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Total Members', totalMembers.toString(), Colors.blue),
                  _buildStatItem('Admins', rootAdmins.toString(), Colors.green),
                  _buildStatItem('Members', regularMembers.toString(), Colors.orange),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildMembersList() {
    if (communityMembers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No community members found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: communityMembers.length,
      itemBuilder: (context, index) {
        final member = communityMembers[index];
        return _buildMemberCard(member);
      },
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final isCurrentUser = member['phone'] == currentUserPhone;
    // Check for multiple admin role indicators
    final isAdmin = member['role'] == 'Root Administrator' || 
                   member['role'] == 'admin' || 
                   member['role'] == 'national_leadership' ||
                   member['referralCode'] == 'TALADMIN' ||
                   member['isAdmin'] == true;
    final fullName = member['fullName'] as String? ?? 'Unknown';
    final phone = member['phone'] as String? ?? 'N/A';
    final memberId = member['memberId'] as String? ?? 'N/A';
    final address = member['address'] as Map<String, dynamic>?;
    final location = address != null 
        ? '${address['villageCity'] ?? ''}, ${address['district'] ?? ''}'
        : 'Location not provided';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isCurrentUser ? 4 : 1,
      color: isCurrentUser ? Colors.green.shade50 : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isAdmin ? Colors.green : Colors.blue,
          child: Text(
            fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                fullName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isCurrentUser ? Colors.green.shade700 : null,
                ),
              ),
            ),
            if (isCurrentUser)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'YOU',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (isAdmin)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'ADMIN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: $memberId'),
            Text('Location: $location'),
            if (!isCurrentUser) Text('Phone: ${phone.replaceRange(6, 10, 'XXXX')}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isAdmin ? Icons.admin_panel_settings : Icons.person,
              color: isAdmin ? Colors.green : Colors.grey,
            ),
            Text(
              isAdmin ? 'Admin' : 'Member',
              style: TextStyle(
                fontSize: 10,
                color: isAdmin ? Colors.green : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}