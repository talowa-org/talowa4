// Enhanced Message Input Widget for TALOWA Messaging
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../models/messaging/message_model.dart';

class MessageInputWidget extends StatefulWidget {
  final Function(String content, {MessageType? messageType, List<String>? mediaUrls}) onSendMessage;
  final VoidCallback? onStartTyping;
  final VoidCallback? onStopTyping;
  final MessageModel? replyToMessage;
  final VoidCallback? onCancelReply;
  final bool isEnabled;

  const MessageInputWidget({
    super.key,
    required this.onSendMessage,
    this.onStartTyping,
    this.onStopTyping,
    this.replyToMessage,
    this.onCancelReply,
    this.isEnabled = true,
  });

  @override
  State<MessageInputWidget> createState() => _MessageInputWidgetState();
}

class _MessageInputWidgetState extends State<MessageInputWidget>
    with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  bool _isTyping = false;
  bool _showEmojiPicker = false;
  bool _isSending = false;
  
  late AnimationController _emojiAnimationController;
  late Animation<double> _emojiAnimation;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    
    _emojiAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _emojiAnimation = CurvedAnimation(
      parent: _emojiAnimationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _emojiAnimationController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final isCurrentlyTyping = _textController.text.trim().isNotEmpty;
    
    if (isCurrentlyTyping != _isTyping) {
      setState(() {
        _isTyping = isCurrentlyTyping;
      });
      
      if (isCurrentlyTyping) {
        widget.onStartTyping?.call();
      } else {
        widget.onStopTyping?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Reply indicator
          if (widget.replyToMessage != null)
            _buildReplyIndicator(),
          
          // Main input area
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Attachment button
                IconButton(
                  onPressed: widget.isEnabled ? _showAttachmentOptions : null,
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppTheme.talowaGreen,
                  iconSize: 28,
                ),
                
                // Text input
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Emoji button
                        IconButton(
                          onPressed: widget.isEnabled ? _toggleEmojiPicker : null,
                          icon: Icon(
                            _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions,
                            color: _showEmojiPicker 
                                ? AppTheme.talowaGreen 
                                : Colors.grey[600],
                          ),
                        ),
                        
                        // Text field
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            focusNode: _focusNode,
                            enabled: widget.isEnabled,
                            decoration: const InputDecoration(
                              hintText: 'Type a message...',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 8,
                              ),
                            ),
                            maxLines: null,
                            textCapitalization: TextCapitalization.sentences,
                            onSubmitted: (_) => _sendMessage(),
                            onTap: () {
                              if (_showEmojiPicker) {
                                _toggleEmojiPicker();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Send button
                FloatingActionButton(
                  onPressed: widget.isEnabled && !_isSending ? _sendMessage : null,
                  backgroundColor: AppTheme.talowaGreen,
                  foregroundColor: Colors.white,
                  mini: true,
                  heroTag: "message_send_button",
                  child: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(_isTyping ? Icons.send : Icons.mic),
                ),
              ],
            ),
          ),
          
          // Emoji picker
          AnimatedBuilder(
            animation: _emojiAnimation,
            builder: (context, child) {
              return SizeTransition(
                sizeFactor: _emojiAnimation,
                child: _showEmojiPicker ? _buildEmojiPicker() : const SizedBox.shrink(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReplyIndicator() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.talowaGreen.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: const Border(
            left: BorderSide(
              color: AppTheme.talowaGreen,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.reply,
              size: 16,
              color: AppTheme.talowaGreen,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Replying to ${widget.replyToMessage!.senderName}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.talowaGreen,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.replyToMessage!.content,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: widget.onCancelReply,
              icon: const Icon(Icons.close, size: 18),
              color: Colors.grey[600],
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmojiPicker() {
    const emojis = [
      '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣',
      '😊', '😇', '🙂', '🙃', '😉', '😌', '😍', '🥰',
      '😘', '😗', '😙', '😚', '😋', '😛', '😝', '😜',
      '🤪', '🤨', '🧐', '🤓', '😎', '🤩', '🥳', '😏',
      '😒', '😞', '😔', '😟', '😕', '🙁', '☹️', '😣',
      '😖', '😫', '😩', '🥺', '😢', '😭', '😤', '😠',
      '😡', '🤬', '🤯', '😳', '🥵', '🥶', '😱', '😨',
      '😰', '😥', '😓', '🤗', '🤔', '🤭', '🤫', '🤥',
      '😶', '😐', '😑', '😬', '🙄', '😯', '😦', '😧',
      '😮', '😲', '🥱', '😴', '🤤', '😪', '😵', '🤐',
      '🥴', '🤢', '🤮', '🤧', '😷', '🤒', '🤕', '🤑',
      '🤠', '😈', '👿', '👹', '👺', '🤡', '💩', '👻',
      '💀', '☠️', '👽', '👾', '🤖', '🎃', '😺', '😸',
      '😹', '😻', '😼', '😽', '🙀', '😿', '😾', '👋',
      '🤚', '🖐️', '✋', '🖖', '👌', '🤏', '✌️', '🤞',
      '🤟', '🤘', '🤙', '👈', '👉', '👆', '🖕', '👇',
      '☝️', '👍', '👎', '👊', '✊', '🤛', '🤜', '👏',
      '🙌', '👐', '🤲', '🤝', '🙏', '✍️', '💅', '🤳',
    ];

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          childAspectRatio: 1,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: emojis.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _insertEmoji(emojis[index]),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[100],
              ),
              child: Center(
                child: Text(
                  emojis[index],
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
    });

    if (_showEmojiPicker) {
      _focusNode.unfocus();
      _emojiAnimationController.forward();
    } else {
      _emojiAnimationController.reverse();
      _focusNode.requestFocus();
    }
  }

  void _insertEmoji(String emoji) {
    final text = _textController.text;
    final selection = _textController.selection;
    
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      emoji,
    );
    
    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + emoji.length,
      ),
    );
  }

  void _sendMessage() async {
    final content = _textController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      await widget.onSendMessage(content);
      _textController.clear();
      
      if (_showEmojiPicker) {
        _toggleEmojiPicker();
      }
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => AttachmentOptionsSheet(
        onImageSelected: _handleImageAttachment,
        onDocumentSelected: _handleDocumentAttachment,
        onLocationSelected: _handleLocationShare,
      ),
    );
  }

  void _handleImageAttachment() async {
    Navigator.pop(context);
    
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      // TODO: Upload image and get URL
      // For now, just send a placeholder message
      widget.onSendMessage(
        'Image shared',
        messageType: MessageType.image,
        mediaUrls: [image.path], // This would be the uploaded URL
      );
    }
  }

  void _handleDocumentAttachment() async {
    Navigator.pop(context);
    
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'jpg', 'png'],
    );

    if (result != null) {
      final file = result.files.first;
      // TODO: Upload document and get URL
      widget.onSendMessage(
        'Document: ${file.name}',
        messageType: MessageType.document,
        mediaUrls: [file.path!], // This would be the uploaded URL
      );
    }
  }

  void _handleLocationShare() {
    Navigator.pop(context);
    
    // TODO: Get current location and share
    widget.onSendMessage(
      'Location shared',
      messageType: MessageType.location,
    );
  }
}

