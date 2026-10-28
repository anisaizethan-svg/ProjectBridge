import '../data/project_knowledge_base.dart';
import '../models/smart_project_analysis.dart';

class ProjectAssistantException implements Exception {
  const ProjectAssistantException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract interface class ProjectAssistantService {
  bool get isConfigured;
  Future<SmartProjectAnalysis> analyze(
    String description, {
    Map<String, String> clarificationAnswers = const {},
  });
}

class LocalSmartProjectAssistantService implements ProjectAssistantService {
  const LocalSmartProjectAssistantService();

  @override
  bool get isConfigured => true;

  @override
  Future<SmartProjectAnalysis> analyze(
    String description, {
    Map<String, String> clarificationAnswers = const {},
  }) async {
    final original = description.trim();
    if (original.length < 20) {
      throw const ProjectAssistantException(
        'Please describe the project in at least 20 characters.',
      );
    }
    final answers = clarificationAnswers.values
        .where((answer) => answer.trim().isNotEmpty)
        .join('. ');
    final input = '$original ${answers.isEmpty ? '' : answers}';
    final normalized = _normalize(input);
    final language = _language(normalized);
    final rankedCategories = _rankCategories(normalized);
    final features = _matchedFeatures(normalized);
    final detected = features.map((rule) => rule.label).toList();
    final primary = rankedCategories.isEmpty ? null : rankedCategories.first;
    final score = primary?.score ?? 0;
    final confidence = score >= 9
        ? 92
        : score >= 6
        ? 82
        : score >= 3
        ? 68
        : score > 0
        ? 48
        : 18;
    final lowConfidence = confidence < 60;
    final categories = rankedCategories
        .where((result) => result.score >= 3 && result.score >= score * .2)
        .take(4)
        .map((result) => result.rule.label)
        .toList();
    final title = _suggestTitle(normalized, primary?.rule.label, language);
    final questions = _questions(
      normalized,
      primary?.rule.label,
      features,
      lowConfidence,
      language,
    );
    final riskItems = <String>[];
    final hasSensitive = detected.contains('Sensitive personal data');
    final hasCritical = detected.contains('High-security requirements');
    final hasPayment = detected.contains('Online payments');
    if (hasSensitive) {
      riskItems.add(
        _text(
          language,
          'Sensitive information needs a qualified mentor and strict privacy review.',
          'Для работы с чувствительными данными нужны наставник и строгая проверка приватности.',
          'Сезімтал деректер үшін тәлімгер және қатаң құпиялылық тексеруі қажет.',
        ),
      );
    }
    if (hasCritical) {
      riskItems.add(
        _text(
          language,
          'High-security or critical systems are not suitable for an unsupervised student project.',
          'Системы с высокими требованиями безопасности нельзя разрабатывать студентам без надзора.',
          'Қауіпсіздігі жоғары немесе маңызды жүйелерді студенттің тәлімгерсіз әзірлеуі жарамайды.',
        ),
      );
    }
    if (hasPayment) {
      riskItems.add(
        _text(
          language,
          'Use a payment provider sandbox; never handle card credentials directly.',
          'Используйте тестовый режим платежного провайдера и не обрабатывайте данные карт напрямую.',
          'Төлем провайдерінің тест режимін қолданыңыз; карта деректерін тікелей өңдемеңіз.',
        ),
      );
    }
    if (riskItems.isEmpty) {
      riskItems.add(
        _text(
          language,
          'Confirm scope, content ownership, and review cadence with the client before work starts.',
          'До начала работы согласуйте объём, права на материалы и регулярность проверки с заказчиком.',
          'Жұмыс басталмай тұрып көлемді, материалдарға құқықты және тексеру жиілігін тапсырыс берушімен келісіңіз.',
        ),
      );
    }
    final isUnclear = primary == null;
    final difficulty = _difficulty(features, detected, lowConfidence, language);
    final skills = _skills(categories, features, normalized);
    final roles = _roles(categories, features, language);
    final tasks = _tasks(categories, detected, language);
    final deliverables = _deliverables(categories, detected, language);
    final technologies = _technologies(categories, detected);
    final timeline = _timeline(difficulty, language);
    final conflictNotes = _conflicts(normalized, language);
    final categoryName = isUnclear
        ? _text(
            language,
            'Needs clarification',
            'Требуется уточнение',
            'Нақтылау қажет',
          )
        : primary.rule.label;

    return SmartProjectAnalysis(
      originalDescription: original,
      title: title,
      category: categoryName,
      additionalCategories: categories
          .where((category) => category != categoryName)
          .toList(),
      conflictNotes: conflictNotes,
      description: original,
      problemToSolve: _problem(categories, language),
      requiredSkills: skills,
      suggestedTechnologies: technologies,
      difficulty: difficulty,
      difficultyReason: _difficultyReason(features, detected, language),
      suggestedRoles: roles,
      estimatedTeamSize: (roles.length).clamp(1, 5),
      deliverables: deliverables,
      suggestedTasks: tasks,
      acceptanceCriteria: _acceptance(detected, language),
      estimatedTimeline: timeline,
      clarifyingQuestions: questions,
      risksAndAssumptions: riskItems,
      detectedFeatures: detected,
      confidencePercent: confidence,
      confidenceLabel: lowConfidence
          ? _text(
              language,
              'Low confidence',
              'Низкая уверенность',
              'Сенімділік төмен',
            )
          : confidence < 80
          ? _text(
              language,
              'Medium confidence',
              'Средняя уверенность',
              'Орташа сенімділік',
            )
          : _text(
              language,
              'High confidence',
              'Высокая уверенность',
              'Сенімділік жоғары',
            ),
      rulesVersion: 'smart-rules-v1',
    );
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('ё', 'е')
      .replaceAll(RegExp(r'[’‘`´]'), "'")
      .replaceAll(RegExp(r'[^\p{L}\p{N}+#]+', unicode: true), ' ')
      .trim();

  static _Language _language(String text) {
    if (RegExp(r'[әіңғүұқөһ]').hasMatch(text)) return _Language.kk;
    if (RegExp(r'[а-я]').hasMatch(text)) return _Language.ru;
    return _Language.en;
  }

  static String _text(_Language language, String en, String ru, String kk) =>
      switch (language) {
        _Language.en => en,
        _Language.ru => ru,
        _Language.kk => kk,
      };

  static bool _contains(String text, String term) {
    final normalizedTerm = _normalize(term);
    if (normalizedTerm.isEmpty) return false;
    if (normalizedTerm.contains(' ')) {
      final wanted = normalizedTerm.split(' ');
      final tokens = text.split(' ');
      for (var start = 0; start <= tokens.length - wanted.length; start++) {
        var matches = true;
        for (var offset = 0; offset < wanted.length; offset++) {
          if (!_wordMatches(tokens[start + offset], wanted[offset])) {
            matches = false;
            break;
          }
        }
        if (matches) return true;
      }
      return false;
    }
    final tokens = text.split(' ');
    for (final token in tokens) {
      if (token == normalizedTerm) return true;
      // A small, language-neutral suffix trim handles common inflections
      // without relying on exact whole sentences or external NLP services.
      if (normalizedTerm.length >= 4 && token.startsWith(normalizedTerm)) {
        return true;
      }
      final stem = _stem(token);
      if (stem.length >= 4 && normalizedTerm.startsWith(stem)) return true;
    }
    return false;
  }

  static bool _wordMatches(String token, String word) {
    if (token == word) return true;
    if (word.length >= 4 && token.startsWith(word)) return true;
    final stem = _stem(token);
    return stem.length >= 4 && (stem == word || word.startsWith(stem));
  }

  static String _stem(String token) {
    const endings = [
      'иями',
      'ями',
      'ами',
      'ого',
      'ему',
      'ыми',
      'ими',
      'ого',
      'ая',
      'яя',
      'ое',
      'ее',
      'ый',
      'ий',
      'ой',
      'ые',
      'ие',
      'ов',
      'ев',
      'ам',
      'ям',
      'ах',
      'ях',
      'у',
      'а',
      'я',
      'и',
      'е',
      'ю',
      'ом',
      'ем',
      'ать',
      'ять',
      'ing',
      'ers',
      'ies',
      'ed',
      'es',
      's',
      'лар',
      'лер',
      'дар',
      'дер',
      'тар',
      'тер',
      'ның',
      'нің',
      'ға',
      'ге',
      'ды',
      'ді',
      'ты',
      'ті',
      'мен',
      'дан',
      'ден',
    ];
    for (final ending in endings) {
      if (token.length > ending.length + 3 && token.endsWith(ending)) {
        return token.substring(0, token.length - ending.length);
      }
    }
    return token;
  }

  static List<_CategoryScore> _rankCategories(String text) {
    final scores = <_CategoryScore>[];
    for (final rule in ProjectKnowledgeBase.categories) {
      var score = 0;
      for (final term in rule.terms) {
        if (_contains(text, term)) score += _termWeight(term, rule.weight);
      }
      if (rule.label == 'Restaurant QR Menus') {
        final menu =
            _contains(text, 'menu') ||
            _contains(text, 'меню') ||
            _contains(text, 'мәзір');
        final venue = [
          'cafe',
          'coffee shop',
          'restaurant',
          'кафе',
          'ресторан',
          'кофейня',
          'мейрамхана',
        ].any((term) => _contains(text, term));
        final qr = _contains(text, 'qr');
        if (menu && venue) score += 7;
        if (menu && qr) score += 9;
        if (menu && !venue && !qr) score = 0;
      }
      if (rule.label == 'Mobile Development' && _contains(text, 'menu')) {
        if (_contains(text, 'navigation menu') ||
            _contains(text, 'app menu') ||
            _contains(text, 'android')) {
          score += 5;
        }
      }
      if (rule.label == 'Mobile Development' &&
          [
            'web app',
            'web application',
            'веб-приложение',
          ].any((term) => _contains(text, term)) &&
          ![
            'mobile',
            'android',
            'ios',
            'телефон',
          ].any((term) => _contains(text, term))) {
        score = 0;
      }
      if (rule.label == 'Graphic Design' &&
          _contains(text, 'restaurant') &&
          _contains(text, 'logo')) {
        score += 3;
      }
      if (rule.label == 'Web Development' &&
          _contains(text, 'menu') &&
          _contains(text, 'qr')) {
        score += 7;
      }
      if (score > 0) scores.add(_CategoryScore(rule, score));
    }
    scores.sort((a, b) => b.score.compareTo(a.score));
    return scores;
  }

  static int _termWeight(String term, int base) =>
      term.contains(' ') ? base + 2 : base;

  static List<FeatureRule> _matchedFeatures(String text) => ProjectKnowledgeBase
      .features
      .where((rule) => rule.terms.any((term) => _contains(text, term)))
      .toList();

  static String _suggestTitle(
    String text,
    String? category,
    _Language language,
  ) {
    if (category == 'Restaurant QR Menus') {
      return _text(
        language,
        'Cafe QR Menu',
        'QR-меню кафе',
        'Кафенің QR мәзірі',
      );
    }
    if (category == 'Booking Systems') {
      final salon = [
        'salon',
        'beauty',
        'салон',
        'сұлулық',
      ].any((term) => _contains(text, term));
      return salon
          ? _text(
              language,
              'Salon Booking System',
              'Система записи в салон',
              'Салонға жазылу жүйесі',
            )
          : _text(
              language,
              'Appointment Booking System',
              'Система записи на приём',
              'Қабылдауға жазылу жүйесі',
            );
    }
    if (category == 'Graphic Design') {
      if (_contains(text, 'logo') || _contains(text, 'логотип')) {
        return _text(
          language,
          'Business Logo Design',
          'Дизайн логотипа',
          'Логотип дизайны',
        );
      }
      if (_contains(text, 'poster') ||
          _contains(text, 'плакат') ||
          _contains(text, 'афиша')) {
        return _text(
          language,
          'Event Poster Design',
          'Дизайн афиши',
          'Іс-шара постерінің дизайны',
        );
      }
    }
    if (category == 'E-commerce') {
      return _text(
        language,
        'Online Store',
        'Интернет-магазин',
        'Онлайн дүкен',
      );
    }
    if (category == 'Telegram Bot Development') {
      return _text(
        language,
        'Telegram Support Bot',
        'Бот поддержки в Telegram',
        'Telegram қолдау боты',
      );
    }
    if (category == 'Inventory Systems') {
      return _text(
        language,
        'Inventory Management System',
        'Система учёта запасов',
        'Қорларды басқару жүйесі',
      );
    }
    if (category == 'Educational Platforms') {
      return _text(
        language,
        'Online Learning Platform',
        'Образовательная платформа',
        'Онлайн оқыту платформасы',
      );
    }
    if (category == 'Landing Pages') {
      return _text(
        language,
        'Business Landing Page',
        'Лендинг для бизнеса',
        'Бизнеске арналған лендинг',
      );
    }
    if (category == 'Portfolio Websites') {
      return _text(
        language,
        'Personal Portfolio Website',
        'Сайт-портфолио',
        'Портфолио сайты',
      );
    }
    if (category == 'Dashboard / Admin Panels') {
      return _text(
        language,
        'Management Dashboard',
        'Панель управления',
        'Басқару панелі',
      );
    }
    if (category == 'Event Applications') {
      return _text(
        language,
        'Event Information App',
        'Приложение для мероприятий',
        'Іс-шараларға арналған қосымша',
      );
    }
    if (category == null) {
      return _text(
        language,
        'Project Idea — Needs Clarification',
        'Идея проекта — требуется уточнение',
        'Жоба идеясы — нақтылау қажет',
      );
    }
    return _text(
      language,
      'Project ${_shortLabel(category)}',
      'Проект: ${_shortLabel(category)}',
      'Жоба: ${_shortLabel(category)}',
    );
  }

  static String _shortLabel(String category) => switch (category) {
    'Web Development' => 'Website',
    'Mobile Development' => 'Mobile App',
    'UX/UI Design' => 'Interface Prototype',
    'Graphic Design' => 'Visual Design',
    'Backend Development' => 'Backend Service',
    'Full-Stack Development' => 'Full-Stack Application',
    'QA / Software Testing' => 'Software Testing',
    'Database Development' => 'Database',
    'Business Websites' => 'Business Website',
    _ => category,
  };

  static List<String> _questions(
    String text,
    String? category,
    List<FeatureRule> features,
    bool low,
    _Language language,
  ) {
    final questions = <String>[];
    if (low) {
      questions.add(
        _text(
          language,
          'What should the project help people do, and who will use it?',
          'Какую задачу должен решить проект и кто будет им пользоваться?',
          'Жоба қандай мәселені шешеді және оны кім қолданады?',
        ),
      );
    }
    if (category == 'Restaurant QR Menus' &&
        !_contains(text, 'ordering') &&
        !_contains(text, 'заказ') &&
        !_contains(text, 'тапсырыс')) {
      questions.add(
        _text(
          language,
          'Should customers only view the menu, or also place orders?',
          'Клиенты должны только смотреть меню или ещё и оформлять заказы?',
          'Клиенттер мәзірді ғана көре ме, әлде тапсырыс та бере ме?',
        ),
      );
    }
    if (category == 'Booking Systems' &&
        !_contains(text, 'website') &&
        !_contains(text, 'app') &&
        !_contains(text, 'приложен') &&
        !_contains(text, 'сайт')) {
      questions.add(
        _text(
          language,
          'Should this be a website, a mobile app, or both?',
          'Нужен сайт, мобильное приложение или оба варианта?',
          'Сайт керек пе, мобильді қосымша ма, әлде екеуі де керек пе?',
        ),
      );
    }
    if (features.any((feature) => feature.label == 'Online payments') &&
        !_contains(text, 'sandbox') &&
        !_contains(text, 'test mode')) {
      questions.add(
        _text(
          language,
          'Which payment provider should be used, and can the first version use its test mode?',
          'Какого платёжного провайдера использовать и можно ли начать с тестового режима?',
          'Қай төлем провайдерін қолдану керек және алғашқы нұсқада оның тест режимін пайдалануға бола ма?',
        ),
      );
    }
    if (category != null &&
        !_contains(text, 'admin') &&
        !_contains(text, 'админ') &&
        !_contains(text, 'әкімші')) {
      if (category == 'Restaurant QR Menus' ||
          category == 'Business Websites' ||
          category == 'E-commerce') {
        questions.add(
          _text(
            language,
            'Who will update the content after launch?',
            'Кто будет обновлять содержимое после запуска?',
            'Іске қосылғаннан кейін мазмұнды кім жаңартады?',
          ),
        );
      }
    }
    return questions.take(4).toList();
  }

  static List<String> _conflicts(String text, _Language language) {
    final conflicts = <String>[];
    final webOnly = [
      'website only',
      'only a website',
      'только сайт',
      'только вебсайт',
      'тек сайт',
      'веб-сайт қана',
    ].any((term) => _contains(text, term));
    final mobileRequested = [
      'mobile app',
      'android app',
      'ios app',
      'мобильное приложение',
      'мобильді қосымша',
    ].any((term) => _contains(text, term));
    if (webOnly && mobileRequested) {
      conflicts.add(
        _text(
          language,
          'The brief says website only and also requests a mobile app. Confirm whether one or both platforms are in scope.',
          'В описании одновременно указан только сайт и мобильное приложение. Уточните, нужна одна платформа или обе.',
          'Сипаттамада тек сайт және мобильді қосымша қатар көрсетілген. Бір платформа ма, әлде екеуі де керек пе — нақтылаңыз.',
        ),
      );
    }
    final noDatabase = [
      'without a database',
      'without database',
      'no database',
      'без базы данных',
      'деректер базасынсыз',
    ].any((term) => _contains(text, term));
    final persistentData = [
      'save user data',
      'store user data',
      'save orders',
      'save bookings',
      'сохранять данные',
      'хранить данные',
      'сохранять заказы',
      'деректерді сақтау',
      'тапсырыстарды сақтау',
    ].any((term) => _contains(text, term));
    if (noDatabase && persistentData) {
      conflicts.add(
        _text(
          language,
          'The brief excludes a database but also requires saved data. Clarify whether local storage or a database is acceptable.',
          'В описании требуется сохранять данные, но база данных исключена. Уточните, допустимо ли локальное хранение или нужна база.',
          'Сипаттамада деректерді сақтау керек, бірақ деректер базасы қолданылмасын делінген. Жергілікті сақтау жарай ма, әлде база қажет пе — нақтылаңыз.',
        ),
      );
    }
    return conflicts;
  }

  static String _difficulty(
    List<FeatureRule> features,
    List<String> detected,
    bool low,
    _Language language,
  ) {
    if (low) {
      return _text(
        language,
        'Difficulty requires clarification',
        'Сложность требует уточнения',
        'Күрделілікті нақтылау қажет',
      );
    }
    var points = features.fold<int>(0, (sum, feature) => sum + feature.weight);
    if (detected.contains('Database')) points++;
    if (detected.contains('API integration')) points++;
    if (detected.contains('Role-based access')) points++;
    if (detected.contains('Online payments')) points += 3;
    if (detected.contains('Sensitive personal data') ||
        detected.contains('High-security requirements')) {
      points += 5;
    }
    if (detected.contains('Online payments') ||
        detected.contains('Sensitive personal data') ||
        detected.contains('High-security requirements')) {
      return 'Advanced';
    }
    if (points <= 3) return 'Beginner';
    if (points <= 8) return 'Intermediate';
    return 'Advanced';
  }

  static String _difficultyReason(
    List<FeatureRule> features,
    List<String> detected,
    _Language language,
  ) {
    if (detected.contains('Sensitive personal data') ||
        detected.contains('High-security requirements')) {
      return _text(
        language,
        'This includes sensitive data or high-security requirements. A qualified mentor must review the scope; do not use real sensitive data in a student prototype.',
        'В проекте есть чувствительные данные или высокие требования безопасности. Объём должен проверить опытный наставник; не используйте реальные чувствительные данные в учебном прототипе.',
        'Жобада сезімтал деректер немесе қауіпсіздік талаптары жоғары. Ауқымды тәжірибелі тәлімгер тексеруі керек; оқу прототипінде нақты сезімтал деректерді қолданбаңыз.',
      );
    }
    if (detected.contains('Online payments')) {
      return _text(
        language,
        'Payment integration adds security and provider dependencies. Keep the first version in sandbox mode and request mentor review.',
        'Интеграция платежей добавляет требования к безопасности и зависимости от провайдера. Начните с тестового режима и попросите наставника проверить решение.',
        'Төлем интеграциясы қауіпсіздік талаптарын және провайдерге тәуелділікті арттырады. Алдымен тест режимін қолданып, тәлімгерге тексертіңіз.',
      );
    }
    if (features.length >= 6) {
      return _text(
        language,
        'Several connected features, data handling, or integrations increase implementation and testing effort. Split delivery into reviewed milestones.',
        'Несколько связанных функций, работа с данными или интеграции увеличивают объём разработки и тестирования. Разбейте работу на этапы с проверкой.',
        'Бірнеше байланысқан функция, деректерді өңдеу немесе интеграциялар әзірлеу мен тестілеу көлемін арттырады. Жұмысты тексерілетін кезеңдерге бөліңіз.',
      );
    }
    if (features.isEmpty) {
      return _text(
        language,
        'The description does not identify enough scope to estimate difficulty. Answer the questions or continue with this assumption marked.',
        'В описании недостаточно деталей для оценки сложности. Ответьте на вопросы или продолжите с отмеченным предположением.',
        'Сипаттамада күрделілікті бағалауға мәлімет жеткіліксіз. Сұрақтарға жауап беріңіз немесе белгіленген болжаммен жалғастырыңыз.',
      );
    }
    return _text(
      language,
      'The current scope looks bounded. The estimate can change when requirements and content are confirmed.',
      'Текущий объём выглядит ограниченным. Оценка изменится после уточнения требований и материалов.',
      'Қазіргі ауқым шектеулі көрінеді. Талаптар мен материалдар нақтыланса, бағалау өзгеруі мүмкін.',
    );
  }

  static List<String> _skills(
    List<String> categories,
    List<FeatureRule> features,
    String text,
  ) {
    final skills = <String>[];
    void add(String value) {
      if (!skills.contains(value)) skills.add(value);
    }

    if (categories.any(
      (x) => [
        'Web Development',
        'Landing Pages',
        'Business Websites',
        'Portfolio Websites',
        'Restaurant QR Menus',
      ].contains(x),
    )) {
      add('Responsive Design');
      add('HTML');
      add('CSS');
      if (features.any(
        (x) => [
          'Booking',
          'Shopping cart',
          'Search',
          'Filters',
          'Admin panel',
        ].contains(x.label),
      )) {
        add('JavaScript');
      }
    }
    if (categories.contains('Mobile Development')) {
      add('Mobile UI');
      add('Flutter');
      add('Dart');
    }
    if (categories.contains('UX/UI Design')) {
      add('Figma');
      add('Wireframing');
      add('Prototyping');
    }
    if (categories.contains('Graphic Design')) {
      add('Branding');
      add('Typography');
      add('Illustration');
    }
    if (categories.any(
      (x) => [
        'Backend Development',
        'Full-Stack Development',
        'Telegram Bot Development',
        'Booking Systems',
        'E-commerce',
        'Inventory Systems',
        'Educational Platforms',
        'Dashboard / Admin Panels',
      ].contains(x),
    )) {
      add('API and data modeling');
      if (features.any(
        (x) => ['Login', 'User registration'].contains(x.label),
      )) {
        add('Authentication');
      }
      if (features.any(
        (x) => [
          'Database',
          'Product catalog',
          'Booking',
          'Shopping cart',
        ].contains(x.label),
      )) {
        add('Database Design');
      }
    }
    if (categories.contains('QA / Software Testing')) {
      add('Test Cases');
      add('Manual Testing');
      add('Bug Reporting');
    }
    if (features.any((x) => x.label == 'Online payments')) {
      add('Payment Provider Sandbox Integration');
    }
    if (features.any((x) => x.label == 'Maps')) add('Maps API Integration');
    if (skills.isEmpty && text.contains(' ')) add('Requirements Analysis');
    return skills.take(8).toList();
  }

  static List<String> _technologies(
    List<String> categories,
    List<String> features,
  ) {
    final result = <String>[];
    void add(String item) {
      if (!result.contains(item)) result.add(item);
    }

    if (categories.any(
      (x) => [
        'Web Development',
        'Landing Pages',
        'Business Websites',
        'Portfolio Websites',
        'Restaurant QR Menus',
      ].contains(x),
    )) {
      add('HTML/CSS');
    }
    if (categories.contains('Mobile Development')) {
      add('Flutter (one possible cross-platform option)');
    }
    if (categories.contains('UX/UI Design') ||
        categories.contains('Graphic Design')) {
      add('Figma (design and prototype option)');
    }
    if (categories.contains('Telegram Bot Development')) {
      add('Telegram Bot API');
    }
    if (categories.any(
      (x) => ['Backend Development', 'Full-Stack Development'].contains(x),
    )) {
      add('REST API');
    }
    if (features.contains('Database')) {
      add('SQLite or Firebase (choose after data requirements are confirmed)');
    }
    if (features.contains('Online payments')) {
      add('Payment provider sandbox (provider to be selected)');
    }
    if (features.contains('Maps')) {
      add('Maps SDK/API (provider to be selected)');
    }
    if (result.isEmpty) add('Choose tools after clarifying the project scope.');
    return result;
  }

  static List<String> _roles(
    List<String> categories,
    List<FeatureRule> features,
    _Language language,
  ) {
    final roles = <String>[];
    if (categories.any((x) => ['UX/UI Design', 'Graphic Design'].contains(x))) {
      roles.add(
        _text(
          language,
          'UX/UI or graphic designer',
          'UX/UI- или графический дизайнер',
          'UX/UI немесе графикалық дизайнер',
        ),
      );
    }
    if (categories.any(
      (x) => [
        'Web Development',
        'Landing Pages',
        'Business Websites',
        'Portfolio Websites',
        'Restaurant QR Menus',
        'E-commerce',
      ].contains(x),
    )) {
      roles.add(
        _text(
          language,
          'Frontend developer',
          'Frontend-разработчик',
          'Frontend әзірлеушісі',
        ),
      );
    }
    if (categories.any(
      (x) => [
        'Backend Development',
        'Full-Stack Development',
        'Telegram Bot Development',
        'Booking Systems',
        'Inventory Systems',
        'Dashboard / Admin Panels',
      ].contains(x),
    )) {
      roles.add(
        _text(
          language,
          'Backend developer',
          'Backend-разработчик',
          'Backend әзірлеушісі',
        ),
      );
    }
    if (categories.contains('Mobile Development')) {
      roles.add(
        _text(
          language,
          'Mobile developer',
          'Разработчик мобильных приложений',
          'Мобильді қосымша әзірлеушісі',
        ),
      );
    }
    if (categories.contains('QA / Software Testing') || features.length > 3) {
      roles.add(
        _text(language, 'QA tester', 'QA-тестировщик', 'QA тестілеушісі'),
      );
    }
    if (roles.isEmpty) {
      roles.add(
        _text(
          language,
          'Project mentor / requirements reviewer',
          'Наставник / специалист по требованиям',
          'Жоба тәлімгері / талаптарды тексеруші',
        ),
      );
    }
    return roles.take(4).toList();
  }

  static List<String> _tasks(
    List<String> categories,
    List<String> features,
    _Language language,
  ) {
    final tasks = <String>[
      _text(
        language,
        'Confirm target users, scope, and success criteria with the client.',
        'Согласовать с заказчиком пользователей, объём и критерии успеха.',
        'Тапсырыс берушімен пайдаланушыларды, ауқымды және табыс өлшемдерін келісу.',
      ),
      _text(
        language,
        'Sketch the main user flow and review it before implementation.',
        'Набросать основной сценарий пользователя и согласовать до разработки.',
        'Негізгі пайдаланушы сценарийін сызып, әзірлеуге дейін келісу.',
      ),
    ];
    if (categories.contains('Graphic Design') ||
        categories.contains('UX/UI Design')) {
      tasks.add(
        _text(
          language,
          'Prepare editable visual concepts and collect feedback.',
          'Подготовить редактируемые визуальные варианты и собрать обратную связь.',
          'Өңделетін визуалды нұсқаларды дайындап, пікір жинау.',
        ),
      );
    }
    if (features.contains('Database') ||
        features.contains('User registration')) {
      tasks.add(
        _text(
          language,
          'Define the data fields and access rules; use sample data during development.',
          'Определить поля данных и правила доступа; при разработке использовать тестовые данные.',
          'Дерек өрістері мен қолжетімділік ережелерін анықтап, әзірлеуде үлгі деректерді пайдалану.',
        ),
      );
    }
    if (features.contains('Online payments')) {
      tasks.add(
        _text(
          language,
          'Prototype payment flow only in the provider sandbox and review it with a mentor.',
          'Создать сценарий оплаты только в тестовом режиме провайдера и проверить с наставником.',
          'Төлем сценарийін тек провайдердің тест ортасында жасап, тәлімгермен тексеру.',
        ),
      );
    }
    tasks.add(
      _text(
        language,
        'Test the agreed acceptance criteria and present the result to the client.',
        'Проверить согласованные критерии приёмки и показать результат заказчику.',
        'Келісілген қабылдау критерийлерін тексеріп, нәтижені тапсырыс берушіге көрсету.',
      ),
    );
    return tasks.take(6).toList();
  }

  static List<String> _deliverables(
    List<String> categories,
    List<String> features,
    _Language language,
  ) {
    final items = <String>[
      _text(
        language,
        'A reviewed project brief with agreed scope and assumptions.',
        'Согласованный бриф проекта с объёмом и предположениями.',
        'Ауқымы мен болжамдары келісілген жоба сипаттамасы.',
      ),
    ];
    if (categories.any((x) => ['UX/UI Design', 'Graphic Design'].contains(x))) {
      items.add(
        _text(
          language,
          'Editable design files and a short style guide.',
          'Редактируемые файлы дизайна и краткий гайд по стилю.',
          'Өңделетін дизайн файлдары және қысқа стиль нұсқаулығы.',
        ),
      );
    }
    if (categories.any(
      (x) => [
        'Web Development',
        'Mobile Development',
        'Landing Pages',
        'Business Websites',
        'Portfolio Websites',
        'Restaurant QR Menus',
        'E-commerce',
        'Educational Platforms',
        'Event Applications',
      ].contains(x),
    )) {
      items.add(
        _text(
          language,
          'A working prototype for the agreed target device or screen sizes.',
          'Рабочий прототип для согласованных устройств или размеров экрана.',
          'Келісілген құрылғыларға немесе экран өлшемдеріне арналған жұмыс прототипі.',
        ),
      );
    }
    if (features.contains('Database') ||
        features.contains('User registration')) {
      items.add(
        _text(
          language,
          'A documented data model using sample data.',
          'Документированная модель данных на тестовых данных.',
          'Үлгі деректермен құжатталған деректер моделі.',
        ),
      );
    }
    items.add(
      _text(
        language,
        'Test notes and a short handover/demo.',
        'Результаты тестирования и краткая передача/демо.',
        'Тестілеу жазбалары және қысқа таныстырылым/тапсыру.',
      ),
    );
    return items;
  }

  static List<String> _acceptance(
    List<String> features,
    _Language language,
  ) => [
    _text(
      language,
      'The agreed core user flow can be completed using the supplied test content.',
      'Согласованный основной сценарий можно пройти на предоставленных тестовых материалах.',
      'Келісілген негізгі сценарийді берілген сынақ материалдарымен орындауға болады.',
    ),
    _text(
      language,
      'The client reviews the result against the written scope and acceptance criteria.',
      'Заказчик проверяет результат по описанному объёму и критериям приёмки.',
      'Тапсырыс беруші нәтижені жазылған ауқым мен қабылдау критерийлері бойынша тексереді.',
    ),
    if (features.contains('Mobile responsiveness'))
      _text(
        language,
        'Key screens remain usable on the agreed mobile screen sizes.',
        'Основные экраны остаются удобными на согласованных размерах мобильного экрана.',
        'Негізгі экрандар келісілген мобильді өлшемдерде қолдануға ыңғайлы.',
      ),
  ];

  static String _problem(List<String> categories, _Language language) =>
      categories.isEmpty
      ? _text(
          language,
          'The need and intended users still need to be clarified.',
          'Потребность и целевые пользователи требуют уточнения.',
          'Қажеттілік пен мақсатты пайдаланушыларды нақтылау керек.',
        )
      : _text(
          language,
          'The client needs a clear, testable solution for ${_shortLabel(categories.first).toLowerCase()}.',
          'Заказчику нужно понятное и проверяемое решение: ${_shortLabel(categories.first).toLowerCase()}.',
          'Тапсырыс берушіге ${_shortLabel(categories.first).toLowerCase()} үшін түсінікті әрі тексерілетін шешім қажет.',
        );

  static String _timeline(
    String difficulty,
    _Language language,
  ) => switch (difficulty) {
    'Beginner' => _text(
      language,
      'About 2–4 weeks, assuming a small team and prompt client feedback.',
      'Около 2–4 недель при небольшой команде и своевременной обратной связи.',
      'Шағын топ және уақытылы кері байланыс болса, шамамен 2–4 апта.',
    ),
    'Intermediate' => _text(
      language,
      'About 4–8 weeks; confirm integrations and review points before setting dates.',
      'Около 4–8 недель; сроки интеграций и проверок нужно уточнить.',
      'Шамамен 4–8 апта; интеграциялар мен тексеру кезеңдерін нақтылау қажет.',
    ),
    'Advanced' => _text(
      language,
      'Do not set a delivery date until a mentor reviews the risks and scope.',
      'Не устанавливайте срок до проверки рисков и объёма наставником.',
      'Тәлімгер тәуекелдер мен ауқымды тексермейінше мерзім белгілемеңіз.',
    ),
    _ => _text(
      language,
      'Timeline requires clarification of users, features, and delivery scope.',
      'Сроки можно оценить после уточнения пользователей, функций и объёма.',
      'Пайдаланушылар, функциялар және жұмыс ауқымы нақтыланған соң мерзім бағаланады.',
    ),
  };
}

enum _Language { en, ru, kk }

class _CategoryScore {
  const _CategoryScore(this.rule, this.score);
  final KnowledgeRule rule;
  final int score;
}
