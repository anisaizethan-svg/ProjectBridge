import 'dart:math' as math;

import 'professional_models.dart';

/// Immutable inputs projected from the existing project and profile repositories.
class MatchProjectRequirements {
  const MatchProjectRequirements({
    required this.id,
    required this.requiredSkills,
    this.optionalSkills = const [],
    this.requiredRoles = const [],
    this.category = '',
    this.teamSize = 1,
    this.weeklyHours,
    this.duration = '',
  });
  final String id, category, duration;
  final List<String> requiredSkills, optionalSkills, requiredRoles;
  final int teamSize;
  final double? weeklyHours;
}

class MatchCandidate {
  const MatchCandidate(
    this.profile, {
    this.activeProjects = 0,
    this.relevantCompletedProjects = 0,
  });
  final ProfessionalProfile profile;
  final int activeProjects, relevantCompletedProjects;
}

class MatchWeights {
  const MatchWeights({
    this.skills = 45,
    this.roles = 25,
    this.capacity = 20,
    this.experience = 10,
  });
  final double skills, roles, capacity, experience;
  double get total => skills + roles + capacity + experience;
}

class MatchResult {
  const MatchResult({
    required this.studentId,
    required this.projectId,
    required this.score,
    required this.reliable,
    required this.eligible,
    required this.matchingSkills,
    required this.missingSkills,
    required this.suggestedRole,
    required this.explanations,
    required this.knownWeight,
  });
  final String studentId, projectId, suggestedRole;
  final int? score;
  final bool reliable, eligible;
  final double knownWeight;
  final List<String> matchingSkills, missingSkills, explanations;
  String get label => !reliable
      ? 'Not enough information to calculate a reliable match.'
      : '$score% match';
}

class TeamSlot {
  const TeamSlot({
    required this.role,
    required this.candidate,
    required this.match,
    required this.roleScore,
  });
  final String role;
  final MatchCandidate candidate;
  final MatchResult match;
  final double roleScore;
}

class TeamRecommendation {
  const TeamRecommendation({
    required this.members,
    required this.uncoveredRoles,
    required this.missingSkills,
  });
  final List<TeamSlot> members;
  final List<String> uncoveredRoles, missingSkills;
}

/// Transparent local scoring. No institution, name or sensitive attribute is used.
class TeamMatchingService {
  const TeamMatchingService({this.weights = const MatchWeights()});
  final MatchWeights weights;
  static const roleSkills = {
    'Web Developer': ['HTML', 'CSS', 'JavaScript', 'React'],
    'Mobile Developer': ['Flutter', 'Dart', 'Firebase'],
    'UI/UX Designer': ['UI/UX Design', 'Figma', 'Prototyping', 'User Research'],
    'Graphic Designer': ['Graphic Design', 'Branding', 'Illustrator'],
    'Backend Developer': ['Python', 'Backend Development', 'Database Design'],
    'Project Manager': ['Project Management'],
    'Content Creator': ['Content Creation', 'Video Editing'],
    'Tester': ['Testing'],
  };
  static String categoryRole(String category) {
    final key = Skill.key(category);
    if (key.contains('mobile')) return 'Mobile Developer';
    if (key.contains('web')) return 'Web Developer';
    if (key.contains('uiux')) return 'UI/UX Designer';
    if (key.contains('graphic') || key.contains('branding')) {
      return 'Graphic Designer';
    }
    if (key.contains('backend')) return 'Backend Developer';
    if (key.contains('test')) return 'Tester';
    if (key.contains('marketing') || key.contains('content')) {
      return 'Content Creator';
    }
    return '';
  }

  List<String> rolesFor(MatchProjectRequirements project) =>
      project.requiredRoles.isNotEmpty
      ? Skill.clean(project.requiredRoles)
      : [
          if (categoryRole(project.category).isNotEmpty)
            categoryRole(project.category),
        ];

  double roleFit(String role, ProfessionalProfile p) {
    final desired = Skill.key(role);
    final preferred = p.preferredRoles.any((r) => Skill.key(r) == desired);
    final canonical = roleSkills.keys
        .where((r) => Skill.key(r) == desired)
        .firstOrNull;
    final capabilities = canonical == null
        ? <String>[role]
        : roleSkills[canonical]!;
    final keys = p.skills.map(Skill.key).toSet();
    final skillRatio =
        capabilities.where((s) => keys.contains(Skill.key(s))).length /
        capabilities.length;
    final specialization = categoryRole(p.specialization);
    if (skillRatio == 0) return 0;
    return math.max(
      skillRatio,
      preferred
          ? 1
          : specialization.isNotEmpty && Skill.key(specialization) == desired
          ? .8
          : 0,
    );
  }

