// Explains a deck card's fit in the three parts the score is built from, using plain
// counts from the profiles. The parts and weights are the ones in server/utils/matching.js.
// The API only sends the total score, so these are counts ("2 of 3 skills are new to you"),
// never the server's part scores.
import { label } from './labels.js';
import { joinWords } from './format.js';

const ROLE_GAP = { frontend: 'frontend', backend: 'backend', fullstack: 'full-stack', designer: 'design', ml: 'ML', pm: 'product' };
const STYLE = ['schedule', 'commitment', 'communication'];

// "Pitching" -> "pitching", but "UI design" and "AI" keep their capitals.
const lowerFirst = (s) => (/^[A-Z]{2}/.test(s) ? s : s[0].toLowerCase() + s.slice(1));

// `team` is the profiles the deck scored against: just you, or your whole crew.
export function fitReport(team, person) {
  const solo = team.length === 1;
  const you = solo ? 'you' : 'your crew';
  const your = solo ? 'your' : "your crew's";

  // Skills (50%): a role and superpowers the team lacks, and skills nobody on it has
  const newRole = !team.some((m) => m.role === person.role);
  const teamPowers = new Set(team.flatMap((m) => m.superpowers ?? []));
  const powers = joinWords((person.superpowers ?? []).filter((p) => !teamPowers.has(p)).map((p) => lowerFirst(label(p))));
  const teamSkills = new Set(team.flatMap((m) => m.skills ?? []).map((s) => s.toLowerCase()));
  const newSkills = person.skills.filter((s) => !teamSkills.has(s.toLowerCase())).length;
  const role = ROLE_GAP[person.role] ?? label(person.role);
  const skills = newRole
    ? `Fills ${your} ${role} gap${powers ? ` and brings ${powers}` : ''}`
    : powers ? `Brings ${powers} ${you} lack${solo ? '' : 's'}` : `Another ${role} role, like ${solo ? 'yours' : 'one in your crew'}`;

  // Style (30%): the same schedule, drive and way of talking
  const sameStyle = team.reduce((n, m) => n + STYLE.filter((k) => m[k] === person[k]).length, 0);
  const style = `${label(person.schedule)}, ${lowerFirst(label(person.commitment))}, prefers ${lowerFirst(label(person.communication))}`;

  // Interests (20%): domains you both care about
  const teamInterests = new Set(team.flatMap((m) => m.interests ?? []));
  const shared = person.interests.filter((i) => teamInterests.has(i));
  const interests = shared.length
    ? `${solo ? 'You both picked' : 'Your crew also picked'} ${joinWords(shared.map(label))}`
    : `Into ${joinWords(person.interests.map(label))}, nothing shared yet`;

  return [
    { key: 'skills', weight: 50, headline: skills, have: newSkills, of: person.skills.length,
      caption: `${newSkills} of ${person.skills.length} skills new to ${you}` },
    { key: 'style', weight: 30, headline: style, have: sameStyle, of: STYLE.length * team.length,
      caption: `${sameStyle} of ${STYLE.length * team.length} ${solo ? 'match you' : 'match across your crew'}` },
    { key: 'interests', weight: 20, headline: interests, have: shared.length, of: person.interests.length,
      caption: `${shared.length} of ${person.interests.length} interests shared` },
  ];
}
