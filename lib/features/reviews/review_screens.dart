part of '../../main.dart';

const reviewPublicationExplanation =
    'Reviews stay hidden until both sides submit for this student–client pair, or 14 days after project completion. Reviews submitted after that date publish immediately. Ratings are feedback, not professional certification.';

class ProjectReviewActions extends StatelessWidget {
  const ProjectReviewActions({
    super.key,
    required this.project,
    required this.actorId,
  });
  final BridgeProject project;
  final String actorId;
  @override
  Widget build(BuildContext context) {
    final repository = ReviewScope.maybeOf(context);
    if (repository == null) return const SizedBox.shrink();
    final targets = repository.targets(actorId, project.id);
    if (targets.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        for (final target in targets)
          Builder(
            builder: (context) {
              final own = repository.ownReview(actorId, project.id, target);
              final name = repository.nameFor(target, project);
              return own == null
                  ? TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ReviewFormScreen(
                            repository: repository,
                            project: project,
                            actorId: actorId,
                            targetId: target,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.rate_review_outlined),
                      label: Text(
                        targets.length > 1
                            ? 'Leave a Review · $name'
                            : 'Leave a Review',
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Review submitted · $name\n${own.publicationStatus == ReviewPublication.published ? 'Published' : 'Hidden until both submit or the review window ends'}',
                        style: const TextStyle(color: muted),
                      ),
                    );
            },
          ),
      ],
    );
  }
}

class ReviewFormScreen extends StatefulWidget {
  const ReviewFormScreen({
    super.key,
    required this.repository,
    required this.project,
    required this.actorId,
    required this.targetId,
  });
  final ReviewRepository repository;
  final BridgeProject project;
  final String actorId, targetId;
  @override
  State<ReviewFormScreen> createState() => _ReviewFormScreenState();
}

class _ReviewFormScreenState extends State<ReviewFormScreen> {
  int overall = 0;
  final ratings = <String, int>{};
  final comment = TextEditingController();
  bool busy = false;
  String? error;
  bool get client => widget.actorId == widget.project.clientId;
  Map<String, String> get categories =>
      client ? studentReviewCategories : clientReviewCategories;
  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    if (overall == 0 ||
        categories.keys.any((key) => (ratings[key] ?? 0) == 0)) {
      setState(() => error = 'Select a rating from 1 to 5 for every category.');
      return;
    }
    FocusScope.of(context).unfocus();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Submit your review?'),
        content: const Text(
          'Your review cannot be edited after submission.\n\n$reviewPublicationExplanation',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.submit(
        actorId: widget.actorId,
        projectId: widget.project.id,
        targetId: widget.targetId,
        overallRating: overall,
        categoryRatings: ratings,
        comment: comment.text,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Review submitted. Publication follows the review window rules.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = e is StateError
              ? e.message.toString()
              : e is ArgumentError
              ? e.message.toString()
              : 'Could not save your review. Your draft is preserved. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final names = ProfessionalScope.maybeOf(context);
    final target = client
        ? names?.profiles
                  .where((p) => p.id == widget.targetId)
                  .firstOrNull
                  ?.name ??
              widget.project.acceptedTeamStudents[widget.targetId] ??
              widget.project.applicantName ??
              'Student'
        : widget.project.client;
    final deadline = widget.repository.publicationDeadline(widget.project.id);
    return Scaffold(
      appBar: AppBar(title: Text(client ? 'Review Student' : 'Review Client')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              target,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
            ),
            Text(widget.project.title, style: const TextStyle(color: muted)),
            const SizedBox(height: 20),
            const Text(
              reviewPublicationExplanation,
              style: TextStyle(color: muted, height: 1.5),
            ),
            if (deadline != null)
              Text(
                'Review window ends: ${_reviewDate(deadline)}',
                style: const TextStyle(color: muted),
              ),
            const SizedBox(height: 20),
            ReviewStarPicker(
              label: 'Overall rating',
              value: overall,
              enabled: !busy,
              onChanged: (v) => setState(() => overall = v),
            ),
            for (final entry in categories.entries)
              ReviewStarPicker(
                label: entry.value,
                value: ratings[entry.key] ?? 0,
                enabled: !busy,
                onChanged: (v) => setState(() => ratings[entry.key] = v),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: comment,
              enabled: !busy,
              minLines: 3,
              maxLines: 6,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Written feedback (optional)',
                helperText: 'Be respectful. Do not include private contact information.',
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: busy ? null : submit,
              child: Text(busy ? 'Saving review…' : 'Submit Review'),
            ),
          ],
        ),
      ),
    );
  }
}

