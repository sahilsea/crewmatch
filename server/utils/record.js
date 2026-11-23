import Event from '../models/Event.js';

// Hackathon record for each person, from their crew's finished entries:
// events checked into, challenges approved, points, and the latest one.
// People without a crew have an empty record.
export async function recordsFor(users) {
  const crewOf = Object.fromEntries(users.filter((u) => u.crew).map((u) => [u.id, u.crew.toString()]));
  const crewIds = [...new Set(Object.values(crewOf))];
  const empty = { events: 0, challenges: 0, points: 0, last: null };
  if (!crewIds.length) return Object.fromEntries(users.map((u) => [u.id, empty]));

  const rows = await Event.aggregate([
    { $unwind: '$entries' },
    { $match: { 'entries.status': 'completed', $expr: { $in: [{ $toString: '$entries.crew' }, crewIds] } } },
    { $sort: { 'entries.completedAt': -1 } },
    {
      $group: {
        _id: { $toString: '$entries.crew' },
        events: { $sum: { $cond: [{ $eq: ['$kind', 'event'] }, 1, 0] } },
        challenges: { $sum: { $cond: [{ $eq: ['$kind', 'challenge'] }, 1, 0] } },
        points: { $sum: '$entries.pointsAwarded' },
        lastTitle: { $first: '$title' },
        lastKind: { $first: '$kind' },
        lastAt: { $first: '$entries.completedAt' },
      },
    },
  ]);
  const byCrew = Object.fromEntries(rows.map((r) => [r._id, {
    events: r.events,
    challenges: r.challenges,
    points: r.points,
    last: r.lastTitle ? { title: r.lastTitle, kind: r.lastKind, at: r.lastAt } : null,
  }]));
  return Object.fromEntries(users.map((u) => [u.id, byCrew[crewOf[u.id]] ?? empty]));
}
