part of '../../main.dart';

enum WeeklyAvailability {
  under5('Less than 5 hours/week'),
  fiveTo10('5–10 hours/week'),
  tenTo15('10–15 hours/week'),
  fifteenTo20('15–20 hours/week'),
  over20('More than 20 hours/week');

  const WeeklyAvailability(this.label);
  final String label;
  static WeeklyAvailability? fromHours(double? hours) =>
      hours == null || hours <= 0
      ? null
      : hours < 5
      ? under5
      : hours <= 10
      ? fiveTo10
      : hours <= 15
      ? tenTo15
      : hours <= 20
      ? fifteenTo20
      : over20;
}

class ApplicationValidation {
  static String? motivation(String? value) {
    final text = value?.trim() ?? '';
    if (text.length < 30) return 'Write at least 30 characters about your fit.';
    if (text.length > 1000) {
      return 'Keep your introduction within 1000 characters.';
    }
    if (text.split(RegExp(r'\s+')).length < 3) {
      return 'Describe your experience in a few words.';
    }
    return null;
  }

  static String? portfolio(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    return uri != null &&
            ['http', 'https'].contains(uri.scheme) &&
            uri.host.contains('.') &&
            !RegExp(r'\s').hasMatch(text) &&
            uri.userInfo.isEmpty
        ? null
        : 'Enter a valid http:// or https:// portfolio link.';
  }

  static List<String> matching(List<String> required, List<String> owned) =>
      Skill.clean(owned)
          .where((s) => required.any((r) => Skill.key(r) == Skill.key(s)))
          .toList();
}

Future<void> applyToProject(
  BuildContext context,
  BridgeProject project,
  VoidCallback changed,
  List<String> studentSkills, {
  required String applicantId,
  required String applicantName,
}) async {
  if (project.applied) return;
  final root = context.findAncestorStateOfType<_ProjectBridgeAppState>();
  final repository = ProfessionalScope.maybeOf(context);
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFFFAF9FF),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => ApplicationSheet(
      project: project,
      applicantId: applicantId,
      applicantName: applicantName,
      fallbackSkills: studentSkills,
      repository: repository,
      save: root?.saveApplicationSnapshot ?? () async {},
      editSkills: root?.editProfile,
    ),
  );
  if (result == true) {
    changed();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Application sent. Status: Pending.')),
      );
    }
  }
}

/// Holds the draft locally until submission is validated and storage acknowledges it.
class ApplicationSheet extends StatefulWidget {
  const ApplicationSheet({
    super.key,
    required this.project,
    required this.applicantId,
    required this.applicantName,
    required this.fallbackSkills,
    required this.save,
    this.repository,
    this.editSkills,
  });
  final BridgeProject project;
  final String applicantId, applicantName;
  final List<String> fallbackSkills;
  final ProfessionalRepository? repository;
  final Future<void> Function() save;
  final Future<void> Function()? editSkills;
  @override
  State<ApplicationSheet> createState() => _ApplicationSheetState();
}

class _ApplicationSheetState extends State<ApplicationSheet> {
  final form = GlobalKey<FormState>();
  final motivation = TextEditingController(), link = TextEditingController();
  final selected = <String>{}, portfolioIds = <String>{};
  WeeklyAvailability? availability;
  bool saving = false;
  String? error;
  ProfessionalProfile? get profile =>
      widget.repository?.profile(widget.applicantId);
  List<String> get skills =>
      Skill.clean(profile?.skills ?? widget.fallbackSkills);
  List<PortfolioProject> get portfolio =>
      widget.repository?.portfolioFor(widget.applicantId) ?? [];
  @override
  void initState() {
    super.initState();
    availability = WeeklyAvailability.fromHours(profile?.weeklyHours);
    selected.addAll(
      ApplicationValidation.matching(widget.project.requiredSkills, skills),
    );
    final urls = portfolio.where(
      (p) => p.url.isNotEmpty && ApplicationValidation.portfolio(p.url) == null,
    );
    if (urls.isNotEmpty) link.text = urls.first.url;
  }

