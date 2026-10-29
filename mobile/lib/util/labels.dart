import '../models/user.dart';

/// Human-friendly labels for the option values the API uses.
/// Kept in step with client/src/labels.js.
const _labels = {
  'frontend': 'Frontend',
  'backend': 'Backend',
  'fullstack': 'Full-stack',
  'designer': 'Designer',
  'ml': 'ML / AI',
  'pm': 'Product',
  'beginner': 'Beginner',
  'intermediate': 'Intermediate',
  'advanced': 'Advanced',
  'morning_person': 'Early bird',
  'night_owl': 'Night owl',
  'flexible': 'Flexible',
  'just_for_fun': 'Just for fun',
  'committed': 'Committed',
  'here_to_win': 'Here to win',
  'chat': 'Chat',
  'calls': 'Calls',
  'in_person': 'In person',
  'ai': 'AI',
  'climate': 'Climate',
  'education': 'Education',
  'fintech': 'Fintech',
  'gaming': 'Gaming',
  'health': 'Health',
  'productivity': 'Productivity',
  'social_impact': 'Social impact',
  'pitching': 'Pitching',
  'ui_design': 'UI design',
  'research': 'Research',
  'project_management': 'Project management',
  'video_editing': 'Video editing',
};

String optionLabel(String value) => _labels[value] ?? value.replaceAll('_', ' ');

/// Legends for the profile form's chip groups.
const fieldLabels = {
  'role': 'Your role',
  'experienceLevel': 'Experience',
  'schedule': 'Works best',
  'commitment': 'How serious',
  'communication': 'Talks by',
  'interests': 'What you care about',
  'superpowers': 'Superpowers',
};

/// The crew coverage checklist, in display order.
const checklistLabels = {
  'frontend': 'Frontend',
  'backend': 'Backend',
  'designer': 'Design',
  'pitching': 'Pitching',
};

/// "Designer · Intermediate · Night owl"
String personMeta(User person) => [
      person.role,
      person.experienceLevel,
      person.schedule,
    ].whereType<String>().map(optionLabel).join(' · ');

/// "Designer · Figma": role and best-known skill, for compact rows.
String roleAndSkill(User person) => [
      if (person.role != null) optionLabel(person.role!),
      if (person.skills.isNotEmpty) person.skills.first,
    ].join(' · ');

/// "tara_f.profile", the file name on a swipe card.
String profileFileName(String name) {
  final parts = name.toLowerCase().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return 'someone.profile';
  final initial = parts.length > 1 ? '_${parts.last[0]}' : '';
  return '${parts.first}$initial.profile';
}

/// "1 crew", "3 crews"
String plural(int count, String noun, [String? pluralNoun]) =>
    '$count ${count == 1 ? noun : pluralNoun ?? '${noun}s'}';
