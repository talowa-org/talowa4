// Create Group Screen for TALOWA Messaging System
// Reference: in-app-communication/requirements.md - Group Creation

import 'package:flutter/material.dart';
import '../../models/messaging/group_model.dart';
import '../../models/user_model.dart';
import '../../services/messaging/group_service.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/onboarding/feature_discovery_widget.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final GroupService _groupService = GroupService();
  final DatabaseService _databaseService = DatabaseService();

  GroupType _selectedType = GroupType.village;
  GeographicScope? _selectedLocation;
  GroupSettings _settings = GroupSettings.defaultSettings();
  final List<String> _selectedMemberIds = [];
  List<UserModel> _availableUsers = [];
  bool _isLoading = false;
  bool _isLoadingUsers = false;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser != null) {
        final userDoc = await _databaseService.getUser(currentUser.uid);
        if (userDoc != null) {
          setState(() {
            _currentUser = userDoc;
            _selectedLocation = GeographicScope(
              level: AppConstants.levelVillage,
              locationId: userDoc.address.villageCity,
              locationName: userDoc.address.villageCity,
            );
          });
          _loadAvailableUsers();
        }
      }
    } catch (e) {
      debugPrint('Error loading current user: $e');
    }
  }

  Future<void> _loadAvailableUsers() async {
    if (_currentUser == null) return;

    try {
      setState(() {
        _isLoadingUsers = true;
      });

      // Load users from the same geographic area
      final users = await _databaseService.getUsersByLocation(
        level: _selectedLocation?.level ?? AppConstants.levelVillage,
        locationId: _selectedLocation?.locationId ?? '',
      );

      setState(() {
        _availableUsers = users.where((user) => user.id != _currentUser!.id).toList();
        _isLoadingUsers = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingUsers = false;
      });
      debugPrint('Error loading available users: $e');
    }
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location')),
      );
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      final groupId = await _groupService.createGroup(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        location: _selectedLocation!,
        initialMemberIds: _selectedMemberIds,
        settings: _settings,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Group created successfully!'),
            backgroundColor: Color(AppConstants.successGreenValue),
          ),
        );
        Navigator.of(context).pop(groupId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating group: $e'),
            backgroundColor: const Color(AppConstants.emergencyRedValue),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FeatureDiscoveryWidget(
      featureKey: 'group_management_training',
      title: 'New to Group Management?',
      description: 'As a coordinator, you have special powers to create and manage groups. Take our training to learn best practices.',
      icon: Icons.school,
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
        backgroundColor: const Color(AppConstants.talowaGreenValue),
        foregroundColor: Colors.white,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _createGroup,
              child: const Text(
                'CREATE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildBasicInfoSection(),
            const SizedBox(height: 24),
            _buildGroupTypeSection(),
            const SizedBox(height: 24),
            _buildLocationSection(),
            const SizedBox(height: 24),
            _buildMembersSection(),
            const SizedBox(height: 24),
            _buildSettingsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Basic Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Group Name *',
                hintText: 'Enter group name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Group name is required';
                }
                if (value.trim().length < 3) {
                  return 'Group name must be at least 3 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Enter group description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) {
                if (value != null && value.trim().length > 500) {
                  return 'Description must be less than 500 characters';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupTypeSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Group Type',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: GroupType.values.map((type) {
                final isSelected = _selectedType == type;
                return FilterChip(
                  label: Text(type.displayName),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedType = type;
                      });
                    }
                  },
                  selectedColor: const Color(AppConstants.talowaGreenValue).withValues(alpha: 0.2),
                  checkmarkColor: const Color(AppConstants.talowaGreenValue),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Location',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedLocation != null) ...[
              ListTile(
                leading: const Icon(Icons.location_on),
                title: Text(_selectedLocation!.locationName),
                subtitle: Text('${_selectedLocation!.level} level'),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: _showLocationPicker,
                ),
              ),
            ] else ...[
              ElevatedButton.icon(
                onPressed: _showLocationPicker,
                icon: const Icon(Icons.location_on),
                label: const Text('Select Location'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMembersSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Initial Members',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_selectedMemberIds.length} selected',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoadingUsers)
              const LoadingWidget(message: 'Loading users...')
            else if (_availableUsers.isEmpty)
              const Text('No users found in your area')
            else
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: _availableUsers.length,
                  itemBuilder: (context, index) {
                    final user = _availableUsers[index];
                    final isSelected = _selectedMemberIds.contains(user.id);
                    
                    return CheckboxListTile(
                      title: Text(user.fullName),
                      subtitle: Text(user.role),
                      value: isSelected,
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            _selectedMemberIds.add(user.id);
                          } else {
                            _selectedMemberIds.remove(user.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Group Settings',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildPermissionSetting(
              'Who can add members',
              _settings.whoCanAddMembers,
              (permission) => setState(() {
                _settings = _settings.copyWith(whoCanAddMembers: permission);
              }),
            ),
            const SizedBox(height: 12),
            _buildPermissionSetting(
              'Who can send messages',
              _settings.whoCanSendMessages,
              (permission) => setState(() {
                _settings = _settings.copyWith(whoCanSendMessages: permission);
              }),
            ),
            const SizedBox(height: 12),
            _buildPermissionSetting(
              'Who can share media',
              _settings.whoCanShareMedia,
              (permission) => setState(() {
                _settings = _settings.copyWith(whoCanShareMedia: permission);
              }),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Require approval to join'),
              value: _settings.requireApprovalToJoin,
              onChanged: (value) => setState(() {
                _settings = _settings.copyWith(requireApprovalToJoin: value);
              }),
            ),
            SwitchListTile(
              title: const Text('Allow anonymous messages'),
              value: _settings.allowAnonymousMessages,
              onChanged: (value) => setState(() {
                _settings = _settings.copyWith(allowAnonymousMessages: value);
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionSetting(
    String title,
    GroupPermission currentValue,
    Function(GroupPermission) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: GroupPermission.values.map((permission) {
            final isSelected = currentValue == permission;
            return FilterChip(
              label: Text(permission.displayName),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  onChanged(permission);
                }
              },
              selectedColor: const Color(AppConstants.talowaGreenValue).withValues(alpha: 0.2),
              checkmarkColor: const Color(AppConstants.talowaGreenValue),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _showLocationPicker() {
    if (_currentUser == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(_currentUser!.address.villageCity),
              subtitle: const Text('Village level'),
              onTap: () {
                setState(() {
                  _selectedLocation = GeographicScope(
                    level: AppConstants.levelVillage,
                    locationId: _currentUser!.address.villageCity,
                    locationName: _currentUser!.address.villageCity,
                  );
                });
                Navigator.of(context).pop();
                _loadAvailableUsers();
              },
            ),
            ListTile(
              title: Text(_currentUser!.address.mandal),
              subtitle: const Text('Mandal level'),
              onTap: () {
                setState(() {
                  _selectedLocation = GeographicScope(
                    level: AppConstants.levelMandal,
                    locationId: _currentUser!.address.mandal,
                    locationName: _currentUser!.address.mandal,
                  );
                });
                Navigator.of(context).pop();
                _loadAvailableUsers();
              },
            ),
            ListTile(
              title: Text(_currentUser!.address.district),
              subtitle: const Text('District level'),
              onTap: () {
                setState(() {
                  _selectedLocation = GeographicScope(
                    level: AppConstants.levelDistrict,
                    locationId: _currentUser!.address.district,
                    locationName: _currentUser!.address.district,
                  );
                });
                Navigator.of(context).pop();
                _loadAvailableUsers();
              },
            ),
          ],
        ),
      ),
    );
  }
}


