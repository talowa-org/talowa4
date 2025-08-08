// Auto Save Mixin - Automatic draft saving functionality
// Part of Task 11: Add post editing and management

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/social_feed/post_management_service.dart';
import '../models/social_feed/post_model.dart';

/// Mixin for automatic draft saving functionality
mixin AutoSaveMixin<T extends StatefulWidget> on State<T> {
  Timer? _autoSaveTimer;
  String? _currentDraftId;
  bool _hasUnsavedChanges = false;
  
  // Auto-save configuration
  Duration get autoSaveInterval => const Duration(seconds: 30);
  bool get enableAutoSave => true;
  
  // Abstract methods to be implemented by the using class
  String get authorId;
  String? get currentTitle;
  String? get currentContent;
  List<String>? get currentHashtags;
  PostCategory? get currentCategory;
  
  @override
  void initState() {
    super.initState();
    if (enableAutoSave) {
      _startAutoSave();
    }
  }
  
  @override
  void dispose() {
    _stopAutoSave();
    super.dispose();
  }
  
  /// Start the auto-save timer
  void _startAutoSave() {
    _autoSaveTimer = Timer.periodic(autoSaveInterval, (_) {
      if (_hasUnsavedChanges) {
        _performAutoSave();
      }
    });
  }
  
  /// Stop the auto-save timer
  void _stopAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
  }
  
  /// Mark that there are unsaved changes
  void markUnsavedChanges() {
    _hasUnsavedChanges = true;
  }
  
  /// Mark that changes have been saved
  void markChangesSaved() {
    _hasUnsavedChanges = false;
  }
  
  /// Perform auto-save
  Future<void> _performAutoSave() async {
    try {
      _currentDraftId = await PostManagementService.autoSaveDraft(
        authorId: authorId,
        draftId: _currentDraftId,
        title: currentTitle,
        content: currentContent,
        hashtags: currentHashtags,
        category: currentCategory,
      );
      
      _hasUnsavedChanges = false;
      _onAutoSaveSuccess();
    } catch (e) {
      _onAutoSaveError(e);
    }
  }
  
  /// Manual save draft
  Future<String?> saveDraft() async {
    try {
      _currentDraftId = await PostManagementService.saveDraft(
        draftId: _currentDraftId,
        authorId: authorId,
        title: currentTitle,
        content: currentContent,
        hashtags: currentHashtags,
        category: currentCategory,
      );
      
      _hasUnsavedChanges = false;
      _onSaveSuccess();
      return _currentDraftId;
    } catch (e) {
      _onSaveError(e);
      return null;
    }
  }
  
  /// Load draft by ID
  Future<Map<String, dynamic>?> loadDraft(String draftId) async {
    try {
      final drafts = await PostManagementService.getUserDrafts(authorId);
      final draft = drafts.firstWhere(
        (d) => d['id'] == draftId,
        orElse: () => {},
      );
      
      if (draft.isNotEmpty) {
        _currentDraftId = draftId;
        return draft;
      }
      return null;
    } catch (e) {
      _onLoadError(e);
      return null;
    }
  }
  
  /// Delete current draft
  Future<bool> deleteDraft() async {
    if (_currentDraftId == null) return false;
    
    try {
      await PostManagementService.deleteDraft(_currentDraftId!);
      _currentDraftId = null;
      _hasUnsavedChanges = false;
      _onDeleteSuccess();
      return true;
    } catch (e) {
      _onDeleteError(e);
      return false;
    }
  }
  
  /// Check if there are unsaved changes
  bool get hasUnsavedChanges => _hasUnsavedChanges;
  
  /// Get current draft ID
  String? get currentDraftId => _currentDraftId;
  
  /// Set draft ID (useful when loading existing draft)
  set currentDraftId(String? draftId) {
    _currentDraftId = draftId;
  }
  
  // Callback methods that can be overridden
  
  void _onAutoSaveSuccess() {
    // Override in implementing class if needed
    debugPrint('Auto-save successful');
  }
  
  void _onAutoSaveError(dynamic error) {
    // Override in implementing class if needed
    debugPrint('Auto-save failed: $error');
  }
  
  void _onSaveSuccess() {
    // Override in implementing class if needed
    debugPrint('Manual save successful');
  }
  
  void _onSaveError(dynamic error) {
    // Override in implementing class if needed
    debugPrint('Manual save failed: $error');
  }
  
  void _onLoadError(dynamic error) {
    // Override in implementing class if needed
    debugPrint('Load draft failed: $error');
  }
  
  void _onDeleteSuccess() {
    // Override in implementing class if needed
    debugPrint('Delete draft successful');
  }
  
  void _onDeleteError(dynamic error) {
    // Override in implementing class if needed
    debugPrint('Delete draft failed: $error');
  }
}

