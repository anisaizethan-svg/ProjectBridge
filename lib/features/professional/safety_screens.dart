part of '../../main.dart';

Future<Map<String, String>?> textFieldsDialog(
  BuildContext context,
  String title,
  Map<String, String> values, {
  Set<String>? requiredKeys,
}) => showDialog<Map<String, String>>(
  context: context,
  builder: (_) => _RecordFieldsDialog(
    title: title,
    values: values,
    requiredKeys: requiredKeys,
  ),
);

class _RecordFieldsDialog extends StatefulWidget {
  const _RecordFieldsDialog({
    required this.title,
    required this.values,
    this.requiredKeys,
  });
  final String title;
  final Map<String, String> values;
  final Set<String>? requiredKeys;
  @override
  State<_RecordFieldsDialog> createState() => _RecordFieldsDialogState();
}

class _RecordFieldsDialogState extends State<_RecordFieldsDialog> {
  final form = GlobalKey<FormState>();
  late final controllers = widget.values.map(
    (key, value) => MapEntry(key, TextEditingController(text: value)),
  );
  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 550,
      child: Form(
        key: form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in controllers.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: entry.value,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(labelText: entry.key),
                    validator: (v) =>
                        (widget.requiredKeys == null ||
                                widget.requiredKeys!.contains(entry.key)) &&
                            (v == null || v.trim().isEmpty)
                        ? 'Required'
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(
              context,
              controllers.map((key, value) => MapEntry(key, value.text.trim())),
            );
          }
        },
        child: const Text('Save'),
      ),
    ],
  );
}

void openProjectSafety(
  BuildContext context,
  ProfessionalRepository repository,
  String projectId,
  String actorId,
) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ProjectSafetyScreen(
        repository: repository,
        projectId: projectId,
        actorId: actorId,
      ),
    ),
  );
}

class ProjectSafetyScreen extends StatefulWidget {
  const ProjectSafetyScreen({
    super.key,
    required this.repository,
    required this.projectId,
    required this.actorId,
  });
  final ProfessionalRepository repository;
  final String projectId, actorId;
  @override
  State<ProjectSafetyScreen> createState() => _ProjectSafetyScreenState();
}

class _ProjectSafetyScreenState extends State<ProjectSafetyScreen> {
  int page = 0;
  ProfessionalRepository get repo => widget.repository;
  BridgeProject get project => repo.project(widget.projectId);
  bool get client => widget.actorId == project.clientId;
  Future<void> editAgreement() async {
    final result = await textFieldsDialog(
      context,
      'Project agreement',
      repo.agreementPreview(project).terms,
    );
    if (result != null && mounted) {
      professionalAction(
        context,
        () => repo.saveAgreement(widget.actorId, project.id, result),
      );
    }
  }

  Future<void> createMilestone() async {
    final result = await textFieldsDialog(context, 'Create milestone', {
      'Milestone title': '',
      'Expected deliverable': '',
      'Due date (YYYY-MM-DD)': project.deadlineAt
          .toIso8601String()
          .split('T')
          .first,
    });
    if (result == null || !mounted) return;
    professionalAction(context, () {
      final due = DateTime.tryParse(result['Due date (YYYY-MM-DD)']!);
      if (due == null) throw StateError('Enter a valid due date.');
      repo.createMilestone(
        widget.actorId,
        project.id,
        result['Milestone title']!,
        result['Expected deliverable']!,
        due,
        assigneeId: project.acceptedParticipantIds.firstOrNull,
      );
    });
  }

  Future<void> submitMilestone(ProjectMilestone milestone) async {
    final result = await textFieldsDialog(context, 'Submit milestone', {
      'Deliverable or progress link': milestone.submission,
    });
    if (result != null && mounted) {
      professionalAction(
        context,
        () => repo.submitMilestone(
          widget.actorId,
          milestone.id,
          result.values.single,
        ),
      );
    }
  }

