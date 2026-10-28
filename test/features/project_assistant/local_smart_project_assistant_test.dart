import 'package:flutter_test/flutter_test.dart';
import 'package:pr_bridge/features/project_assistant/services/local_smart_project_assistant.dart';

void main() {
  const assistant = LocalSmartProjectAssistantService();

  test('the service is ready offline and is deterministic', () async {
    expect(assistant.isConfigured, isTrue);
    const idea =
        'I own a coffee shop. I need a QR menu with photos and prices. I want to edit the menu myself.';
    final first = await assistant.analyze(idea);
    final second = await assistant.analyze(idea);
    expect(first.title, 'Cafe QR Menu');
    expect(first.category, 'Restaurant QR Menus');
    expect(first.additionalCategories, contains('Web Development'));
    expect(
      first.detectedFeatures,
      containsAll(['QR codes', 'Image uploads', 'Admin panel']),
    );
    expect(first, isNot(same(second)));
    expect(first.suggestedTasks, second.suggestedTasks);
    expect(first.rulesVersion, 'smart-rules-v1');
  });

  test(
    '20 English project examples map to useful overlapping categories',
    () async {
      final cases = <({String text, String category})>[
        (
          text: 'A cafe QR menu with editable prices and food photos.',
          category: 'Restaurant QR Menus',
        ),
        (
          text: 'A mobile app for salon bookings and appointment reminders.',
          category: 'Mobile Development',
        ),
        (
          text: 'A logo design for a restaurant brand.',
          category: 'Graphic Design',
        ),
        (text: 'A poster for a school event.', category: 'Graphic Design'),
        (
          text: 'An online shop with a product catalog and shopping cart.',
          category: 'E-commerce',
        ),
        (
          text: 'A Telegram customer support bot for my cafe.',
          category: 'Telegram Bot Development',
        ),
        (
          text: 'A UX/UI prototype for a healthcare app.',
          category: 'UX/UI Design',
        ),
        (
          text: 'A student attendance dashboard for teachers.',
          category: 'Dashboard / Admin Panels',
        ),
        (
          text: 'A website with appointment requests for a small business.',
          category: 'Booking Systems',
        ),
        (
          text: 'A mobile lost-and-found application for a college campus.',
          category: 'Mobile Development',
        ),
        (
          text: 'An inventory management system for a small warehouse.',
          category: 'Inventory Systems',
        ),
        (
          text: 'An online educational platform for self-paced courses.',
          category: 'Educational Platforms',
        ),
        (
          text:
              'A multilingual restaurant menu in Kazakh, Russian, and English.',
          category: 'Restaurant QR Menus',
        ),
        (
          text: 'A business website with an admin panel to update content.',
          category: 'Dashboard / Admin Panels',
        ),
        (
          text: 'A business landing page for a local design studio.',
          category: 'Landing Pages',
        ),
        (
          text: 'Appointment booking with SMS notifications for customers.',
          category: 'Booking Systems',
        ),
        (
          text: 'An app with maps for campus visitors.',
          category: 'Mobile Development',
        ),
        (
          text: 'An online store that accepts online payments.',
          category: 'E-commerce',
        ),
        (
          text: 'A software testing project with test cases and bug reports.',
          category: 'QA / Software Testing',
        ),
        (
          text: 'Please help me make something useful.',
          category: 'Needs clarification',
        ),
      ];
      for (final example in cases) {
        final analysis = await assistant.analyze(example.text);
        expect(
          [analysis.category, ...analysis.additionalCategories],
          contains(example.category),
          reason: 'Failed to classify: ${example.text}',
        );
      }
    },
  );

  test(
    'Russian and Kazakh terms match inflections and preserve output language',
    () async {
      final russian = await assistant.analyze(
        'Нужно мобильное приложение для записи клиентов в салон красоты с напоминаниями.',
      );
      expect([
        russian.category,
        ...russian.additionalCategories,
      ], contains('Mobile Development'));
      expect([
        russian.category,
        ...russian.additionalCategories,
      ], contains('Booking Systems'));
      expect(russian.difficultyReason, contains('Текущий'));
      expect(russian.detectedFeatures, contains('Notifications'));

      final kazakh = await assistant.analyze(
        'Кафеге арналған QR мәзірі, бағалар мен фотоларды өзім өзгертемін.',
      );
      expect(kazakh.category, 'Restaurant QR Menus');
      expect(kazakh.detectedFeatures, contains('QR codes'));
      expect(kazakh.title, contains('QR'));
      expect(kazakh.clarifyingQuestions, isNotEmpty);
    },
  );

  test(
    'menu context avoids confusing app navigation with a restaurant menu',
    () async {
      final navigation = await assistant.analyze(
        'I need a navigation menu for an Android app.',
      );
      expect(navigation.category, 'Mobile Development');
      expect(
        navigation.additionalCategories,
        isNot(contains('Restaurant QR Menus')),
      );

      final logo = await assistant.analyze(
        'Please design a logo for my restaurant.',
      );
      expect(logo.category, 'Graphic Design');
      expect(logo.additionalCategories, isNot(contains('Web Development')));

      final ambiguousMenu = await assistant.analyze(
        'I need a menu for my product.',
      );
      expect(
        ambiguousMenu.additionalCategories,
        isNot(contains('Restaurant QR Menus')),
      );
    },
  );

  test('extra Russian and Kazakh examples retain category coverage', () async {
    final examples = <({String text, String category})>[
      (
        text: 'Нужен логотип для ресторана и фирменный стиль.',
        category: 'Graphic Design',
      ),
      (
        text: 'Сделать школьную афишу для весеннего мероприятия.',
        category: 'Graphic Design',
      ),
      (
        text: 'Интернет-магазин с каталогом товаров и корзиной.',
        category: 'E-commerce',
      ),
      (
        text: 'Телеграм бот для поддержки покупателей.',
        category: 'Telegram Bot Development',
      ),
      (
        text: 'Панель управления для учёта товаров на складе.',
        category: 'Dashboard / Admin Panels',
      ),
      (
        text: 'Сайт-визитка для небольшой компании.',
        category: 'Business Websites',
      ),
      (
        text: 'Кафеге арналған QR мәзірі және баға тізімі.',
        category: 'Restaurant QR Menus',
      ),
      (
        text: 'Салонға жазылу қосымшасы және еске салу хабарландырулары.',
        category: 'Booking Systems',
      ),
      (
        text: 'Мейрамхана логотипін жасау және бренд түстерін таңдау.',
        category: 'Graphic Design',
      ),
      (
        text: 'Мектеп кешіне арналған постер дизайны.',
        category: 'Graphic Design',
      ),
      (
        text: 'Онлайн дүкен: тауарлар каталогы және сатып алу себеті.',
        category: 'E-commerce',
      ),
      (
        text: 'Telegram қолдау боты клиенттердің сұрақтарына жауап береді.',
        category: 'Telegram Bot Development',
      ),
      (
        text: 'Қойма қорларын басқару жүйесі және тауар есебі.',
        category: 'Inventory Systems',
      ),
      (
        text: 'Оқушыларға арналған онлайн оқыту платформасы.',
        category: 'Educational Platforms',
      ),
    ];
    for (final example in examples) {
      final result = await assistant.analyze(example.text);
      expect(
        [result.category, ...result.additionalCategories],
        contains(example.category),
        reason: 'Failed to classify: ${example.text}',
      );
    }
  });

  test(
    'payments and sensitive data require advanced estimates and mentor review',
    () async {
      final payment = await assistant.analyze(
        'An online store with a shopping cart that accepts online payments.',
      );
      expect(payment.difficulty, 'Advanced');
      expect(
        payment.risksAndAssumptions.join(' ').toLowerCase(),
        contains('sandbox'),
      );

      final health = await assistant.analyze(
        'A healthcare app that stores patient medical records.',
      );
      expect(health.detectedFeatures, contains('Sensitive personal data'));
      expect(health.difficulty, 'Advanced');
      expect(health.difficultyReason.toLowerCase(), contains('mentor'));
    },
  );

  test(
    'flags contradictory channel and storage requirements for clarification',
    () async {
      final channel = await assistant.analyze(
        'I need a website only, but also require a native Android mobile app for customers.',
      );
      expect(channel.conflictNotes, isNotEmpty);

      final storage = await assistant.analyze(
        'Build a booking site without a database but save user data for later.',
      );
      expect(storage.conflictNotes, isNotEmpty);
    },
  );

  test('clarification answers refine the same local analysis without losing source text', () async {
    final before = await assistant.analyze(
      'A salon booking system for customers who need appointment reminders.',
    );
    final after = await assistant.analyze(
      'A salon booking system for customers who need appointment reminders.',
      clarificationAnswers: {
        'Platform?': 'A mobile app with push notifications.',
      },
    );
    expect(after.originalDescription, before.originalDescription);
    expect(after.detectedFeatures, contains('Notifications'));
    expect([
      after.category,
      ...after.additionalCategories,
    ], contains('Mobile Development'));
  });

  test('rejects descriptions too short for meaningful analysis', () async {
    expect(
      () => assistant.analyze('A site'),
      throwsA(isA<ProjectAssistantException>()),
    );
  });
}
