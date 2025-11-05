// Mock Feed Service - Provides fast loading sample data
import 'package:flutter/foundation.dart';
import '../../models/social_feed/post_model.dart';

class MockFeedService {
  static final MockFeedService _instance = MockFeedService._internal();
  factory MockFeedService() => _instance;
  MockFeedService._internal();

  /// Get mock feed posts for fast loading
  Future<List<PostModel>> getMockFeedPosts({int limit = 8}) async {
    // Simulate fast loading
    await Future.delayed(const Duration(milliseconds: 100));
    
    final mockPosts = <PostModel>[];
    
    for (int i = 0; i < limit; i++) {
      mockPosts.add(PostModel(
        id: 'mock_post_$i',
        authorId: 'mock_author_$i',
        authorName: 'Community Member ${i + 1}',
        authorRole: 'member',
        title: i % 3 == 0 ? 'Important Update ${i + 1}' : null,
        content: _getMockContent(i),
        hashtags: _getMockHashtags(i),
        category: _getMockCategory(i),
        location: 'Telangana',
        createdAt: DateTime.now().subtract(Duration(hours: i)),
        likesCount: (i * 3) % 15,
        commentsCount: (i * 2) % 8,
        sharesCount: i % 5,
        isLikedByCurrentUser: i % 4 == 0,
      ));
    }
    
    debugPrint('✅ Mock feed loaded ${mockPosts.length} posts in 100ms');
    return mockPosts;
  }

  String _getMockContent(int index) {
    final contents = [
      'Great news! Our land rights campaign is making progress. The local authorities have agreed to meet with our representatives next week.',
      'Agriculture update: The new farming techniques shared in our workshop are showing excellent results. Crop yields have increased by 20%!',
      'Community meeting scheduled for this Saturday at 10 AM. We will discuss the upcoming legal proceedings and next steps.',
      'Success story: Thanks to our collective efforts, the disputed land in Sector 5 has been officially recognized under our community ownership.',
      'Legal update: The court hearing has been postponed to next month. Our legal team is preparing additional documentation.',
      'Educational workshop on sustainable farming practices will be held next Tuesday. All community members are welcome to attend.',
      'Emergency alert: Please be aware of the new government regulations regarding land documentation. Check your papers.',
      'Celebrating our community! Today marks the 2nd anniversary of our successful land rights movement. Thank you all for your support.',
    ];
    
    return contents[index % contents.length];
  }

  List<String> _getMockHashtags(int index) {
    final hashtagSets = [
      ['landrights', 'community'],
      ['agriculture', 'farming'],
      ['meeting', 'community'],
      ['success', 'victory'],
      ['legal', 'update'],
      ['education', 'workshop'],
      ['emergency', 'alert'],
      ['celebration', 'anniversary'],
    ];
    
    return hashtagSets[index % hashtagSets.length];
  }

  PostCategory _getMockCategory(int index) {
    final categories = [
      PostCategory.announcement,
      PostCategory.agriculture,
      PostCategory.communityNews,
      PostCategory.successStory,
      PostCategory.legalUpdate,
      PostCategory.education,
      PostCategory.emergency,
      PostCategory.generalDiscussion,
    ];
    
    return categories[index % categories.length];
  }
}