// Attachment Options Bottom Sheet
class AttachmentOptionsSheet extends StatelessWidget {
  final VoidCallback onImageSelected;
  final VoidCallback onDocumentSelected;
  final VoidCallback onLocationSelected;

  const AttachmentOptionsSheet({
    super.key,
    required this.onImageSelected,
    required this.onDocumentSelected,
    required this.onLocationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          
          const Text(
            'Share Content',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          
          // Options grid
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildAttachmentOption(
                icon: Icons.photo_library,
                label: 'Photos',
                color: Colors.blue,
                onTap: onImageSelected,
              ),
              _buildAttachmentOption(
                icon: Icons.camera_alt,
                label: 'Camera',
                color: Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  _takePicture();
                },
              ),
              _buildAttachmentOption(
                icon: Icons.insert_drive_file,
                label: 'Document',
                color: Colors.orange,
                onTap: onDocumentSelected,
              ),
              _buildAttachmentOption(
                icon: Icons.location_on,
                label: 'Location',
                color: Colors.red,
                onTap: onLocationSelected,
              ),
              _buildAttachmentOption(
                icon: Icons.mic,
                label: 'Voice',
                color: Colors.purple,
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement voice recording
                },
              ),
              _buildAttachmentOption(
                icon: Icons.contact_phone,
                label: 'Contact',
                color: Colors.teal,
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement contact sharing
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              size: 30,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _takePicture() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      // TODO: Handle camera image
    }
  }
}