/// Enhanced auto-save mixin with additional features
mixin EnhancedAutoSaveMixin<T extends StatefulWidget> on AutoSaveMixin<T> {
  // Additional configuration
  int get maxDrafts => 10;
  Duration get draftRetentionPeriod => const Duration(days: 30);
  
  /// Save draft with metadata
  Future<String?> saveDraftWithMetadata({
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Add metadata to the draft
      final draftData = {
        'authorId': authorId,
        'title': currentTitle,
        'content': currentContent,
        'hashtags': currentHashtags,
        'category': currentCategory?.toString().split('.').last,
        'metadata': metadata ?? {},
        'version': DateTime.now().millisecondsSinceEpoch,
      };
      
      // Use the base save functionality
      return await saveDraft();
    } catch (e) {
      _onSaveError(e);
      return null;
    }
  }
  
  /// Get all drafts with metadata
  Future<List<Map<String, dynamic>>> getAllDraftsWithMetadata() async {
    try {
      final drafts = await PostManagementService.getUserDrafts(authorId);
      
      // Sort by last updated
      drafts.sort((a, b) {
        final aTime = (a['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bTime = (b['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        return bTime.compareTo(aTime);
      });
      
      return drafts;
    } catch (e) {
      _onLoadError(e);
      return [];
    }
  }
  
  /// Clean up old drafts
  Future<void> cleanupOldDrafts() async {
    try {
      final drafts = await getAllDraftsWithMetadata();
      final cutoffDate = DateTime.now().subtract(draftRetentionPeriod);
      
      // Delete drafts older than retention period
      for (final draft in drafts) {
        final updatedAt = (draft['updatedAt'] as Timestamp?)?.toDate();
        if (updatedAt != null && updatedAt.isBefore(cutoffDate)) {
          await PostManagementService.deleteDraft(draft['id']);
        }
      }
      
      // Keep only the most recent drafts if we exceed the limit
      if (drafts.length > maxDrafts) {
        final excessDrafts = drafts.skip(maxDrafts);
        for (final draft in excessDrafts) {
          await PostManagementService.deleteDraft(draft['id']);
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up old drafts: $e');
    }
  }
  
  /// Create a backup of current content
  Future<String?> createBackup({String? backupName}) async {
    try {
      final backupData = {
        'type': 'backup',
        'name': backupName ?? 'Backup ${DateTime.now().toIso8601String()}',
        'createdAt': DateTime.now().toIso8601String(),
      };
      
      return await saveDraftWithMetadata(metadata: backupData);
    } catch (e) {
      debugPrint('Error creating backup: $e');
      return null;
    }
  }
  
  /// Restore from backup
  Future<Map<String, dynamic>?> restoreFromBackup(String backupId) async {
    try {
      return await loadDraft(backupId);
    } catch (e) {
      debugPrint('Error restoring from backup: $e');
      return null;
    }
  }
}

/// Auto-save status widget
class AutoSaveStatusWidget extends StatefulWidget {
  final bool hasUnsavedChanges;
  final DateTime? lastSaveTime;
  final bool isAutoSaveEnabled;
  final VoidCallback? onManualSave;
  
  const AutoSaveStatusWidget({
    Key? key,
    required this.hasUnsavedChanges,
    this.lastSaveTime,
    this.isAutoSaveEnabled = true,
    this.onManualSave,
  }) : super(key: key);
  
  @override
  State<AutoSaveStatusWidget> createState() => _AutoSaveStatusWidgetState();
}

class _AutoSaveStatusWidgetState extends State<AutoSaveStatusWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getStatusColor().withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(),
            size: 14,
            color: _getStatusColor(),
          ),
          const SizedBox(width: 6),
          Text(
            _getStatusText(),
            style: TextStyle(
              fontSize: 12,
              color: _getStatusColor(),
              fontWeight: FontWeight.w500,
            ),
          ),
          if (widget.onManualSave != null && widget.hasUnsavedChanges) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: widget.onManualSave,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getStatusColor(),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Color _getStatusColor() {
    if (widget.hasUnsavedChanges) {
      return Colors.orange;
    } else if (widget.lastSaveTime != null) {
      return Colors.green;
    } else {
      return Colors.grey;
    }
  }
  
  IconData _getStatusIcon() {
    if (widget.hasUnsavedChanges) {
      return Icons.edit;
    } else if (widget.lastSaveTime != null) {
      return Icons.check_circle;
    } else {
      return Icons.save;
    }
  }
  
  String _getStatusText() {
    if (widget.hasUnsavedChanges) {
      return widget.isAutoSaveEnabled ? 'Auto-saving...' : 'Unsaved changes';
    } else if (widget.lastSaveTime != null) {
      final timeDiff = DateTime.now().difference(widget.lastSaveTime!);
      if (timeDiff.inMinutes < 1) {
        return 'Saved just now';
      } else if (timeDiff.inMinutes < 60) {
        return 'Saved ${timeDiff.inMinutes}m ago';
      } else {
        return 'Saved ${timeDiff.inHours}h ago';
      }
    } else {
      return 'Not saved';
    }
  }
}