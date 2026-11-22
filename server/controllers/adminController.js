import User from '../models/User.js';
import Crew from '../models/Crew.js';
import Event from '../models/Event.js';

// GET /api/admin/stats — numbers for the web dashboard.
export async function getStats(req, res) {
  const students = { isAdmin: false };
  const [
    totalUsers, completeProfiles, matchAgg, crews, byRole, byInterest, events, challenges, pendingAgg,
    pendingEvents, communityEvents, liveEvents,
  ] = await Promise.all([
    User.countDocuments(students),
    User.countDocuments({ ...students, profileComplete: true }),
    User.aggregate([{ $match: students }, { $group: { _id: null, n: { $sum: { $size: '$matches' } } } }]),
    Crew.countDocuments(),
    User.aggregate([
      { $match: { ...students, role: { $ne: null } } },
      { $group: { _id: '$role', count: { $sum: 1 } } },
      { $sort: { count: -1 } },
    ]),
    User.aggregate([
      { $match: students },
      { $unwind: '$interests' },
      { $group: { _id: '$interests', count: { $sum: 1 } } },
      { $sort: { count: -1 } },
    ]),
    Event.countDocuments({ kind: 'event', status: 'official' }),
    Event.countDocuments({ kind: 'challenge', status: 'official' }),
    // Challenge links waiting for an admin to approve or reject.
    Event.aggregate([
      { $match: { 'entries.status': 'submitted' } },
      { $unwind: '$entries' },
      { $match: { 'entries.status': 'submitted' } },
      { $count: 'n' },
    ]),
    // Students' events: waiting for points, and running without points.
    Event.countDocuments({ status: 'pending' }),
    Event.countDocuments({ status: 'community' }),
    Event.countDocuments({ startsAt: { $lte: new Date() }, endsAt: { $gte: new Date() } }),
  ]);

  res.json({
    totalUsers,
    completeProfiles,
    // Each match is stored on both people.
    totalMatches: (matchAgg[0]?.n ?? 0) / 2,
    crews,
    byRole: byRole.map((r) => ({ role: r._id, count: r.count })),
    byInterest: byInterest.map((r) => ({ interest: r._id, count: r.count })),
    events,
    challenges,
    pendingSubmissions: pendingAgg[0]?.n ?? 0,
    pendingEvents,
    communityEvents,
    liveEvents,
  });
}

// GET /api/admin/users — every student, for the admin table.
export async function listUsers(req, res) {
  const users = await User.find({ isAdmin: false }).sort({ createdAt: -1 });
  res.json({
    count: users.length,
    users: users.map((u) => ({
      ...u.toSelf(),
      createdAt: u.createdAt,
      seed: u.autoLike,
    })),
  });
}
