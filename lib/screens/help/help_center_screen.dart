// TALOWA Help Center Screen
// Comprehensive help documentation with search and categories
// Reference: in-app-communication/requirements.md - Requirements 2.2, 3.1, 9.1

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/help/help_category.dart';
import '../../models/help/help_article.dart';
import '../../models/help/help_search_result.dart';
import '../../services/help_documentation_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/help/help_category_card.dart';
import '../../widgets/help/help_search_bar.dart';
import '../../widgets/help/help_search_results.dart';
import '../../widgets/help/faq_section.dart';
import '../../widgets/common/loading_widget.dart';
import 'help_article_screen.dart';
import '../onboarding/onboarding_screen.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final HelpDocumentationService _helpService = HelpDocumentationService();

  List<HelpCategory> _categories = [];
  List<HelpArticle> _faqArticles = [];
  List<HelpSearchResult> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadHelpContent();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHelpContent() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _helpService.initialize();
      final categories = await _helpService.getHelpCategories();
      final faqs = await _helpService.getFAQs();

      setState(() {
        _categories = categories;
        _faqArticles = faqs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading help content: $e');
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searchQuery = '';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchQuery = query;
    });

    try {
      final results = await _helpService.searchArticles(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      debugPrint('Error searching help articles: $e');
    }
  }

  void _openArticle(HelpArticle article) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HelpArticleScreen(article: article),
      ),
    );
  }

  void _openTutorial(String tutorialType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OnboardingScreen(
          tutorialType: tutorialType,
          onCompleted: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tutorial completed! You can always access it again from here.'),
                backgroundColor: AppTheme.talowaGreen,
              ),
            );
          },
        ),
      ),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Help Center',
          style: TextStyle(
            fontFamily: 'NotoSansTelugu',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.talowaGreen,
        elevation: AppTheme.elevationLow,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontFamily: 'NotoSansTelugu',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: 'Browse'),
            Tab(text: 'Search'),
            Tab(text: 'FAQs'),
          ],
        ),
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Loading help content...')
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBrowseTab(),
                _buildSearchTab(),
                _buildFAQTab(),
              ],
            ),
    );
  }

  Widget _buildBrowseTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.talowaGreen.withOpacity(0.1),
                  AppTheme.talowaGreen.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.talowaGreen.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome to TALOWA Help',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.talowaGreen,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Find answers to your questions and learn how to use TALOWA effectively.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openTutorial('messaging'),
                        icon: const Icon(Icons.message, size: 18),
                        label: const Text('Messaging Tutorial'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.talowaGreen,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openTutorial('calling'),
                        icon: const Icon(Icons.call, size: 18),
                        label: const Text('Calling Tutorial'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.talowaGreen,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Categories section
          const Text(
            'Browse by Category',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Category cards
          if (_categories.isEmpty)
            const Center(
              child: Column(
                children: [
                  Icon(Icons.help_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No help categories available',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final userRole = AuthService.currentUser?.displayName ?? 'member';
                final relevantArticles = category.getArticlesForRole(userRole);
                
                return HelpCategoryCard(
                  category: category.copyWith(articles: relevantArticles),
                  onTap: () => _openCategoryArticles(category, relevantArticles),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.all(16),
          color: AppTheme.background,
          child: HelpSearchBar(
            controller: _searchController,
            onSearch: _performSearch,
            onClear: _clearSearch,
            isLoading: _isSearching,
          ),
        ),

        // Search results
        Expanded(
          child: _searchQuery.isEmpty
              ? _buildSearchSuggestions()
              : _isSearching
                  ? const LoadingWidget(message: 'Searching...')
                  : HelpSearchResults(
                      results: _searchResults,
                      query: _searchQuery,
                      onArticleTap: _openArticle,
                    ),
        ),
      ],
    );
  }

  Widget _buildSearchSuggestions() {
    final suggestions = [
      'How to send a message',
      'Making voice calls',
      'Anonymous reporting',
      'Group management',
      'Privacy settings',
      'Troubleshooting',
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Popular searches',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.map((suggestion) {
              return ActionChip(
                label: Text(suggestion),
                onPressed: () {
                  _searchController.text = suggestion;
                  _performSearch(suggestion);
                },
                backgroundColor: AppTheme.talowaGreen.withOpacity(0.1),
                labelStyle: const TextStyle(color: AppTheme.talowaGreen),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQTab() {
    return FAQSection(
      articles: _faqArticles,
      onArticleTap: _openArticle,
    );
  }

  void _openCategoryArticles(HelpCategory category, List<HelpArticle> articles) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HelpCategoryArticlesScreen(
          category: category,
          articles: articles,
          onArticleTap: _openArticle,
        ),
      ),
    );
  }
}

// Help Category Articles Screen
class HelpCategoryArticlesScreen extends StatelessWidget {
  final HelpCategory category;
  final List<HelpArticle> articles;
  final Function(HelpArticle) onArticleTap;

  const HelpCategoryArticlesScreen({
    super.key,
    required this.category,
    required this.articles,
    required this.onArticleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          category.title,
          style: const TextStyle(
            fontFamily: 'NotoSansTelugu',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.talowaGreen,
        foregroundColor: Colors.white,
      ),
      body: articles.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.article_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No articles available',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: articles.length,
              itemBuilder: (context, index) {
                final article = articles[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.talowaGreen.withOpacity(0.1),
                      child: const Icon(
                        Icons.article,
                        color: AppTheme.talowaGreen,
                      ),
                    ),
                    title: Text(
                      article.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          article.content.length > 100
                              ? '${article.content.substring(0, 100)}...'
                              : article.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              article.readTimeText,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (article.isFAQ) ...[
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.talowaGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'FAQ',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.talowaGreen,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => onArticleTap(article),
                  ),
                );
              },
            ),
    );
  }
}