  static const broadSkillRoles = {
    'webdevelopment': 'Web Developer',
    'mobiledevelopment': 'Mobile Developer',
    'backenddevelopment': 'Backend Developer',
  };
  bool supportsSkills(String requirement, Iterable<String> storedSkills) {
    final keys = storedSkills.map(Skill.key).toSet();
    final key = Skill.key(requirement);
    if (keys.contains(key)) return true;
    final role = broadSkillRoles[key];
    if (role == null) return false;
    final capabilities = roleSkills[role]!;
    final count = capabilities.where((s) => keys.contains(Skill.key(s))).length;
    return count >= 2 && count / capabilities.length >= .5;
  }

  MatchResult score(
    MatchProjectRequirements project,
    MatchCandidate candidate,
  ) {
    final p = candidate.profile;
    final required = Skill.clean(project.requiredSkills);
    final keys = p.skills.map(Skill.key).toSet();
    final matched = required.where((s) => supportsSkills(s, p.skills)).toList();
    final missing = required
        .where((s) => !supportsSkills(s, p.skills))
        .toList();
    final roles = rolesFor(project);
    double? skillScore = required.isEmpty || p.skills.isEmpty
        ? null
        : matched.length / required.length;
    if (skillScore != null && project.optionalSkills.isNotEmpty) {
      final optional = Skill.clean(project.optionalSkills);
      final bonus =
          optional.where((s) => supportsSkills(s, p.skills)).length /
          optional.length *
          .1;
      skillScore = math.min(1, skillScore + bonus);
    }
    final roleScore = roles.isEmpty || p.skills.isEmpty
        ? null
        : roles.map((r) => roleFit(r, p)).reduce(math.max);
    final reasons = <String>[
      'Required skills: ${matched.length}/${required.length}${matched.isEmpty ? '' : ' · ${matched.join(', ')}'}.',
      if (missing.isNotEmpty) 'Missing required skills: ${missing.join(', ')}.',
      if (required.isEmpty) 'Project required skills are not specified.',
    ];
    for (final skill in matched.where((s) => !keys.contains(Skill.key(s)))) {
      final evidence = roleSkills[broadSkillRoles[Skill.key(skill)]!]!
          .where((s) => keys.contains(Skill.key(s)))
          .join(', ');
      reasons.add(
        '$skill recognized from declared technical skills: $evidence. This does not imply verified experience.',
      );
    }
    double? capacity;
    final eligible =
        p.availability != Availability.unavailable &&
        p.weeklyHours != 0 &&
        candidate.activeProjects < 3;
    if (p.availability == Availability.unknown && p.weeklyHours == null) {
      reasons.add(
        'Availability and weekly hours are unknown; confirm them before inviting.',
      );
    } else {
      final availability = switch (p.availability) {
        Availability.available => 1.0,
        Availability.limited => .5,
        Availability.unavailable => 0.0,
        Availability.unknown => .5,
      };
      final hoursRatio = project.weeklyHours != null && p.weeklyHours != null
          ? (p.weeklyHours! / project.weeklyHours!).clamp(0, 1).toDouble()
          : availability;
      capacity =
          (availability + hoursRatio) / 2 / (1 + candidate.activeProjects);
      reasons.add(
        'Availability: ${p.availability.name}; ${p.weeklyHours == null ? 'weekly hours unknown' : '${p.weeklyHours} h/week'}; ${candidate.activeProjects} active projects.',
      );
    }
    if (!eligible) {
      reasons.add(
        p.availability == Availability.unavailable
            ? 'Not currently available; excluded from suggested teams.'
            : 'Already has 3 or more active projects; excluded from suggested teams.',
      );
    }
    final experience = math.min(1.0, candidate.relevantCompletedProjects / 3);
    reasons.add(
      '${candidate.relevantCompletedProjects} relevant client-confirmed demo completions. Independent work is shown separately.',
    );
    final components = [
      (skillScore, weights.skills),
      (roleScore, weights.roles),
      (capacity, weights.capacity),
      (experience, weights.experience),
    ];
    final known = components
        .where((c) => c.$1 != null)
        .fold<double>(0, (sum, c) => sum + c.$2);
    final sum = components
        .where((c) => c.$1 != null)
        .fold<double>(0, (sum, c) => sum + c.$1! * c.$2);
    final reliable =
        (skillScore != null || roleScore != null) &&
        known >= weights.total * .7 &&
        weights.total > 0;
    var suggested = roles.isEmpty
        ? ''
        : (roles.toList()
                ..sort((a, b) => roleFit(b, p).compareTo(roleFit(a, p))))
              .first;
    if (suggested.isNotEmpty && roleFit(suggested, p) == 0) suggested = '';
    if (suggested.isNotEmpty) {
      reasons.add(
        'Suggested role: $suggested · ${(roleFit(suggested, p) * 100).round()}% role compatibility from skills, specialization and preferred roles.',
      );
    }
    if (known < weights.total) {
      reasons.add(
        'Missing data is excluded from the score; ${known.round()}/${weights.total.round()} weight points are known.',
      );
    }
    return MatchResult(
      studentId: p.id,
      projectId: project.id,
      score: known == 0 ? null : (sum / known * 100).round(),
      reliable: reliable,
      eligible: eligible,
      matchingSkills: List.unmodifiable(matched),
      missingSkills: List.unmodifiable(missing),
      suggestedRole: suggested,
      explanations: List.unmodifiable(reasons),
      knownWeight: known,
    );
  }

