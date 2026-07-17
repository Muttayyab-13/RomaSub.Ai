// FrontEnd/test/widgets/dashboard/recent_projects_card_test.dart
//
// Pins the row content (name, transliteration flow copy, duration format),
// the empty state, and the View All callback. The card takes a plain list so
// no provider/fake is needed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/core/design/base_theme.dart';
import 'package:romasubai_frontend/widgets/dashboard/recent_projects_card.dart';

Widget _host({
  required List<Map<String, dynamic>> projects,
  void Function(Map<String, dynamic>)? onProjectTap,
  VoidCallback? onViewAll,
}) {
  return MaterialApp(
    theme: buildBaseTheme(false),
    home: Scaffold(
      body: RecentProjectsCard(
        projects: projects,
        onProjectTap: onProjectTap ?? (_) {},
        onViewAll: onViewAll ?? () {},
      ),
    ),
  );
}

void main() {
  testWidgets('renders a project row with name and transliteration flow', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        projects: [
          {
            'file_id': 'f1',
            'project_name': 'Interview_Raw_01',
            'original_filename': 'Interview_Raw_01.mp4',
            'is_video': true,
            'file_duration': 2720, // 45:20
            'created_at': '2026-07-17T10:42:00Z',
          },
        ],
      ),
    );
    expect(find.text('Interview_Raw_01'), findsOneWidget);
    expect(find.text('Urdu → Roman Urdu'), findsOneWidget);
    expect(find.text('45:20'), findsOneWidget);
  });

  testWidgets('formats an hour-plus duration as H:MM:SS', (tester) async {
    await tester.pumpWidget(
      _host(
        projects: [
          {
            'file_id': 'f2',
            'project_name': 'Podcast',
            'is_video': false,
            'file_duration': 4325, // 1:12:05
            'created_at': '2026-07-16T09:00:00Z',
          },
        ],
      ),
    );
    expect(find.text('1:12:05'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no projects', (
    tester,
  ) async {
    await tester.pumpWidget(_host(projects: const []));
    expect(find.text('No projects yet'), findsOneWidget);
  });

  testWidgets('View All fires its callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _host(projects: const [], onViewAll: () => tapped = true),
    );
    await tester.tap(find.text('View All'));
    expect(tapped, isTrue);
  });

  testWidgets('tapping a row fires onProjectTap with the project', (
    tester,
  ) async {
    Map<String, dynamic>? got;
    await tester.pumpWidget(
      _host(
        projects: [
          {
            'file_id': 'f9',
            'project_name': 'Clip',
            'is_video': true,
            'created_at': '2026-07-17T10:00:00Z',
          },
        ],
        onProjectTap: (p) => got = p,
      ),
    );
    await tester.tap(find.text('Clip'));
    expect(got?['file_id'], 'f9');
  });
}
