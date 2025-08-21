// TALOWA Tutorial Progress Model
// Tracks user progress through various tutorials

class TutorialProgress {
  final bool messagingCompleted;
  final bool callingCompleted;
  final bool groupManagementCompleted;
  final double overallProgress;
  final DateTime? lastUpdated;

  const TutorialProgress({
    required this.messagingCompleted,
    required this.callingCompleted,
    required this.groupManagementCompleted,
    required this.overallProgress,
    this.lastUpdated,
  });

  TutorialProgress copyWith({
    bool? messagingCompleted,
    bool? callingCompleted,
    bool? groupManagementCompleted,
    double? overallProgress,
    DateTime? lastUpdated,
  }) {
    return TutorialProgress(
      messagingCompleted: messagingCompleted ?? this.messagingCompleted,
      callingCompleted: callingCompleted ?? this.callingCompleted,
      groupManagementCompleted: groupManagementCompleted ?? this.groupManagementCompleted,
      overallProgress: overallProgress ?? this.overallProgress,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Check if all basic tutorials are completed
  bool get isBasicTutorialCompleted => messagingCompleted && callingCompleted;

  /// Check if all tutorials (including coordinator features) are completed
  bool get isAllTutorialsCompleted => 
      messagingCompleted && callingCompleted && groupManagementCompleted;

  /// Get next recommended tutorial
  String? get nextRecommendedTutorial {
    if (!messagingCompleted) return 'messaging';
    if (!callingCompleted) return 'calling';
    if (!groupManagementCompleted) return 'group_management';
    return null;
  }

  /// Get completion percentage as integer (0-100)
  int get completionPercentage => (overallProgress * 100).round();

  Map<String, dynamic> toJson() {
    return {
      'messagingCompleted': messagingCompleted,
      'callingCompleted': callingCompleted,
      'groupManagementCompleted': groupManagementCompleted,
      'overallProgress': overallProgress,
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }

  factory TutorialProgress.fromJson(Map<String, dynamic> json) {
    return TutorialProgress(
      messagingCompleted: json['messagingCompleted'] as bool,
      callingCompleted: json['callingCompleted'] as bool,
      groupManagementCompleted: json['groupManagementCompleted'] as bool,
      overallProgress: (json['overallProgress'] as num).toDouble(),
      lastUpdated: json['lastUpdated'] != null 
          ? DateTime.parse(json['lastUpdated'] as String)
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TutorialProgress &&
        other.messagingCompleted == messagingCompleted &&
        other.callingCompleted == callingCompleted &&
        other.groupManagementCompleted == groupManagementCompleted &&
        other.overallProgress == overallProgress;
  }

  @override
  int get hashCode {
    return Object.hash(
      messagingCompleted,
      callingCompleted,
      groupManagementCompleted,
      overallProgress,
    );
  }

  @override
  String toString() {
    return 'TutorialProgress(messaging: $messagingCompleted, calling: $callingCompleted, '
           'groupManagement: $groupManagementCompleted, progress: $completionPercentage%)';
  }
}