class SmartProjectAnalysis {
  SmartProjectAnalysis({
    required this.originalDescription,
    required this.title,
    required this.category,
    this.additionalCategories = const [],
    this.conflictNotes = const [],
    required this.description,
    required this.problemToSolve,
    required this.requiredSkills,
    required this.suggestedTechnologies,
    required this.difficulty,
    required this.difficultyReason,
    required this.suggestedRoles,
    required this.estimatedTeamSize,
    required this.deliverables,
    required this.suggestedTasks,
    required this.acceptanceCriteria,
    required this.estimatedTimeline,
    required this.clarifyingQuestions,
    required this.risksAndAssumptions,
    this.detectedFeatures = const [],
    this.confidencePercent = 50,
    this.confidenceLabel = 'Medium confidence',
    this.rulesVersion = 'smart-rules-v1',
  });

  final String originalDescription;
  String title, category, description, problemToSolve;
  List<String> additionalCategories;
  List<String> conflictNotes;
  List<String> requiredSkills, suggestedTechnologies;
  String difficulty, difficultyReason;
  List<String> suggestedRoles;
  int estimatedTeamSize;
  List<String> deliverables, suggestedTasks, acceptanceCriteria;
  String estimatedTimeline;
  List<String> clarifyingQuestions, risksAndAssumptions;
  List<String> detectedFeatures;
  int confidencePercent;
  String confidenceLabel;
  String rulesVersion;
}