  @override
  void dispose() {
    motivation.dispose();
    link.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (saving || !form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      saving = true;
      error = null;
    });
    // Snapshot supports rollback on storage failure without losing the draft.
    final before = DemoSnapshot.projectToJson(widget.project);
    try {
      if (widget.repository?.settings?.blocked(
            widget.applicantId,
            widget.project.clientId,
          ) ??
          false) {
        throw StateError(
          'Applications are unavailable between blocked accounts.',
        );
      }
      final ok = widget.project.submitApplication(
        studentId: widget.applicantId,
        name: profile?.name ?? widget.applicantName,
        studentSkills: skills.where(selected.contains).toList(),
        introduction: motivation.text.trim(),
        hours: availability!.label,
        availabilityCode: availability!.name,
        headline: profile?.headline,
        portfolio: link.text.trim().isEmpty ? null : link.text.trim(),
        portfolioProjects: portfolio
            .where((p) => portfolioIds.contains(p.id))
            .toList(),
      );
      if (!ok) {
        throw StateError(
          'Already applied or this project is no longer accepting applications.',
        );
      }
      try {
        await widget.save();
      } catch (_) {
        // Restore only application fields; preserve unrelated project state.
        widget.project
          ..applied = before['applied'] as bool
          ..applicantId = before['applicantId'] as String?
          ..applicantName = before['applicantName'] as String?
          ..applicantSkills = List<String>.from(
            before['applicantSkills'] as List,
          )
          ..applicationStatus = before['applicationStatus'] as String
          ..appliedAt = DateTime.parse(before['appliedAt'] as String)
          ..motivation = before['motivation'] as String?
          ..availability = before['availability'] as String?
          ..portfolioLink = before['portfolioLink'] as String?
          ..applicationAvailabilityCode =
              before['applicationAvailabilityCode'] as String?
          ..applicantHeadline = before['applicantHeadline'] as String?
          ..applicationPortfolio = (before['applicationPortfolio'] as List)
              .map(
                (p) => PortfolioProject.fromJson(
                  Map<String, dynamic>.from(p as Map),
                ),
              )
              .toList();
        rethrow;
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = e is StateError ? e.message : 'Your application could not be saved. Your draft is here; please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final matches = ApplicationValidation.matching(
      widget.project.requiredSkills,
      skills,
    );
    final missing = Skill.clean(widget.project.requiredSkills)
        .where((r) => !skills.any((s) => Skill.key(s) == Skill.key(r)))
        .toList();
    return PopScope(
      canPop: !saving,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .9,
            ),
            child: Form(
              key: form,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: SizedBox(width: 40, child: Divider(thickness: 4)),
                    ),
                    Text(
                      'Apply to project',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.project.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${widget.project.client} · ${widget.project.category}',
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      key: const Key('application-motivation'),
                      controller: motivation,
                      enabled: !saving,
                      minLines: 4,
                      maxLines: 7,
                      maxLength: 1000,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: const InputDecoration(
                        labelText: 'Why are you a good fit?',
                        alignLabelWithHint: true,
                        hintText: 'Introduce yourself, describe your relevant experience, and explain how you can help with this project.',
                      ),
                      validator: ApplicationValidation.motivation,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<WeeklyAvailability>(
                      initialValue: availability,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Weekly availability',
                      ),
                      items: WeeklyAvailability.values
                          .map(
                            (a) => DropdownMenuItem(
                              value: a,
                              child: Text(a.label),
                            ),
                          )
                          .toList(),
                      onChanged: saving
                          ? null
                          : (v) => setState(() => availability = v),
                      validator: (v) =>
                          v == null ? 'Select your weekly availability.' : null,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Matching skills',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (matches.isEmpty)
                      const Text(
                        'No matching skills found in your profile. You can still apply and explain your experience.',
                      ),
                    if (matches.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        children: matches.map(skillChip).toList(),
                      ),
                    if (missing.isNotEmpty)
                      Text(
                        'Skills to develop: ${missing.join(', ')}',
                        style: const TextStyle(color: muted),
                      ),
                    if (skills.any((s) => !matches.contains(s))) ...[
                      const SizedBox(height: 12),
                      const Text('Other profile skills to highlight'),
                      Wrap(
                        spacing: 8,
                        children: skills
                            .where((s) => !matches.contains(s))
                            .map(skillChip)
                            .toList(),
                      ),
                    ],
                    if (skills.isEmpty && widget.editSkills != null)
                      TextButton(
                        onPressed: saving
                            ? null
                            : () async {
                                await widget.editSkills!();
                                if (mounted) setState(() {});
                              },
                        child: const Text('Edit profile skills'),
                      ),
                    const SizedBox(height: 24),
                    TextFormField(
                      key: const Key('application-portfolio'),
                      controller: link,
                      enabled: !saving,
                      keyboardType: TextInputType.url,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: const InputDecoration(
                        labelText: 'Portfolio link (optional)',
                        hintText: 'https://github.com/username',
                      ),
                      validator: ApplicationValidation.portfolio,
                    ),
                    if (portfolio.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('Include portfolio projects (self-reported)'),
                      ...portfolio.map(
                        (p) => CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(p.title),
                          value: portfolioIds.contains(p.id),
                          onChanged: saving
                              ? null
                              : (v) => setState(() {
                                  if (v == true) {
                                    portfolioIds.add(p.id);
                                  } else {
                                    portfolioIds.remove(p.id);
                                  }
                                }),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const Text(
                      'What happens next?',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Text(
                      "The client will review your application. If accepted, you'll be able to communicate through your project chat.",
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: saving || widget.project.applied
                          ? null
                          : submit,
                      child: saving
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              widget.project.applied
                                  ? widget.project.applicationStatus
                                  : 'Submit application',
                            ),
                    ),
                    TextButton(
                      onPressed: saving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget skillChip(String skill) => FilterChip(
    label: Text(skill),
    selected: selected.contains(skill),
    onSelected: saving
        ? null
        : (v) => setState(() {
            if (v) {
              selected.add(skill);
            } else {
              selected.remove(skill);
            }
          }),
  );
}
