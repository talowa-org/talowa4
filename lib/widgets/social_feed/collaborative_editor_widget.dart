// Collaborative Editor Widget for TALOWA
// Real-time collaborative content editing interface

import 'package:flutter/material.dart';
import '../../models/social_feed/collaborative_models.dart';
import '../../services/social_feed/collaborative_content_service.dart';
import '../../services/social_feed/collaboration_notification_service.dart';
import '../../services/auth_service.dart';

class CollaborativeEditorWidget extends StatefulWidget {
  final String sessionId;
  final VoidCallback? onPublish;

  const CollaborativeEditorWidget({
    Key? key,
    required this.sessionId,
    this.onPublish,
  }) : super(key: key);

  @override
  State<CollaborativeEditorWidget> createState() =>
      _CollaborativeEditorWidgetState();
}

class _CollaborativeEditorWidgetState
    extends State<CollaborativeEditorWidget> {
  final _contentController = TextEditingController();
  final _titleController = TextEditingController();
  final _collaborativeService = CollaborativeContentService();
  final _notificationService = CollaborationNotificationService();

  CollaborativeSession? _session;
  bool _isLoading = true;
  int _cursorPosition = 0;

  @override
  void initState() {
    super.initState();
    _setupRealtimeSync();
  }

  void _setupRealtimeSync() {
    _collaborativeService.getEditStream(widget.sessionId).listen(
      (session) {
        setState(() {
          _session = session;
          _isLoading = false;

          // Update content if changed by others
          if (_contentController.text != session.currentVersion.content) {
            final oldCursor = _cursorPosition;
            _contentController.text = session.currentVersion.content;
            _contentController.selection = TextSelection.fromPosition(
              TextPosition(offset: oldCursor),
            );
          }

          if (_titleController.text != (session.currentVersion.title ?? '')) {
            _titleController.text = session.currentVersion.title ?? '';
          }
        });
      },
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync error: $error')),
        );
      },
    );
  }

  Future<void> _handleTextEdit(String newText) async {
    if (_session == null) return;

    final currentUser = AuthService.currentUser;
    if (currentUser == null) return;

    final oldText = _session!.currentVersion.content;
    if (oldText == newText) return;

    // Determine edit type and position
    EditType editType;
    int position;
    String? oldContent;
    String? newContent;

    if (newText.length > oldText.length) {
      // Insert
      editType = EditType.textInsert;
      position = _findDifferencePosition(oldText, newText);
      newContent = newText.substring(position, position + (newText.length - oldText.length));
    } else if (newText.length < oldText.length) {
      // Delete
      editType = EditType.textDelete;
      position = _findDifferencePosition(oldText, newText);
      oldContent = oldText.substring(position, position + (oldText.length - newText.length));
    } else {
      // Edit
      editType = EditType.textEdit;
      position = _findDifferencePosition(oldText, newText);
      oldContent = oldText[position];
      newContent = newText[position];
    }

    final edit = ContentEdit(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      type: editType,
      position: position,
      oldText: oldContent,
      newText: newContent,
      userId: currentUser.uid,
      timestamp: DateTime.now(),
    );

    try {
      await _collaborativeService.applyContentEdit(
        sessionId: widget.sessionId,
        userId: currentUser.uid,
        edit: edit,
      );

      // Notify other collaborators
      final collaboratorIds = _session!.collaborators
          .map((c) => c.userId)
          .where((id) => id != currentUser.uid)
          .toList();

      await _notificationService.sendEditNotification(
        sessionId: widget.sessionId,
        editorId: currentUser.uid,
        collaboratorIds: collaboratorIds,
        editType: editType.name,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to apply edit: $e')),
      );
    }
  }

  int _findDifferencePosition(String oldText, String newText) {
    final minLength = oldText.length < newText.length
        ? oldText.length
        : newText.length;

    for (int i = 0; i < minLength; i++) {
      if (oldText[i] != newText[i]) {
        return i;
      }
    }
    return minLength;
  }

  Future<void> _publishPost() async {
    try {
      final postId = await _collaborativeService.publishCollaborativePost(
        widget.sessionId,
      );

      // Notify collaborators
      if (_session != null) {
        final currentUser = AuthService.currentUser;
        if (currentUser != null) {
          await _notificationService.sendPublishNotification(
            sessionId: widget.sessionId,
            publisherId: currentUser.uid,
            collaboratorIds: _session!.collaborators.map((c) => c.userId).toList(),
            postId: postId,
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post published successfully!')),
        );
        widget.onPublish?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to publish: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_session == null) {
      return const Center(child: Text('Session not found'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collaborative Editor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _showVersionHistory(),
          ),
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () => _showCollaborators(),
          ),
          IconButton(
            icon: const Icon(Icons.publish),
            onPressed: _publishPost,
          ),
        ],
      ),
      body: Column(
        children: [
          // Active collaborators indicator
          _buildActiveCollaboratorsBar(),

          // Content editor
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      hintText: 'Post title (optional)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      // Handle title changes
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TextField(
                      controller: _contentController,
                      decoration: const InputDecoration(
                        hintText: 'Start writing...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: null,
                      expands: true,
                      onChanged: _handleTextEdit,
                      onTap: () {
                        setState(() {
                          _cursorPosition = _contentController.selection.baseOffset;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Media gallery
          if (_session!.currentVersion.mediaUrls.isNotEmpty)
            _buildMediaGallery(),
        ],
      ),
    );
  }

  Widget _buildActiveCollaboratorsBar() {
    final activeCollaborators =
        _session!.collaborators.where((c) => c.isActive).toList();

    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.blue.shade50,
      child: Row(
        children: [
          const Icon(Icons.people, size: 20),
          const SizedBox(width: 8),
          Text('${activeCollaborators.length} active'),
          const Spacer(),
          ...activeCollaborators.take(5).map((c) => Padding(
                padding: const EdgeInsets.only(left: 4),
                child: CircleAvatar(
                  radius: 12,
                  backgroundImage: c.avatarUrl != null
                      ? NetworkImage(c.avatarUrl!)
                      : null,
                  child: c.avatarUrl == null
                      ? Text(c.name[0].toUpperCase())
                      : null,
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildMediaGallery() {
    return Container(
      height: 100,
      padding: const EdgeInsets.all(8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _session!.currentVersion.mediaUrls.length,
        itemBuilder: (context, index) {
          final url = _session!.currentVersion.mediaUrls[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              ),
            ),
          );
        },
      ),
    );
  }

  void _showVersionHistory() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Version History',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _session!.versionHistory.length,
                itemBuilder: (context, index) {
                  final version = _session!.versionHistory[index];
                  return ListTile(
                    leading: CircleAvatar(child: Text(version.id)),
                    title: Text('Edited by ${version.editedBy}'),
                    subtitle: Text(version.editedAt.toString()),
                    trailing: IconButton(
                      icon: const Icon(Icons.restore),
                      onPressed: () async {
                        await _collaborativeService.revertToVersion(
                          widget.sessionId,
                          version.id,
                        );
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCollaborators() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Collaborators',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _session!.collaborators.length,
                itemBuilder: (context, index) {
                  final collaborator = _session!.collaborators[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: collaborator.avatarUrl != null
                          ? NetworkImage(collaborator.avatarUrl!)
                          : null,
                      child: collaborator.avatarUrl == null
                          ? Text(collaborator.name[0].toUpperCase())
                          : null,
                    ),
                    title: Text(collaborator.name),
                    subtitle: Text(collaborator.role.name),
                    trailing: collaborator.isActive
                        ? const Icon(Icons.circle, color: Colors.green, size: 12)
                        : const Icon(Icons.circle, color: Colors.grey, size: 12),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    _titleController.dispose();
    super.dispose();
  }
}
