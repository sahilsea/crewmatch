// Compatibility score (0-100), reason tags and the crew checklist.
// `team` is a list of profiles: just you, or your whole crew.

const COMMITMENT = { just_for_fun: 0, committed: 1, here_to_win: 2 };
const ROLE_LABEL = {
  frontend: 'frontend', backend: 'backend', fullstack: 'full-stack',
  designer: 'design', ml: 'ML', pm: 'product',
};
const POWER_TAG = {
  pitching: "Your crew's presenter",
  ui_design: 'Brings UI design',
  research: 'Brings research',
  project_management: 'Keeps the crew on track',
  video_editing: 'Can cut the demo video',
};
const INTEREST_LABEL = { ai: 'AI', fintech: 'fintech', social_impact: 'social impact' };
export const MUST_HAVES = ['frontend', 'backend', 'designer', 'pitching'];

const powers = (team) => new Set(team.flatMap((m) => m.superpowers ?? []));
const lower = (list) => new Set((list ?? []).map((s) => s.toLowerCase()));
const minus = (a, b) => [...a].filter((x) => !b.has(x));

// 0 to 1: same schedule, same commitment, same way of communicating.
function styleFit(a, b) {
  const schedule = a.schedule === b.schedule ? 1 : [a.schedule, b.schedule].includes('flexible') ? 0.7 : 0;
  const gap = Math.abs((COMMITMENT[a.commitment] ?? 1) - (COMMITMENT[b.commitment] ?? 1));
  const comms = a.communication === b.communication ? 1 : 0.5;
  return (schedule + (1 - gap / 2) + comms) / 3;
}

export function compatibility(team, candidate) {
  const teamRoles = new Set(team.map((m) => m.role));
  const teamSkills = new Set(team.flatMap((m) => [...lower(m.skills)]));
  const candSkills = lower(candidate.skills);

  // 1. Complementary skills (50%): a new role, a superpower the team lacks, new skills
  const role = teamRoles.has(candidate.role) ? 0.2 : 1;
  const newPower = minus(candidate.superpowers ?? [], powers(team)).length ? 1 : 0;
  const newSkills = minus(candSkills, teamSkills).length / Math.max(candSkills.size, 1);
  const skills = 0.5 * role + 0.3 * newPower + 0.2 * newSkills;

  // 2. Working style (30%), averaged over the team
  const style = team.reduce((sum, m) => sum + styleFit(m, candidate), 0) / team.length;

  // 3. Shared interests (20%), measured against the shorter list
  const teamInterests = new Set(team.flatMap((m) => m.interests ?? []));
  const candInterests = new Set(candidate.interests ?? []);
  const shared = [...candInterests].filter((i) => teamInterests.has(i)).length;
  const interests = shared / Math.max(Math.min(teamInterests.size, candInterests.size), 1);

  // A small boost for sharing a campus club: +3 per club, at most +6, so it
  // breaks ties without lifting everyone in your club to the top.
  const bonus = Math.min(6, 3 * sharedClubs(team, candidate));
  return Math.min(100, Math.round(100 * (0.5 * skills + 0.3 * style + 0.2 * interests)) + bonus);
}

// How many of the candidate's clubs someone on the team is also in.
function sharedClubs(team, candidate) {
  const teamClubs = new Set(team.flatMap((m) => (m.clubs ?? []).map(String)));
  return (candidate.clubs ?? []).filter((c) => teamClubs.has(String(c))).length;
}

// Up to 3 instant, free reasons to show on the card.
export function reasonTags(team, candidate) {
  const tags = [];
  const { role } = candidate;
  if (role && !team.some((m) => m.role === role)) {
    tags.push(`Fills your ${ROLE_LABEL[role] ?? role} gap`);
  }
  for (const p of minus(candidate.superpowers ?? [], powers(team)).sort()) {
    tags.push(POWER_TAG[p] ?? 'Brings a new superpower');
  }
  const teamInterests = new Set(team.flatMap((m) => m.interests ?? []));
  const shared = (candidate.interests ?? []).filter((i) => teamInterests.has(i)).sort();
  if (shared.length) {
    tags.push('Into ' + shared.slice(0, 2).map((i) => INTEREST_LABEL[i] ?? i).join(' and '));
  }
  if (team.every((m) => m.schedule === candidate.schedule)) {
    const names = { night_owl: 'Fellow night owl', morning_person: 'Fellow early bird' };
    tags.push(names[candidate.schedule] ?? 'Same schedule');
  }
  if (sharedClubs(team, candidate)) tags.push('In your club');
  return tags.slice(0, 3);
}

// What the crew has covered, e.g. { backend: true, pitching: false }.
export function crewChecklist(team) {
  const have = new Set([...team.map((m) => m.role), ...powers(team)]);
  if (have.has('fullstack')) { have.add('frontend'); have.add('backend'); }
  if (have.has('ui_design')) have.add('designer');
  return Object.fromEntries(MUST_HAVES.map((need) => [need, have.has(need)]));
}
