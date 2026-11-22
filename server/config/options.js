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

// How someone's swipe card looks (the card editor in the app).
export const CARD_COVERS = ['dusk', 'gold', 'midnight', 'parchment', 'circuit', 'photo'];
export const CARD_ACCENTS = ['crimson', 'gold', 'navy', 'teal', 'plum'];
export const CARD_FIELDS = ['superpowers', 'skills', 'interests', 'experience', 'schedule'];
export const DEFAULT_CARD_FIELDS = ['superpowers', 'skills', 'experience'];
export const MAX_CREW_SIZE = 4;
export const MIN_DECK_SCORE = 40;

// Hackathon hub: events and challenges. Kept out of OPTIONS so /api/options stays the profile chips.
export const EVENT_KINDS = ['event', 'challenge'];
export const EVENT_CATEGORIES = {
  event: ['workshop', 'talk', 'social', 'expo'],
  challenge: ['build', 'design', 'pitch', 'quiz'],
};
export const ENTRY_STATUSES = ['joined', 'submitted', 'completed'];
// Generated check-in codes skip look-alikes (I/1, O/0) so they read well off a projector.
export const CHECKIN_CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
export const CHECKIN_GRACE_MINUTES = 30;
