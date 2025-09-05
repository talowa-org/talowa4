import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import '../../services/navigation/navigation_guard_service.dart';

class LandScreen extends StatefulWidget {
  const LandScreen({super.key});

  @override
  State<LandScreen> createState() => _LandScreenState();
}

class _LandScreenState extends State<LandScreen> {
  List<Map<String, dynamic>> landRecords = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLandRecords();
  }

  Future<void> _loadLandRecords() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.phoneNumber != null) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('land_records')
            .where('ownerPhone', isEqualTo: user!.phoneNumber)
            .orderBy('createdAt', descending: true)
            .get();

        if (mounted) {
          setState(() {
            landRecords = querySnapshot.docs
                .map((doc) => {'id': doc.id, ...doc.data()})
                .toList();
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading land records: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('My Land'),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showAddLandDialog,
            ),
          ],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : landRecords.isEmpty
                ? _buildEmptyState()
                : _buildLandList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.landscape,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Land Records Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first land record to get started',
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddLandDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Land Record'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: landRecords.length,
      itemBuilder: (context, index) {
        final land = landRecords[index];
        return _buildLandCard(land);
      },
    );
  }

  Widget _buildLandCard(Map<String, dynamic> land) {
    final surveyNumber = land['surveyNumber'] as String? ?? 'N/A';
    final area = land['area'] as double? ?? 0.0;
    final unit = land['unit'] as String? ?? 'acres';
    final location = land['location'] as String? ?? 'Unknown';
    final landType = land['landType'] as String? ?? 'Agricultural';
    final status = land['status'] as String? ?? 'Active';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Survey No: $surveyNumber',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: status == 'Active' ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    Icons.straighten,
                    'Area',
                    '$area $unit',
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    Icons.location_on,
                    'Location',
                    location,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildInfoItem(
              Icons.terrain,
              'Land Type',
              landType,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showLandDetails(land),
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('View Details'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _editLand(land),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  void _showAddLandDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Land Record'),
        content: const Text(
          'Land record management feature is coming soon. This will allow you to:\n\n'
          'â€¢ Add land survey details\n'
          'â€¢ Upload land documents\n'
          'â€¢ Track land ownership\n'
          'â€¢ Manage land transactions',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLandDetails(Map<String, dynamic> land) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Land Details - ${land['surveyNumber']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Survey Number: ${land['surveyNumber']}'),
            Text('Area: ${land['area']} ${land['unit']}'),
            Text('Location: ${land['location']}'),
            Text('Land Type: ${land['landType']}'),
            Text('Status: ${land['status']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _editLand(Map<String, dynamic> land) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Land Record'),
        content: const Text('Land editing feature is coming soon.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
