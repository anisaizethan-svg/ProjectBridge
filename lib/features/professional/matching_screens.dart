part of '../../main.dart';

extension ProfessionalMatching on ProfessionalRepository {
  static const matcher = TeamMatchingService();
  MatchProjectRequirements requirements(BridgeProject p) =>
      MatchProjectRequirements(
        id: p.id,
        requiredSkills: p.requiredSkills.isEmpty ? p.skills : p.requiredSkills,
        optionalSkills: p.optionalSkills,
        requiredRoles: p.requiredRoles,
        category: p.category,
        teamSize: p.teamSize,
        weeklyHours: p.weeklyCommitment,
        duration: p.estimatedTimeline ?? 'Not specified',
      );
  List<MatchCandidate> candidatesFor(BridgeProject p) =>
      profiles.map((profile) {
        final required = requirements(p).requiredSkills.map(Skill.key).toSet();
        return MatchCandidate(
          profile,
          activeProjects: projects()
              .where(
                (other) =>
                    other.acceptedParticipantIds.contains(profile.id) &&
                    !other.completed &&
                    !['Cancelled', 'Closed'].contains(other.lifecycleStatus),
              )
              .length,
          relevantCompletedProjects: passportsFor(profile.id)
              .where(
                (passport) =>
                    passport.skills.any((s) => required.contains(Skill.key(s))),
              )
              .length,
        );
      }).toList();
  MatchResult matchFor(BridgeProject p, String profileId) => matcher.score(
    requirements(p),
    candidatesFor(p).firstWhere((c) => c.profile.id == profileId),
  );
  void saveMatchingRequirements(
    String actorId,
    String projectId,
    Map<String, String> values,
  ) {
    final p = project(projectId);
    requireClient(actorId, p);
    requireActive(p);
    final size = int.tryParse(values['Team size'] ?? '');
    final hoursText = values['Hours per week'] ?? '';
    final hours = double.tryParse(hoursText);
    if (size == null ||
        size < 1 ||
        size > 5 ||
        (hoursText.isNotEmpty && (hours == null || hours <= 0 || hours > 80))) {
      throw StateError(
        'Use a team size of 1–5 and optional weekly hours of 1–80.',
      );
    }
    final roles = Skill.clean((values['Required roles'] ?? '').split(','));
    if (roles.length > 8) {
      throw StateError('Use up to eight distinct required roles.');
    }
    final skills = Skill.clean((values['Required skills'] ?? '').split(','));
    p.requiredSkills = skills;
    p.skills
      ..clear()
      ..addAll(skills);
    p.optionalSkills = Skill.clean(
      (values['Optional skills'] ?? '').split(','),
    );
    p.requiredRoles = roles;
    p.teamSize = size;
    p.weeklyCommitment = hours;
    p.estimatedTimeline = values['Estimated duration'];
    final existing = _agreements[p.id];
    if (existing != null) {
      _agreements[p.id] = ProjectAgreement(
        projectId: p.id,
        version: existing.version + 1,
        terms: {
          ...existing.terms,
          'Weekly commitment': hours == null
              ? 'To be agreed'
              : '$hours hours/week',
        },
      );
    }
    _record(
      actorId,
      p,
      'Updated structured matching requirements. Existing membership was not changed.',
    );
    changed();
  }
}

String actualMatchLabel(BuildContext context, BridgeProject project) {
  final repo = ProfessionalScope.maybeOf(context);
  if (repo == null) return 'Match not calculated';
  final result = repo.matchFor(project, 'student-daria');
  return result.reliable
      ? 'Profile match · ${result.score}%'
      : 'Match needs more information';
}

