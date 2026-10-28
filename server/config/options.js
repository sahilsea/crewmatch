// The allowed choices for every chip on the profile form.
// Web and mobile both fetch these from GET /api/options, so they never drift apart.
export const OPTIONS = {
  role: ['frontend', 'backend', 'fullstack', 'designer', 'ml', 'pm'],
  experienceLevel: ['beginner', 'intermediate', 'advanced'],
  schedule: ['morning_person', 'night_owl', 'flexible'],
  commitment: ['just_for_fun', 'committed', 'here_to_win'],
  communication: ['chat', 'calls', 'in_person'],
  interests: ['ai', 'climate', 'education', 'fintech', 'gaming', 'health', 'productivity', 'social_impact'],
  superpowers: ['pitching', 'ui_design', 'research', 'project_management', 'video_editing'],
};

export const MAX_SUPERPOWERS = 2;
export const MAX_CREW_SIZE = 4;
export const MIN_DECK_SCORE = 40;