  List<MatchResult> rank(
    MatchProjectRequirements project,
    List<MatchCandidate> candidates,
  ) => candidates.map((c) => score(project, c)).toList()
    ..sort((a, b) {
      if (a.eligible != b.eligible) return a.eligible ? -1 : 1;
      if (a.reliable != b.reliable) return a.reliable ? -1 : 1;
      final comparison = (b.score ?? -1).compareTo(a.score ?? -1);
      return comparison == 0 ? a.studentId.compareTo(b.studentId) : comparison;
    });

  TeamRecommendation buildTeam(
    MatchProjectRequirements project,
    List<MatchCandidate> candidates,
  ) {
    final roles = rolesFor(project);
    final ranked = rank(project, candidates);
    final byId = {for (final c in candidates) c.profile.id: c};
    final eligible = ranked
        .where((m) => m.eligible)
        .map((m) => byId[m.studentId]!)
        .toList();
    final matches = {for (final m in ranked) m.studentId: m};
    final memo = <String, (double, List<TeamSlot>)>{};
    (double, List<TeamSlot>) assign(int roleIndex, int used, int remaining) {
      if (roleIndex >= roles.length || remaining <= 0) return (0, <TeamSlot>[]);
      final key = '$roleIndex:$used:$remaining';
      if (memo.containsKey(key)) return memo[key]!;
      var best = assign(roleIndex + 1, used, remaining);
      for (var index = 0; index < eligible.length; index++) {
        if ((used & (1 << index)) != 0) continue;
        final candidate = eligible[index];
        final fit = roleFit(roles[roleIndex], candidate.profile);
        if (fit < .34) {
          continue; // An unrelated candidate does not cover a role.
        }
        final tail = assign(roleIndex + 1, used | (1 << index), remaining - 1);
        final match = matches[candidate.profile.id]!;
        final value = 1000 + fit * 60 + (match.score ?? 0) * .4 + tail.$1;
        if (value > best.$1) {
          best = (
            value,
            [
              TeamSlot(
                role: roles[roleIndex],
                candidate: candidate,
                match: match,
                roleScore: fit,
              ),
              ...tail.$2,
            ],
          );
        }
      }
      memo[key] = best;
      return best;
    }

    final members = assign(
      0,
      0,
      project.teamSize.clamp(0, roles.length).toInt(),
    ).$2;
    final coveredRoles = members.map((m) => m.role).toSet();
    return TeamRecommendation(
      members: List.unmodifiable(members),
      uncoveredRoles: List.unmodifiable(
        roles.where((r) => !coveredRoles.contains(r)),
      ),
      missingSkills: List.unmodifiable(
        Skill.clean(project.requiredSkills).where(
          (s) => !members.any(
            (m) => supportsSkills(s, m.candidate.profile.skills),
          ),
        ),
      ),
    );
  }
}