class TeamMatchingScreen extends StatelessWidget {
  const TeamMatchingScreen({
    super.key,
    required this.repository,
    required this.projectId,
    required this.actorId,
  });
  final ProfessionalRepository repository;
  final String projectId, actorId;
  Future<void> editRequirements(BuildContext context, BridgeProject p) async {
    final values = await textFieldsDialog(
      context,
      'Team requirements',
      {
        'Required skills': p.requiredSkills.join(', '),
        'Optional skills': p.optionalSkills.join(', '),
        'Required roles': p.requiredRoles.join(', '),
        'Team size': '${p.teamSize}',
        'Hours per week': p.weeklyCommitment?.toString() ?? '',
        'Estimated duration': p.estimatedTimeline ?? '',
      },
      requiredKeys: {'Team size'},
    );
    if (values != null && context.mounted) {
      professionalAction(
        context,
        () => repository.saveMatchingRequirements(actorId, p.id, values),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Find Team Members')),
    body: AnimatedBuilder(
      animation: repository,
      builder: (context, _) {
        final p = repository.project(projectId);
        if (actorId != p.clientId) {
          return const Center(
            child: Text(
              'Only the project owner can manage team recommendations.',
            ),
          );
        }
        final requirements = repository.requirements(p);
        final candidates = repository
            .candidatesFor(p)
            .where(
              (c) =>
                  repository.settings?.canViewProfile(
                    actorId,
                    c.profile.id,
                    repository.projects(),
                  ) ??
                  true,
            )
            .map((c) {
              if (repository.settings?.canViewAvailability(
                    actorId,
                    c.profile.id,
                    repository.projects(),
                  ) ??
                  true) {
                return c;
              }
              return MatchCandidate(
                c.profile.withChanges({
                  'availability': Availability.unknown.name,
                  'weeklyHours': null,
                }),
                activeProjects: c.activeProjects,
                relevantCompletedProjects: c.relevantCompletedProjects,
              );
            })
            .toList();
        const service = TeamMatchingService();
        final ranked = service.rank(requirements, candidates);
        final team = service.buildTeam(requirements, candidates);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(p.title, style: Theme.of(context).textTheme.titleLarge),
            const Text(
              'Local, rule-based suggestions · Fictional demo profiles · No automatic enrollment',
            ),
            const SizedBox(height: 12),
            ExpansionTile(
              title: const Text('How matching works'),
              children: const [
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Required skills 45% (optional skills add up to 10% within this component), role compatibility 25%, availability/workload 20%, relevant client-confirmed experience 10%. Unknown data is excluded and flagged. Institutions and sensitive attributes are never scored. Duration is shown for discussion; availability across the full period must be confirmed.',
                  ),
                ),
              ],
            ),
            Text(
              'Required: ${requirements.requiredSkills.join(', ')}\nOptional: ${requirements.optionalSkills.join(', ')}\nRoles: ${service.rolesFor(requirements).join(', ')}\nTeam size: ${p.teamSize} · Duration: ${requirements.duration}\nWeekly hours: ${p.weeklyCommitment ?? 'Not specified'}',
            ),
            if (![
              'Completed',
              'Closed',
              'Cancelled',
            ].contains(p.lifecycleStatus))
              TextButton.icon(
                onPressed: () => editRequirements(context, p),
                icon: const Icon(Icons.tune),
                label: const Text('Edit team requirements'),
              ),
            const SectionTitle('Suggested Team'),
            if (team.members.isEmpty)
              const Text(
                'No suitable role coverage yet. Add structured roles and skills, or update profile availability.',
              ),
            for (final slot in team.members)
              Card(
                child: ListTile(
                  title: Text('${slot.candidate.profile.name} — ${slot.role}'),
                  subtitle: Text(
                    '${(slot.roleScore * 100).round()}% role fit · ${slot.match.label}\nMatches actual skills: ${slot.candidate.profile.skills.join(', ')}',
                  ),
                  onTap: () => openProfessionalProfile(
                    context,
                    repository,
                    slot.candidate.profile.id,
                    actorId,
                  ),
                ),
              ),
            Text(
              'Uncovered roles: ${team.uncoveredRoles.isEmpty ? 'None' : team.uncoveredRoles.join(', ')}',
            ),
            Text(
              'Missing skills: ${team.missingSkills.isEmpty ? 'None' : team.missingSkills.join(', ')}',
            ),
            const Text(
              'Suggestions do not create an application, membership or chat. Students must apply and the client must accept through the existing workflow.',
            ),
            const SizedBox(height: 18),
            const SectionTitle('Ranked candidates'),
            for (final result in ranked)
              Card(
                child: ExpansionTile(
                  title: Text(
                    '${repository.profile(result.studentId).name} · ${result.label}',
                  ),
                  subtitle: Text(
                    '${result.suggestedRole.isEmpty ? 'No compatible required role' : result.suggestedRole}${result.eligible ? '' : ' · Not available for a new team'}',
                  ),
                  childrenPadding: const EdgeInsets.all(16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final reason in result.explanations)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(reason),
                      ),
                    TextButton(
                      onPressed: () => openProfessionalProfile(
                        context,
                        repository,
                        result.studentId,
                        actorId,
                      ),
                      child: const Text('View professional profile'),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    ),
  );
}

class RecommendedProjectsScreen extends StatelessWidget {
  const RecommendedProjectsScreen({
    super.key,
    required this.repository,
    required this.chatRepository,
    required this.onChanged,
    this.profileId = 'student-daria',
  });
  final ProfessionalRepository repository;
  final ChatRepository chatRepository;
  final VoidCallback onChanged;
  final String profileId;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Recommended Projects For You')),
    body: AnimatedBuilder(
      animation: repository,
      builder: (context, _) {
        final p = repository.profile(profileId);
        final entries =
            repository
                .projects()
                .where(
                  (p) =>
                      p.isPublished &&
                      !p.isArchived &&
                      p.lifecycleStatus == 'Published',
                )
                .map(
                  (project) =>
                      (project, repository.matchFor(project, profileId)),
                )
                .toList()
              ..sort((a, b) => (b.$2.score ?? -1).compareTo(a.$2.score ?? -1));
        final relevant = entries
            .where(
              (e) =>
                  e.$2.matchingSkills.isNotEmpty ||
                  (e.$2.suggestedRole.isNotEmpty &&
                      const TeamMatchingService().roleFit(
                            e.$2.suggestedRole,
                            p,
                          ) >
                          0),
            )
            .toList();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Based on ${p.name}’s saved profile. No external AI.'),
            if (p.skills.isEmpty)
              const Text(
                'Not enough information to calculate a reliable match. Add skills to your profile.',
              ),
            if (relevant.isEmpty)
              const Text(
                'No matching published projects yet. Update your skills or explore all projects.',
              ),
            for (final entry in relevant)
              Card(
                child: ExpansionTile(
                  title: Text(entry.$1.title),
                  subtitle: Text(entry.$2.label),
                  childrenPadding: const EdgeInsets.all(16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final reason in entry.$2.explanations) Text(reason),
                    TextButton(
                      onPressed: () => openProject(
                        context,
                        entry.$1,
                        onChanged,
                        chatRepository: chatRepository,
                        displayName: p.name,
                        skills: p.skills,
                      ),
                      child: const Text('Open project and apply'),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    ),
  );
}