  Future<void> reviewMilestone(ProjectMilestone milestone, bool approve) async {
    final result = await textFieldsDialog(
      context,
      approve ? 'Approve milestone' : 'Request changes',
      {'Review feedback': ''},
    );
    if (result != null && mounted) {
      professionalAction(
        context,
        () => repo.reviewMilestone(
          widget.actorId,
          milestone.id,
          approve,
          result.values.single,
        ),
      );
    }
  }

  Future<void> closeProject(bool cancel) async {
    final result = await textFieldsDialog(
      context,
      cancel ? 'Cancel project' : 'Close project',
      {'Reason and handover': ''},
    );
    if (result != null && mounted) {
      professionalAction(
        context,
        () => repo.closeProject(
          widget.actorId,
          project.id,
          cancel,
          result.values.single,
        ),
      );
    }
  }

  Future<void> withdraw() async {
    final result = await textFieldsDialog(context, 'Request withdrawal', {
      'Reason and proposed handover': '',
    });
    if (result != null && mounted) {
      professionalAction(
        context,
        () => repo.requestWithdrawal(
          widget.actorId,
          project.id,
          result.values.single,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Agreement & Milestones'),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final (index, label) in [
                'Agreement',
                'Milestones',
                'Reports',
                'History',
              ].indexed)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: page == index,
                    onSelected: (_) => setState(() => page = index),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    body: AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        final p = project;
        if (widget.actorId != p.clientId && widget.actorId != p.applicantId) {
          return const Center(
            child: Text(
              'Only this project’s participants can view its collaboration details.',
            ),
          );
        }
        final active =
            client || p.acceptedParticipantIds.contains(widget.actorId);
        final agreement = repo.agreementPreview(p);
        final milestones = active
            ? repo.milestonesFor(widget.actorId, p.id)
            : <ProjectMilestone>[];
        final closed = [
          'Closed',
          'Cancelled',
          'Completed',
        ].contains(p.lifecycleStatus);
        final withdrawal = repo.withdrawalFor(widget.actorId, p.id);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(p.title, style: Theme.of(context).textTheme.titleLarge),
            Text('${p.lifecycleStatus} · ${repo.passportStatus(p)}'),
            ProjectReviewActions(project: p, actorId: widget.actorId),
            const SizedBox(height: 12),
            const SizedBox(height: 16),
            if (!active)
              const Text(
                'Membership ended. Your history is retained; work and private chat access are revoked.',
              ),
            if (page == 0 && active) ...[
              const InfoCard(
                icon: Icons.handshake_outlined,
                title: 'Understand and acknowledge the scope',
                body: 'Both parties acknowledge the current version before work starts. This summary is not legal advice or a claim of a legally enforceable contract. Editing scope resets acknowledgements. Chat remains available after acceptance.',
              ),
              Text(
                'Agreement version ${agreement.version}${agreement.version == 0 ? ' · Preview, not saved' : ''}',
              ),
              for (final entry in agreement.terms.entries)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: InfoCard(
                    icon: Icons.checklist_outlined,
                    title: entry.key,
                    body: entry.value,
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                'Client acknowledgement: ${agreement.acknowledgements.containsKey(p.clientId) ? 'Recorded' : 'Pending'}',
              ),
              Text(
                'Student acknowledgement: ${p.acceptedParticipantIds.isNotEmpty && p.acceptedParticipantIds.every(agreement.acknowledgements.containsKey) ? 'Recorded' : 'Pending'}',
              ),
              if (client && !closed)
                FilledButton(
                  onPressed: editAgreement,
                  child: Text(
                    agreement.version == 0
                        ? 'Create agreement'
                        : 'Edit agreement',
                  ),
                ),
              if (!closed &&
                  agreement.version > 0 &&
                  !agreement.acknowledgements.containsKey(widget.actorId))
                OutlinedButton(
                  onPressed: () => professionalAction(
                    context,
                    () => repo.acknowledgeAgreement(widget.actorId, p.id),
                  ),
                  child: const Text('I acknowledge this scope'),
                ),
            ],
            if (page == 1 && active) ...[
              if (milestones.isNotEmpty) ...[
                Text(
                  'Milestone progress: ${milestones.where((m) => m.status == MilestoneStatus.approved).length}/${milestones.length} approved',
                ),
                LinearProgressIndicator(
                  value:
                      milestones
                          .where((m) => m.status == MilestoneStatus.approved)
                          .length /
                      milestones.length,
                ),
                const SizedBox(height: 12),
              ],
              Text(
                'Work may begin: ${repo.agreementReady(p) ? 'Both acknowledgements recorded' : 'Review and acknowledge the agreement first'}',
              ),
              if (client && !closed)
                FilledButton.icon(
                  onPressed: createMilestone,
                  icon: const Icon(Icons.add),
                  label: const Text('Create milestone'),
                ),
              if (milestones.isEmpty)
                const Text(
                  'No milestones yet. The client can create a clear deliverable and assign it to an accepted student.',
                ),
              for (final milestone in milestones)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          milestone.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(milestone.description),
                        Text('Status: ${milestone.status.label}'),
                        Text(
                          'Assigned: ${milestone.assigneeId == null ? 'Not assigned' : repo.profile(milestone.assigneeId!).name} · Due ${milestone.dueAt.toLocal().toString().split(' ').first}',
                        ),
                        if (milestone.submission.isNotEmpty)
                          Text('Submitted: ${milestone.submission}'),
                        if (milestone.feedback.isNotEmpty)
                          Text('Review: ${milestone.feedback}'),
                        if (!closed)
                          Wrap(
                            spacing: 8,
                            children: [
                              if (client &&
                                  milestone.assigneeId == null &&
                                  p.acceptedParticipantIds.isNotEmpty)
                                TextButton(
                                  onPressed: () => professionalAction(
                                    context,
                                    () => repo.assignMilestone(
                                      widget.actorId,
                                      milestone.id,
                                      p.acceptedParticipantIds.first,
                                    ),
                                  ),
                                  child: const Text('Assign accepted student'),
                                ),
                              if (!client &&
                                  milestone.assigneeId == widget.actorId &&
                                  [
                                    MilestoneStatus.notStarted,
                                    MilestoneStatus.needsChanges,
                                  ].contains(milestone.status))
                                TextButton(
                                  onPressed: () => professionalAction(
                                    context,
                                    () => repo.startMilestone(
                                      widget.actorId,
                                      milestone.id,
                                    ),
                                  ),
                                  child: const Text('Start milestone'),
                                ),
                              if (!client &&
                                  milestone.assigneeId == widget.actorId &&
                                  [
                                    MilestoneStatus.inProgress,
                                    MilestoneStatus.needsChanges,
                                  ].contains(milestone.status))
                                TextButton(
                                  onPressed: () => submitMilestone(milestone),
                                  child: const Text('Submit progress'),
                                ),
                              if (client &&
                                  milestone.status ==
                                      MilestoneStatus.submitted) ...[
                                TextButton(
                                  onPressed: () =>
                                      reviewMilestone(milestone, true),
                                  child: const Text('Approve work'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      reviewMilestone(milestone, false),
                                  child: const Text('Request changes'),
                                ),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              if (client &&
                  !closed &&
                  (p.approved ||
                      (milestones.isNotEmpty &&
                          milestones.every(
                            (m) => m.status == MilestoneStatus.approved,
                          ))))
                FilledButton(
                  onPressed: () async {
                    final approved = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Approve project completion?'),
                        content: const Text(
                          'Confirm that the agreed work is complete. This creates a client-confirmed demo passport.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Confirm completion'),
                          ),
                        ],
                      ),
                    );
                    if (approved == true && context.mounted) {
                      professionalAction(
                        context,
                        () => repo.completeProject(widget.actorId, p.id),
                      );
                    }
                  },
                  child: const Text('Approve project completion'),
                ),
            ],
            if (page == 2) ...[
              FilledButton.icon(
                onPressed: () =>
                    openSafetyReport(context, repo, widget.actorId, p.id),
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Report a problem'),
              ),
              const Text(
                'Only your own reports are shown. No real moderation team receives this offline demo report.',
              ),
              for (final report
                  in repo
                      .reportsFor(widget.actorId)
                      .where((r) => r.projectId == p.id))
                Card(
                  child: ListTile(
                    title: Text(report.category),
                    subtitle: Text(
                      '${report.details}\n${report.status}\n${report.reviewNote}',
                    ),
                  ),
                ),
            ],
            if (page == 3) ...[
              for (final event in repo.historyFor(widget.actorId, p.id))
                ListTile(
                  title: Text(event['detail']!),
                  subtitle: Text('${event['actorId']} · ${event['time']}'),
                ),
            ],
            const Divider(height: 28),
            if (withdrawal != null) Text('Withdrawal: $withdrawal'),
            if (client && withdrawal == 'Requested')
              Wrap(
                children: [
                  TextButton(
                    onPressed: () => professionalAction(
                      context,
                      () => repo.reviewWithdrawal(widget.actorId, p.id, true),
                    ),
                    child: const Text('Approve withdrawal'),
                  ),
                  TextButton(
                    onPressed: () => professionalAction(
                      context,
                      () => repo.reviewWithdrawal(widget.actorId, p.id, false),
                    ),
                    child: const Text('Decline withdrawal'),
                  ),
                ],
              ),
            if (!closed && active && withdrawal != 'Requested')
              Wrap(
                spacing: 8,
                children: [
                  if (!client)
                    TextButton(
                      onPressed: withdraw,
                      child: const Text('Request withdrawal'),
                    ),
                  if (client) ...[
                    TextButton(
                      onPressed: () => closeProject(false),
                      child: const Text('Close project'),
                    ),
                    TextButton(
                      onPressed: () => closeProject(true),
                      child: const Text('Cancel project'),
                    ),
                  ],
                ],
              ),
          ],
        );
      },
    ),
  );
}

