// Geographic Scope Widget - Display geographic targeting information
// Part of Task 6: Implement PostWidget for individual posts

import 'package:flutter/material.dart';
import '../../models/social_feed/geographic_targeting.dart';

/// Widget for displaying geographic scope of posts
class GeographicScopeWidget extends StatelessWidget {
  final GeographicTargeting targeting;
  final bool showIcon;
  final bool isCompact;
  
  const GeographicScopeWidget({
    super.key,
    required this.targeting,
    this.showIcon = true,
    this.isCompact = true,
  });
  
  @override
  Widget build(BuildContext context) {
    final scopeInfo = _getScopeInfo();
    
    if (scopeInfo['text'] == null) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(
              scopeInfo['icon'],
              size: 12,
              color: Colors.blue,
            ),
            const SizedBox(width: 4),
          ],
          
          Flexible(
            child: Text(
              scopeInfo['text'],
              style: const TextStyle(
                fontSize: 10,
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
  
  Map<String, dynamic> _getScopeInfo() {
    // Determine the most specific geographic level
    if (targeting.village?.isNotEmpty == true) {
      return {
        'text': isCompact ? targeting.village : 'Village: ${targeting.village}',
        'icon': Icons.home,
        'level': 'village',
      };
    } else if (targeting.mandal?.isNotEmpty == true) {
      return {
        'text': isCompact ? targeting.mandal : 'Mandal: ${targeting.mandal}',
        'icon': Icons.location_city,
        'level': 'mandal',
      };
    } else if (targeting.district?.isNotEmpty == true) {
      return {
        'text': isCompact ? targeting.district : 'District: ${targeting.district}',
        'icon': Icons.account_balance,
        'level': 'district',
      };
    } else if (targeting.state?.isNotEmpty == true) {
      return {
        'text': isCompact ? targeting.state : 'State: ${targeting.state}',
        'icon': Icons.map,
        'level': 'state',
      };
    } else if (targeting.radiusKm != null && targeting.centerPoint != null) {
      return {
        'text': '${targeting.radiusKm!.toInt()}km radius',
        'icon': Icons.my_location,
        'level': 'radius',
      };
    }
    
    return {'text': null};
  }
}

/// Widget for displaying detailed geographic information
class DetailedGeographicWidget extends StatelessWidget {
  final GeographicTargeting targeting;
  final bool showHierarchy;
  
  const DetailedGeographicWidget({
    super.key,
    required this.targeting,
    this.showHierarchy = true,
  });
  
  @override
  Widget build(BuildContext context) {
    final hierarchy = _buildHierarchy();
    
    if (hierarchy.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.location_on, size: 20, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Geographic Scope',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            if (showHierarchy) ...[
              // Hierarchical display
              ...hierarchy.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final isLast = index == hierarchy.length - 1;
                
                return Padding(
                  padding: EdgeInsets.only(
                    left: index * 16.0,
                    bottom: isLast ? 0 : 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item['icon'],
                        size: 16,
                        color: isLast ? Colors.blue : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item['text'],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isLast ? FontWeight.w600 : FontWeight.normal,
                          color: isLast ? Colors.blue : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ] else ...[
              // Simple list display
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: hierarchy.map((item) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item['icon'],
                        size: 12,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item['text'],
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ],
            
            // Radius information
            if (targeting.radiusKm != null && targeting.centerPoint != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.my_location, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      'Within ${targeting.radiusKm!.toInt()}km radius',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  List<Map<String, dynamic>> _buildHierarchy() {
    final hierarchy = <Map<String, dynamic>>[];
    
    if (targeting.state?.isNotEmpty == true) {
      hierarchy.add({
        'text': targeting.state!,
        'icon': Icons.map,
        'level': 'state',
      });
    }
    
    if (targeting.district?.isNotEmpty == true) {
      hierarchy.add({
        'text': targeting.district!,
        'icon': Icons.account_balance,
        'level': 'district',
      });
    }
    
    if (targeting.mandal?.isNotEmpty == true) {
      hierarchy.add({
        'text': targeting.mandal!,
        'icon': Icons.location_city,
        'level': 'mandal',
      });
    }
    
    if (targeting.village?.isNotEmpty == true) {
      hierarchy.add({
        'text': targeting.village!,
        'icon': Icons.home,
        'level': 'village',
      });
    }
    
    return hierarchy;
  }
}

/// Widget for geographic targeting selection
class GeographicTargetingSelector extends StatefulWidget {
  final GeographicTargeting? initialTargeting;
  final Function(GeographicTargeting?) onTargetingChanged;
  final bool allowRadius;
  
  const GeographicTargetingSelector({
    super.key,
    this.initialTargeting,
    required this.onTargetingChanged,
    this.allowRadius = false,
  });
  
  @override
  State<GeographicTargetingSelector> createState() => _GeographicTargetingSelectorState();
}

class _GeographicTargetingSelectorState extends State<GeographicTargetingSelector> {
  String? _selectedState;
  String? _selectedDistrict;
  String? _selectedMandal;
  String? _selectedVillage;
  double? _radiusKm;
  
  // Mock data - in real app, this would come from a service
  final Map<String, List<String>> _stateDistricts = {
    'Telangana': ['Hyderabad', 'Warangal', 'Nizamabad', 'Karimnagar'],
    'Andhra Pradesh': ['Visakhapatnam', 'Vijayawada', 'Guntur', 'Tirupati'],
    'Jharkhand': ['Ranchi', 'Jamshedpur', 'Dhanbad', 'Bokaro'],
  };
  
  final Map<String, List<String>> _districtMandals = {
    'Hyderabad': ['Secunderabad', 'Kukatpally', 'LB Nagar', 'Charminar'],
    'Warangal': ['Hanamkonda', 'Kazipet', 'Narsampet', 'Mahabubabad'],
    'Ranchi': ['Bundu', 'Tamar', 'Silli', 'Angara'],
  };
  
  final Map<String, List<String>> _mandalVillages = {
    'Secunderabad': ['Begumpet', 'Trimulgherry', 'Alwal', 'Bowenpally'],
    'Kukatpally': ['Miyapur', 'Bachupally', 'Pragathi Nagar', 'Nizampet'],
    'Bundu': ['Bundu Village', 'Sonahatu', 'Rahe', 'Lupungutu'],
  };
  
  @override
  void initState() {
    super.initState();
    if (widget.initialTargeting != null) {
      _selectedState = widget.initialTargeting!.state;
      _selectedDistrict = widget.initialTargeting!.district;
      _selectedMandal = widget.initialTargeting!.mandal;
      _selectedVillage = widget.initialTargeting!.village;
      _radiusKm = widget.initialTargeting!.radiusKm;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.location_on, size: 20),
                SizedBox(width: 8),
                Text(
                  'Geographic Targeting',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // State selection
            _buildDropdown(
              label: 'State',
              value: _selectedState,
              items: _stateDistricts.keys.toList(),
              onChanged: (value) {
                setState(() {
                  _selectedState = value;
                  _selectedDistrict = null;
                  _selectedMandal = null;
                  _selectedVillage = null;
                });
                _updateTargeting();
              },
            ),
            
            const SizedBox(height: 12),
            
            // District selection
            _buildDropdown(
              label: 'District',
              value: _selectedDistrict,
              items: _selectedState != null ? _stateDistricts[_selectedState!] ?? [] : [],
              onChanged: (value) {
                setState(() {
                  _selectedDistrict = value;
                  _selectedMandal = null;
                  _selectedVillage = null;
                });
                _updateTargeting();
              },
              enabled: _selectedState != null,
            ),
            
            const SizedBox(height: 12),
            
            // Mandal selection
            _buildDropdown(
              label: 'Mandal',
              value: _selectedMandal,
              items: _selectedDistrict != null ? _districtMandals[_selectedDistrict!] ?? [] : [],
              onChanged: (value) {
                setState(() {
                  _selectedMandal = value;
                  _selectedVillage = null;
                });
                _updateTargeting();
              },
              enabled: _selectedDistrict != null,
            ),
            
            const SizedBox(height: 12),
            
            // Village selection
            _buildDropdown(
              label: 'Village',
              value: _selectedVillage,
              items: _selectedMandal != null ? _mandalVillages[_selectedMandal!] ?? [] : [],
              onChanged: (value) {
                setState(() {
                  _selectedVillage = value;
                });
                _updateTargeting();
              },
              enabled: _selectedMandal != null,
            ),
            
            // Radius selection
            if (widget.allowRadius) ...[
              const SizedBox(height: 16),
              const Text(
                'Or specify radius:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _radiusKm ?? 5.0,
                      min: 1.0,
                      max: 100.0,
                      divisions: 99,
                      label: '${(_radiusKm ?? 5.0).toInt()} km',
                      onChanged: (value) {
                        setState(() {
                          _radiusKm = value;
                        });
                        _updateTargeting();
                      },
                    ),
                  ),
                  Text('${(_radiusKm ?? 5.0).toInt()} km'),
                ],
              ),
            ],
            
            // Clear button
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _clearSelection,
              icon: const Icon(Icons.clear),
              label: const Text('Clear Selection'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    bool enabled = true,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        enabled: enabled,
      ),
      items: items.map((item) => DropdownMenuItem(
        value: item,
        child: Text(item),
      )).toList(),
      onChanged: enabled ? onChanged : null,
    );
  }
  
  void _updateTargeting() {
    final targeting = GeographicTargeting(
      state: _selectedState,
      district: _selectedDistrict,
      mandal: _selectedMandal,
      village: _selectedVillage,
      radiusKm: _radiusKm,
    );
    
    widget.onTargetingChanged(targeting);
  }
  
  void _clearSelection() {
    setState(() {
      _selectedState = null;
      _selectedDistrict = null;
      _selectedMandal = null;
      _selectedVillage = null;
      _radiusKm = null;
    });
    widget.onTargetingChanged(null);
  }
}

