// Message Search Results Widget for TALOWA
// Requirements: 4.2, 4.3, 4.4, 4.5
// Task: Display message search results with highlighting and navigation

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/messaging/message_model.dart';
import '../../../services/messaging/messaging_search_service.dart';

/// Widget to display message search results
class MessageSearchResultsWidget extends StatelessWidget {
  final MessageSearchResult? result;
  final String searchQuery;
  final Function(MessageModel)? onMessageSelected;

  const MessageSearchResultsWidget({
    super.key,
    required this.result,
    required this.searchQuery,
    this.onMessageSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (result == null) {
      return const SizedBox.shrink();
    }

    if (result!.error != null) {
      return _buildErrorState(context);
    }

    if (result!.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      children: [
        _buildResultsHeader(context),
        Expanded(
          child: _buildResultsList(context),
        ),
      ],
    );
  }

  Widget _buildResultsHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.message,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            '${result!.totalResults} message${result!.totalResults == 1 ? '' : 's'} found',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (result!.appliedFilters != null) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.filter_list,
              size: 14,
              color: Theme.of(context).primaryColor,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultsList(BuildContext context) {
    // Group messages by conversation for better organization
    final groupedMessages = _groupMessagesByConversation(result!.messages);

    return ListView.builder(
      itemCount: groupedMessages.length + (result!.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == groupedMessages.length) {
          return _buildLoadMoreButton(context);
        }

        final conversationGroup = groupedMessages[index];
        return _buildConversationGroup(context, conversationGroup);
      },
    );
  }

  Widget _buildConversationGroup(BuildContext context, ConversationGroup group) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Conversation header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _getConversationIcon(group.conversationId),
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    group.conversationName ?? 'Unknown Conversation',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${group.messages.length} match${group.messages.length == 1 ? '' : 'es'}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          
          // Messages in this conversation
          ...group.messages.map((message) => _buildMessageTile(context, message)),
        ],
      ),
    );
  }

  Widget _buildMessageTile(BuildContext context, MessageModel message) {
    return InkWell(
      onTap: () => onMessageSelected?.call(message),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.3),
              width: 0.5,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Message header
            Row(
              children: [
                _buildSenderAvatar(message.senderName),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHighlightedText(
                        context,
                        message.senderName,
                        searchQuery,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatMessageTime(message.sentAt),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildMessageTypeIcon(context, message.messageType),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Message content
            _buildMessageContent(context, message),
            
            // Message status indicators
            if (message.isEdited || message.isDeleted)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    if (message.isEdited)
                      Icon(
                        Icons.edit,
                        size: 12,
                        color: Colors.grey[500],
                      ),
                    if (message.isDeleted)
                      Icon(
                        Icons.delete,
                        size: 12,
                        color: Colors.red[400],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSenderAvatar(String senderName) {
    return CircleAvatar(
      radius: 16,
      child: Text(
        senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildMessageTypeIcon(BuildContext context, MessageType messageType) {
    IconData icon;
    Color color = Theme.of(context).colorScheme.onSurfaceVariant;

    switch (messageType) {
      case MessageType.image:
        icon = Icons.image;
        color = Colors.blue;
        break;
      case MessageType.video:
        icon = Icons.videocam;
        color = Colors.red;
        break;
      case MessageType.audio:
        icon = Icons.mic;
        color = Colors.green;
        break;
      case MessageType.document:
        icon = Icons.description;
        color = Colors.orange;
        break;
      case MessageType.location:
        icon = Icons.location_on;
        color = Colors.purple;
        break;
      case MessageType.emergency:
        icon = Icons.warning;
        color = Colors.red;
        break;
      default:
        icon = Icons.message;
    }

    return Icon(icon, size: 16, color: color);
  }

  Widget _buildMessageContent(BuildContext context, MessageModel message) {
    if (message.messageType == MessageType.text) {
      return _buildHighlightedText(
        context,
        message.content,
        searchQuery,
        style: Theme.of(context).textTheme.bodyMedium,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      );
    } else {
      return Row(
        children: [
          _buildMessageTypeIcon(context, message.messageType),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _getMessageTypeDescription(message.messageType),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildHighlightedText(
    BuildContext context,
    String text,
    String query, {
    TextStyle? style,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    if (query.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final searchService = MessagingSearchService();
    final highlights = searchService.getSearchHighlights(text, query);

    if (highlights.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final spans = <TextSpan>[];
    int lastIndex = 0;

    for (final highlight in highlights) {
      // Add text before highlight
      if (highlight.startIndex > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, highlight.startIndex),
          style: style,
        ));
      }

      // Add highlighted text
      spans.add(TextSpan(
        text: highlight.matchedText,
        style: style?.copyWith(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.3),
          fontWeight: FontWeight.bold,
        ),
      ));

      lastIndex = highlight.endIndex;
    }

    // Add remaining text
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: style,
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }

  Widget _buildLoadMoreButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: () {
          // TODO: Implement load more functionality
        },
        child: const Text('Load More Messages'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final searchService = MessagingSearchService();
    final emptyMessage = searchService.getEmptyStateMessage(searchQuery, isUserSearch: false);
    final suggestions = searchService.getEmptyStateSuggestions();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ...suggestions.map((suggestion) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 16,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      suggestion,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Search Error',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.red[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              result!.error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement retry functionality
              },
              child: const Text('Retry Search'),
            ),
          ],
        ),
      ),
    );
  }

  List<ConversationGroup> _groupMessagesByConversation(List<MessageModel> messages) {
    final groups = <String, ConversationGroup>{};

    for (final message in messages) {
      if (!groups.containsKey(message.conversationId)) {
        groups[message.conversationId] = ConversationGroup(
          conversationId: message.conversationId,
          conversationName: _getConversationName(message.conversationId),
          messages: [],
        );
      }
      groups[message.conversationId]!.messages.add(message);
    }

    return groups.values.toList()
      ..sort((a, b) => b.messages.first.sentAt.compareTo(a.messages.first.sentAt));
  }

  String _formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (difference.inDays == 1) {
      return 'Yesterday ${DateFormat('HH:mm').format(dateTime)}';
    } else if (difference.inDays < 7) {
      return DateFormat('EEE HH:mm').format(dateTime);
    } else {
      return DateFormat('MMM dd, HH:mm').format(dateTime);
    }
  }

  String _getMessageTypeDescription(MessageType messageType) {
    switch (messageType) {
      case MessageType.image:
        return 'Image';
      case MessageType.video:
        return 'Video';
      case MessageType.audio:
        return 'Voice message';
      case MessageType.document:
        return 'Document';
      case MessageType.location:
        return 'Location';
      case MessageType.emergency:
        return 'Emergency message';
      default:
        return 'Message';
    }
  }

  IconData _getConversationIcon(String conversationId) {
    // In a real implementation, this would determine the conversation type
    // For now, return a generic group icon
    return Icons.group;
  }

  String? _getConversationName(String conversationId) {
    // In a real implementation, this would fetch the conversation name
    // For now, return a placeholder
    return 'Conversation';
  }
}

/// Helper class to group messages by conversation
class ConversationGroup {
  final String conversationId;
  final String? conversationName;
  final List<MessageModel> messages;

  ConversationGroup({
    required this.conversationId,
    this.conversationName,
    required this.messages,
  });
}