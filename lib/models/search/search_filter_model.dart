// Search Filter Model - Advanced search filtering options
// Complete search filtering for TALOWA land rights platform

class SearchFilterModel {
  final List<String>? categories;
  final List<String>? types;
  final List<String>? statuses;
  final LocationFilter? location;
  final DateRangeFilter? dateRange;
  final List<String>? tags;
  final PriorityFilter? priority;
  final AuthorFilter? author;
  final RatingFilter? rating;
  final Map<String, dynamic>? customFilters;

  const SearchFilterModel({
    this.categories,
    this.types,
    this.statuses,
    this.location,
    this.dateRange,
    this.tags,
    this.priority,
    this.author,
    this.rating,
    this.customFilters,
  });

  SearchFilterModel copyWith({
    List<String>? categories,
    List<String>? types,
    List<String>? statuses,
    LocationFilter? location,
    DateRangeFilter? dateRange,
    List<String>? tags,
    PriorityFilter? priority,
    AuthorFilter? author,
    RatingFilter? rating,
    Map<String, dynamic>? customFilters,
  }) {
    return SearchFilterModel(
      categories: categories ?? this.categories,
      types: types ?? this.types,
      statuses: statuses ?? this.statuses,
      location: location ?? this.location,
      dateRange: dateRange ?? this.dateRange,
      tags: tags ?? this.tags,
      priority: priority ?? this.priority,
      author: author ?? this.author,
      rating: rating ?? this.rating,
      customFilters: customFilters ?? this.customFilters,
    );
  }

  // Convert to Algolia filter string
  String? toAlgoliaFilters() {
    final filters = <String>[];

    // Category filters
    if (categories != null && categories!.isNotEmpty) {
      final categoryFilter = categories!.map((c) => 'category:"$c"').join(' OR ');
      filters.add('($categoryFilter)');
    }

    // Type filters
    if (types != null && types!.isNotEmpty) {
      final typeFilter = types!.map((t) => 'type:"$t"').join(' OR ');
      filters.add('($typeFilter)');
    }

    // Status filters
    if (statuses != null && statuses!.isNotEmpty) {
      final statusFilter = statuses!.map((s) => 'status:"$s"').join(' OR ');
      filters.add('($statusFilter)');
    }

    // Location filters
    if (location != null) {
      final locationFilters = location!.toAlgoliaFilters();
      if (locationFilters.isNotEmpty) {
        filters.addAll(locationFilters);
      }
    }

    // Date range filters
    if (dateRange != null) {
      final dateFilter = dateRange!.toAlgoliaFilter();
      if (dateFilter != null) {
        filters.add(dateFilter);
      }
    }

    // Tag filters
    if (tags != null && tags!.isNotEmpty) {
      final tagFilters = tags!.map((tag) => 'tags:"$tag"').toList();
      filters.addAll(tagFilters);
    }

    // Priority filters
    if (priority != null) {
      final priorityFilter = priority!.toAlgoliaFilter();
      if (priorityFilter != null) {
        filters.add(priorityFilter);
      }
    }

    // Author filters
    if (author != null) {
      final authorFilter = author!.toAlgoliaFilter();
      if (authorFilter != null) {
        filters.add(authorFilter);
      }
    }

    // Rating filters
    if (rating != null) {
      final ratingFilter = rating!.toAlgoliaFilter();
      if (ratingFilter != null) {
        filters.add(ratingFilter);
      }
    }

    // Custom filters
    if (customFilters != null && customFilters!.isNotEmpty) {
      for (final entry in customFilters!.entries) {
        final key = entry.key;
        final value = entry.value;
        
        if (value is String) {
          filters.add('$key:"$value"');
        } else if (value is List) {
          final valueFilter = value.map((v) => '$key:"$v"').join(' OR ');
          filters.add('($valueFilter)');
        } else if (value is Map && value.containsKey('min') || value.containsKey('max')) {
          // Numeric range filter
          final min = value['min'];
          final max = value['max'];
          if (min != null && max != null) {
            filters.add('$key:$min TO $max');
          } else if (min != null) {
            filters.add('$key >= $min');
          } else if (max != null) {
            filters.add('$key <= $max');
          }
        }
      }
    }

    return filters.isEmpty ? null : filters.join(' AND ');
  }

  bool get isEmpty => 
    (categories?.isEmpty ?? true) &&
    (types?.isEmpty ?? true) &&
    (statuses?.isEmpty ?? true) &&
    location == null &&
    dateRange == null &&
    (tags?.isEmpty ?? true) &&
    priority == null &&
    author == null &&
    rating == null &&
    (customFilters?.isEmpty ?? true);

  bool get isNotEmpty => !isEmpty;