class ReviewStarPicker extends StatelessWidget {
  const ReviewStarPicker({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });
  final String label;
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        Wrap(
          children: [
            for (var star = 1; star <= 5; star++)
              IconButton(
                tooltip: '$label: $star of 5',
                isSelected: value == star,
                onPressed: enabled ? () => onChanged(star) : null,
                icon: Icon(
                  star <= value
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: violet,
                ),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
          ],
        ),
      ],
    ),
  );
}

String _reviewDate(DateTime date) =>
    date.toLocal().toIso8601String().split('T').first;

class ReviewsReputationSection extends StatelessWidget {
  const ReviewsReputationSection({
    super.key,
    required this.profileId,
    required this.actorId,
    required this.client,
  });
  final String profileId, actorId;
  final bool client;
  @override
  Widget build(BuildContext context) {
    final repository = ReviewScope.maybeOf(context);
    if (repository == null) return const SizedBox.shrink();
    final reviews = repository.publishedFor(profileId);
    final average = repository.averageFor(profileId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const SectionTitle('Reviews & Reputation'),
        if (reviews.isEmpty)
          Text(
            client
                ? 'No reviews yet. Reviews will appear after completed projects.'
                : 'No reviews yet. Complete your first project to start building your reputation.',
            style: const TextStyle(color: muted),
          ),
        if (average != null)
          Text(
            '★ ${average.toStringAsFixed(1)} / 5 · ${reviews.length} published reviews',
            style: const TextStyle(
              color: violet,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        if (reviews.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6, bottom: 12),
            child: Text(
              'Feedback from completed projects. Ratings are not certification.',
              style: TextStyle(color: muted),
            ),
          ),
        for (final review in reviews)
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE9EAF1)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    review.reviewerName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    review.projectTitle,
                    style: const TextStyle(color: muted),
                  ),
                  Text(
                    '★ ${review.overallRating} / 5 · ${_reviewDate(review.publishedAt!)}',
                    style: const TextStyle(color: violet),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    review.comment.isEmpty
                        ? 'No written feedback.'
                        : review.comment,
                  ),
                  const SizedBox(height: 8),
                  for (final category in review.categoryRatings.entries)
                    Text(
                      '${(review.revieweeRole == ReviewRole.student ? studentReviewCategories : clientReviewCategories)[category.key]}: ${category.value}/5',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  if (review.moderationStatus == ReviewModeration.reported)
                    const Text(
                      'Reported · awaiting local moderation',
                      style: TextStyle(color: muted),
                    ),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => ReportReviewScreen(
                          repository: repository,
                          review: review,
                          actorId: actorId,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.flag_outlined, size: 18),
                    label: const Text('Report review'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class ReviewProfileScreen extends StatefulWidget {
  const ReviewProfileScreen({
    super.key,
    required this.repository,
    required this.profileId,
    required this.actorId,
    required this.client,
  });
  final ReviewRepository repository;
  final String profileId, actorId;
  final bool client;
  @override
  State<ReviewProfileScreen> createState() => _ReviewProfileScreenState();
}

class _ReviewProfileScreenState extends State<ReviewProfileScreen> {
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => refresh());
  }

  Future<void> refresh() async {
    try {
      await widget.repository.refresh();
      if (mounted) setState(() => error = null);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              error = 'Review updates could not be saved. Pull down to retry.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reviews & Reputation')),
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            if (error != null) Text(error!),
            ReviewsReputationSection(
              profileId: widget.profileId,
              actorId: widget.actorId,
              client: widget.client,
            ),
          ],
        ),
      ),
    ),
  );
}

class ReportReviewScreen extends StatefulWidget {
  const ReportReviewScreen({
    super.key,
    required this.repository,
    required this.review,
    required this.actorId,
  });
  final ReviewRepository repository;
  final ProjectReview review;
  final String actorId;
  @override
  State<ReportReviewScreen> createState() => _ReportReviewScreenState();
}

class _ReportReviewScreenState extends State<ReportReviewScreen> {
  final reason = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  Future<void> report() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.report(
        actorId: widget.actorId,
        reviewId: widget.review.id,
        reason: reason.text,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Report saved on this device. The review remains visible pending moderation.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = e is StateError
              ? e.message.toString()
              : e is ArgumentError
              ? e.message.toString()
              : 'Could not save your report. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Report Review')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.review.projectTitle,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          const Text(
            'Report harassment, private information, threats or inappropriate content. Disagreement with a rating alone does not remove it. Reports are stored locally; no external moderation team is contacted.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: reason,
            enabled: !busy,
            minLines: 4,
            maxLines: 8,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Reason for reporting',
            ),
          ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          FilledButton(
            onPressed: busy ? null : report,
            child: Text(busy ? 'Saving report…' : 'Submit report'),
          ),
        ],
      ),
    ),
  );
}
