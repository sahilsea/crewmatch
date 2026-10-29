// Human-friendly labels for the option values the API uses.
const LABELS = {
  frontend: 'Frontend', backend: 'Backend', fullstack: 'Full-stack', designer: 'Designer', ml: 'ML / AI', pm: 'Product',
  beginner: 'Beginner', intermediate: 'Intermediate', advanced: 'Advanced',
  morning_person: 'Early bird', night_owl: 'Night owl', flexible: 'Flexible',
  just_for_fun: 'Just for fun', committed: 'Committed', here_to_win: 'Here to win',
  chat: 'Chat', calls: 'Calls', in_person: 'In person',
  ai: 'AI', climate: 'Climate', education: 'Education', fintech: 'Fintech', gaming: 'Gaming',
  health: 'Health', productivity: 'Productivity', social_impact: 'Social impact',
  pitching: 'Pitching', ui_design: 'UI design', research: 'Research',
  project_management: 'Project management', video_editing: 'Video editing',
  // Hackathon hub
  event: 'Event', challenge: 'Challenge',
  workshop: 'Workshop', talk: 'Talk', social: 'Social', expo: 'Expo',
  build: 'Build', design: 'Design', pitch: 'Pitch', quiz: 'Quiz',
  live: 'Live', upcoming: 'Upcoming', ended: 'Ended',
};

export const label = (v) => LABELS[v] ?? String(v).replace(/_/g, ' ');

export const FIELD_LABELS = {
  role: 'Your role',
  experienceLevel: 'Experience',
  schedule: 'When do you work best?',
  commitment: 'How serious are you?',
  communication: 'How do you like to talk?',
  interests: 'What do you care about?',
  superpowers: 'Superpowers (up to 2)',
};

export const CHECKLIST_LABELS = { frontend: 'Frontend', backend: 'Backend', designer: 'Design', pitching: 'Pitching' };

// Categories for each kind, from docs/hackathon-api.md.
export const EVENT_CATEGORIES = {
  event: ['workshop', 'talk', 'social', 'expo'],
  challenge: ['build', 'design', 'pitch', 'quiz'],
};
