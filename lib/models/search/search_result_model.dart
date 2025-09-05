// Search Result Model - Search results data structure
// Complete search result handling for TALOWA platform

class SearchResultModel {
  final String indexName;
  final String query;
  final List<SearchHitModel> hits;
  final int totalHits;
  final int page;
  final int hitsPerPage;
  final int totalPages;
  final Map<String, Map<String, int>> facets;
  final int processingTimeMS;
  final bool exhaustiveNbHits;
  final String? aroundLatLng;
  final int? automaticRadius;

  const SearchResultModel({
    required this.indexName,
    required this.query,
    required this.hits,
    required this.totalHits,
    required this.page,
    required this.hitsPerPage,
    required this.totalPages,
    required this.facets,
    required this.processingTimeMS,
    required this.exhaustiveNbHits,
    this.aroundLatLng,
    this.automaticRadius,
  });

  factory SearchResultModel.fromFirebaseResults(
    String indexName,
    String query,
    List<Map<String, dynamic>> documents,
    {
      int page = 0,
      int hitsPerPage = 20,
      int processingTimeMS = 0,
    }
  ) {
    final hits = documents.map((doc) => SearchHitModel.fromFirebaseDoc(doc)).toList();

    return SearchResultModel(
      indexName: indexName,
      query: query,
      hits: hits,
      totalHits: hits.length,
      page: page,
      hitsPerPage: hitsPerPage,
      totalPages: (hits.length / hitsPerPage).ceil(),
      facets: {},
      processingTimeMS: processingTimeMS,
      exhaustiveNbHits: true,
    );
  }

  bool get isEmpty => hits.isEmpty;
  bool get isNotEmpty => hits.isNotEmpty;
  bool get hasMorePages => page < totalPages - 1;

  @override
  String toString() {
    return 'SearchResultModel(indexName: $indexName, query: $query, totalHits: $totalHits, hits: ${hits.length})';
  }
}

class SearchHitModel {
  final String objectID;
  final Map<String, dynamic> data;
  final Map<String, dynamic> highlightResult;
  final double? geoDistance;
  final int? rankingInfo;

  const SearchHitModel({
    required this.objectID,
    required this.data,
    required this.highlightResult,
    this.geoDistance,
    this.rankingInfo,
  });

  factory SearchHitModel.fromFirebaseDoc(Map<String, dynamic> doc) {
    return SearchHitModel(
      objectID: doc['objectID'] as String? ?? '',
      data: Map<String, dynamic>.from(doc)..remove('objectID'),
      highlightResult: {},
      geoDistance: null,
      rankingInfo: null,
    );
  }

  factory SearchHitModel.fromAlgoliaHit(Map<String, dynamic> hit) {
    return SearchHitModel(
      objectID: hit['objectID'] as String,
      data: Map<String, dynamic>.from(hit)..remove('objectID')..remove('_highlightResult')..remove('_geoDistance')..remove('_rankingInfo'),
      highlightResult: hit['_highlightResult'] as Map<String, dynamic>? ?? {},
      geoDistance: hit['_geoDistance'] as double?,
      rankingInfo: hit['_rankingInfo'] as int?,
    );
  }

  // Convenience getters for common fields
  String? get title => data['title'] as String?;
  String? get name => data['name'] as String?;
  String? get content => data['content'] as String?;
  String? get description => data['description'] as String?;
  String? get authorName => data['authorName'] as String?;
  String? get type => data['type'] as String?;
  String? get category => data['category'] as String?;
  String? get status => data['status'] as String?;
  DateTime? get createdAt {
    final timestamp = data['createdAt'];
    if (timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else if (timestamp is String) {
      return DateTime.tryParse(timestamp);
    }
    return null;
  }
  
  Map<String, dynamic>? get location => data['location'] as Map<String, dynamic>?;
  String? get state => location?['state'] as String?;
  String? get district => location?['district'] as String?;
  String? get mandal => location?['mandal'] as String?;
  String? get village => location?['village'] as String?;
  
  List<String>? get tags {
    final tagData = data['tags'];
    if (tagData is List) {
      return tagData.cast<String>();
    }
    return null;
  }

  // Get highlighted version of a field
  String? getHighlighted(String fieldName) {
    final highlighted = highlightResult[fieldName];
    if (highlighted is Map && highlighted['value'] is String) {
      return highlighted['value'] as String;
    }
    return data[fieldName] as String?;
  }

  // Check if field has highlights
  bool hasHighlight(String fieldName) {
    final highlighted = highlightResult[fieldName];
    if (highlighted is Map && highlighted['matchLevel'] is String) {
      return highlighted['matchLevel'] != 'none';
    }
    return false;
  }

  @override
  String toString() {
    return 'SearchHitModel(objectID: $objectID, title: $title, type: $type)';
  }
}

// Search result aggregation for universal search
class UniversalSearchResultModel {
  final String query;
  final Map<String, SearchResultModel> results;
  final int totalHits;
  final int processingTimeMS;

  const UniversalSearchResultModel({
    required this.query,
    required this.results,
    required this.totalHits,
    required this.processingTimeMS,
  });

  factory UniversalSearchResultModel.fromResults(
    String query,
    Map<String, SearchResultModel> results,
  ) {
    final totalHits = results.values.fold<int>(0, (sum, result) => sum + result.totalHits);
    final processingTimeMS = results.values.fold<int>(0, (sum, result) => sum + result.processingTimeMS);

    return UniversalSearchResultModel(
      query: query,
      results: results,
      totalHits: totalHits,
      processingTimeMS: processingTimeMS,
    );
  }

  // Get all hits across all indices
  List<SearchHitModel> get allHits {
    final allHits = <SearchHitModel>[];
    for (final result in results.values) {
      allHits.addAll(result.hits);
    }
    return allHits;
  }

  // Get hits by index name
  List<SearchHitModel> getHitsByIndex(String indexName) {
    return results[indexName]?.hits ?? [];
  }

  // Get top hits across all indices (sorted by relevance)
  List<SearchHitModel> getTopHits(int limit) {
    final allHits = this.allHits;
    // Sort by relevance (hits are already sorted within each index)
    // For cross-index sorting, we'd need more sophisticated ranking
    return allHits.take(limit).toList();
  }

  bool get isEmpty => totalHits == 0;
  bool get isNotEmpty => totalHits > 0;

  @override
  String toString() {
    return 'UniversalSearchResultModel(query: $query, totalHits: $totalHits, indices: ${results.keys.join(', ')})';
  }
}

