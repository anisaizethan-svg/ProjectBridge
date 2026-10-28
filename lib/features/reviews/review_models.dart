part of '../../main.dart';

enum ReviewRole { student, client }

enum ReviewPublication { pending, published }

enum ReviewModeration { unreported, reported }

const studentReviewCategories = {
  'quality': 'Quality of work',
  'communication': 'Communication',
  'reliability': 'Reliability and deadlines',
};
const clientReviewCategories = {
  'clarity': 'Clarity of requirements',
  'communication': 'Communication',
  'fairness': 'Fairness and respect',
};

class ProjectReview {
  ProjectReview({
    required this.id,
    required this.projectId,
    required this.reviewerId,
    required this.revieweeId,
    required this.reviewerRole,
    required this.revieweeRole,
    required this.overallRating,
    required Map<String, int> categoryRatings,
    required this.comment,
    required this.createdAt,
    required this.reviewerName,
    required this.revieweeName,
    required this.projectTitle,
    this.publicationStatus = ReviewPublication.pending,
    this.publishedAt,
    this.moderationStatus = ReviewModeration.unreported,
  }) : categoryRatings = Map.unmodifiable(categoryRatings);
  final String id, projectId, reviewerId, revieweeId, comment;
  final String reviewerName, revieweeName, projectTitle;
  final ReviewRole reviewerRole, revieweeRole;
  final int overallRating;
  final Map<String, int> categoryRatings;
  final DateTime createdAt;
  final ReviewPublication publicationStatus;
  final DateTime? publishedAt;
  final ReviewModeration moderationStatus;
  ProjectReview withStatus({
    DateTime? publishedAt,
    ReviewModeration? moderation,
  }) => ProjectReview(
    id: id,
    projectId: projectId,
    reviewerId: reviewerId,
    revieweeId: revieweeId,
    reviewerRole: reviewerRole,
    revieweeRole: revieweeRole,
    overallRating: overallRating,
    categoryRatings: categoryRatings,
    comment: comment,
    createdAt: createdAt,
    reviewerName: reviewerName,
    revieweeName: revieweeName,
    projectTitle: projectTitle,
    publicationStatus: publishedAt == null
        ? publicationStatus
        : ReviewPublication.published,
    publishedAt: publishedAt ?? this.publishedAt,
    moderationStatus: moderation ?? moderationStatus,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'projectId': projectId,
    'reviewerId': reviewerId,
    'revieweeId': revieweeId,
    'reviewerRole': reviewerRole.name,
    'revieweeRole': revieweeRole.name,
    'overallRating': overallRating,
    'categoryRatings': categoryRatings,
    'comment': comment,
    'createdAt': createdAt.toIso8601String(),
    'publicationStatus': publicationStatus.name,
    'publishedAt': publishedAt?.toIso8601String(),
    'moderationStatus': moderationStatus.name,
    'reviewerName': reviewerName,
    'revieweeName': revieweeName,
    'projectTitle': projectTitle,
  };
  factory ProjectReview.fromJson(Map<String, dynamic> j) => ProjectReview(
    id: j['id'] as String,
    projectId: j['projectId'] as String,
    reviewerId: j['reviewerId'] as String,
    revieweeId: j['revieweeId'] as String,
    reviewerRole: ReviewRole.values.byName(j['reviewerRole'] as String),
    revieweeRole: ReviewRole.values.byName(j['revieweeRole'] as String),
    overallRating: j['overallRating'] as int,
    categoryRatings: Map<String, int>.from(j['categoryRatings'] as Map),
    comment: j['comment'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    publicationStatus: ReviewPublication.values.byName(
      j['publicationStatus'] as String,
    ),
    publishedAt: j['publishedAt'] == null
        ? null
        : DateTime.parse(j['publishedAt'] as String),
    moderationStatus: ReviewModeration.values.byName(
      j['moderationStatus'] as String? ?? 'unreported',
    ),
    reviewerName: j['reviewerName'] as String,
    revieweeName: j['revieweeName'] as String,
    projectTitle: j['projectTitle'] as String,
  );
}

abstract interface class ReviewRepository implements Listenable {
  String nameFor(String id, BridgeProject project);
  List<String> targets(String actorId, String projectId);
  ProjectReview? ownReview(String actorId, String projectId, String targetId);
  List<ProjectReview> publishedFor(String profileId);
  double? averageFor(String profileId);
  DateTime? publicationDeadline(String projectId);
  Future<void> submit({
    required String actorId,
    required String projectId,
    required String targetId,
    required int overallRating,
    required Map<String, int> categoryRatings,
    String comment = '',
  });
  Future<void> report({
    required String actorId,
    required String reviewId,
    required String reason,
  });
  Future<void> refresh();
}
