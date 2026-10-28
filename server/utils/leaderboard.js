import Crew from '../models/Crew.js';
import Event from '../models/Event.js';

// Most points first. On a tie, whoever reached that score first; crews yet to score go by name.
function byRank(a, b) {
  return (
    b.points - a.points ||
    (a.lastScoredAt ?? Infinity) - (b.lastScoredAt ?? Infinity) ||
    a.name.localeCompare(b.name)
  );
}

// Every crew, with the points it has been awarded, ranked from 1.
// GET /api/leaderboard and GET /api/crews/mine both use this, so they always agree.
export async function rankCrews() {
  const [crews, totals] = await Promise.all([
    Crew.find().populate('members', 'name role avatar'),
    Event.aggregate([
      { $match: { 'entries.status': 'completed' } },
      { $unwind: '$entries' },
      { $match: { 'entries.status': 'completed' } },
      {
        $group: {
          _id: '$entries.crew',
          points: { $sum: '$entries.pointsAwarded' },
          completed: { $sum: 1 },
          events: { $sum: { $cond: [{ $eq: ['$kind', 'event'] }, 1, 0] } },
          challenges: { $sum: { $cond: [{ $eq: ['$kind', 'challenge'] }, 1, 0] } },
          // When the crew reached its current score. Entries worth 0 points don't move it.
          lastScoredAt: { $max: { $cond: [{ $gt: ['$entries.pointsAwarded', 0] }, '$entries.completedAt', null] } },
        },
      },
    ]),
  ]);

  // Entries of crews that no longer exist have no crew to land on, so they drop out here.
  const byCrew = new Map(totals.map((t) => [t._id.toString(), t]));
  return crews
    .map((crew) => {
      const t = byCrew.get(crew.id);
      return {
        id: crew.id,
        name: crew.name,
        points: t?.points ?? 0,
        completed: t?.completed ?? 0,
        events: t?.events ?? 0,
        challenges: t?.challenges ?? 0,
        lastScoredAt: t?.lastScoredAt ?? null,
        members: crew.members.map((m) => ({ id: m.id, name: m.name, role: m.role ?? null, avatar: m.avatar })),
      };
    })
    .sort(byRank)
    .map((row, i) => ({ rank: i + 1, ...row }));
}