  @override
  String toString() {
    return 'SearchFilterModel(categories: $categories, types: $types, location: $location, dateRange: $dateRange)';
  }
}

class LocationFilter {
  final List<String>? states;
  final List<String>? districts;
  final List<String>? mandals;
  final List<String>? villages;
  final GeoLocationFilter? geoLocation;

  const LocationFilter({
    this.states,
    this.districts,
    this.mandals,
    this.villages,
    this.geoLocation,
  });

  List<String> toAlgoliaFilters() {
    final filters = <String>[];

    if (states != null && states!.isNotEmpty) {
      final stateFilter = states!.map((s) => 'location.state:"$s"').join(' OR ');
      filters.add('($stateFilter)');
    }

    if (districts != null && districts!.isNotEmpty) {
      final districtFilter = districts!.map((d) => 'location.district:"$d"').join(' OR ');
      filters.add('($districtFilter)');
    }

    if (mandals != null && mandals!.isNotEmpty) {
      final mandalFilter = mandals!.map((m) => 'location.mandal:"$m"').join(' OR ');
      filters.add('($mandalFilter)');
    }

    if (villages != null && villages!.isNotEmpty) {
      final villageFilter = villages!.map((v) => 'location.village:"$v"').join(' OR ');
      filters.add('($villageFilter)');
    }

    return filters;
  }
}

class GeoLocationFilter {
  final double latitude;
  final double longitude;
  final double radiusInMeters;

  const GeoLocationFilter({
    required this.latitude,
    required this.longitude,
    required this.radiusInMeters,
  });
}

class DateRangeFilter {
  final DateTime? startDate;
  final DateTime? endDate;
  final String fieldName;

  const DateRangeFilter({
    this.startDate,
    this.endDate,
    this.fieldName = 'createdAt',
  });

  String? toAlgoliaFilter() {
    if (startDate == null && endDate == null) return null;

    final startTimestamp = startDate?.millisecondsSinceEpoch;
    final endTimestamp = endDate?.millisecondsSinceEpoch;

    if (startTimestamp != null && endTimestamp != null) {
      return '$fieldName:$startTimestamp TO $endTimestamp';
    } else if (startTimestamp != null) {
      return '$fieldName >= $startTimestamp';
    } else if (endTimestamp != null) {
      return '$fieldName <= $endTimestamp';
    }

    return null;
  }
}

class PriorityFilter {
  final List<String>? priorities;
  final int? minPriority;
  final int? maxPriority;

  const PriorityFilter({
    this.priorities,
    this.minPriority,
    this.maxPriority,
  });

  String? toAlgoliaFilter() {
    if (priorities != null && priorities!.isNotEmpty) {
      final priorityFilter = priorities!.map((p) => 'priority:"$p"').join(' OR ');
      return '($priorityFilter)';
    }

    if (minPriority != null && maxPriority != null) {
      return 'priority:$minPriority TO $maxPriority';
    } else if (minPriority != null) {
      return 'priority >= $minPriority';
    } else if (maxPriority != null) {
      return 'priority <= $maxPriority';
    }

    return null;
  }
}

class AuthorFilter {
  final List<String>? authorIds;
  final List<String>? authorNames;
  final bool? verifiedOnly;

  const AuthorFilter({
    this.authorIds,
    this.authorNames,
    this.verifiedOnly,
  });

  String? toAlgoliaFilter() {
    final filters = <String>[];

    if (authorIds != null && authorIds!.isNotEmpty) {
      final idFilter = authorIds!.map((id) => 'authorId:"$id"').join(' OR ');
      filters.add('($idFilter)');
    }

    if (authorNames != null && authorNames!.isNotEmpty) {
      final nameFilter = authorNames!.map((name) => 'authorName:"$name"').join(' OR ');
      filters.add('($nameFilter)');
    }

    if (verifiedOnly == true) {
      filters.add('verified:true');
    }

    return filters.isEmpty ? null : filters.join(' AND ');
  }
}

class RatingFilter {
  final double? minRating;
  final double? maxRating;
  final int? minReviews;

  const RatingFilter({
    this.minRating,
    this.maxRating,
    this.minReviews,
  });

  String? toAlgoliaFilter() {
    final filters = <String>[];

    if (minRating != null && maxRating != null) {
      filters.add('rating:$minRating TO $maxRating');
    } else if (minRating != null) {
      filters.add('rating >= $minRating');
    } else if (maxRating != null) {
      filters.add('rating <= $maxRating');
    }

    if (minReviews != null) {
      filters.add('reviewsCount >= $minReviews');
    }

    return filters.isEmpty ? null : filters.join(' AND ');
  }
}