Future<void> openSafetyReport(
  BuildContext context,
  ProfessionalRepository repository,
  String actorId,
  String projectId,
) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _SafetyReportDialog(
      repository: repository,
      actorId: actorId,
      projectId: projectId,
    ),
  );
}

class _SafetyReportDialog extends StatefulWidget {
  const _SafetyReportDialog({
    required this.repository,
    required this.actorId,
    required this.projectId,
  });
  final ProfessionalRepository repository;
  final String actorId, projectId;
  @override
  State<_SafetyReportDialog> createState() => _SafetyReportDialogState();
}

class _SafetyReportDialogState extends State<_SafetyReportDialog> {
  String category = SafetyReport.categories.first;
  final details = TextEditingController();
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Report a problem'),
    content: Form(
      key: form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Saved privately on this device. Status: Awaiting demo review. No real moderation service is contacted.',
            ),
            DropdownButtonFormField<String>(
              initialValue: category,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Category'),
              items: SafetyReport.categories
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (s) => setState(() => category = s!),
            ),
            TextFormField(
              controller: details,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Describe the problem',
              ),
              validator: (s) => s == null || s.trim().length < 10
                  ? 'Use at least 10 characters'
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!form.currentState!.validate()) return;
          try {
            widget.repository.createReport(
              widget.actorId,
              widget.projectId,
              category,
              details.text,
            );
            Navigator.pop(context);
          } catch (error) {
            professionalAction(context, () => throw error);
          }
        },
        child: const Text('Save private report'),
      ),
    ],
  );
}

class MySafetyReportsScreen extends StatelessWidget {
  const MySafetyReportsScreen({
    super.key,
    required this.repository,
    required this.actorId,
  });
  final ProfessionalRepository repository;
  final String actorId;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My private reports')),
    body: AnimatedBuilder(
      animation: repository,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Only reports submitted by this account are displayed. Offline demo review is not real moderation.',
          ),
          if (repository.reportsFor(actorId).isEmpty)
            const Text('No reports submitted.'),
          for (final report in repository.reportsFor(actorId))
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      repository.project(report.projectId).title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(report.category),
                    Text(report.details),
                    Text(report.status),
                    if (report.reviewNote.isNotEmpty) Text(report.reviewNote),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
