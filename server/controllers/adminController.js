import User from '../models/User.js';
import Crew from '../models/Crew.js';

// GET /api/admin/stats — numbers for the web dashboard.
export async function getStats(req, res) {
  const students = { isAdmin: false };
  const [totalUsers, completeProfiles, matchAgg, crews, byRole, byInterest] = await Promise.all([
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
  ]);

  res.json({
    totalUsers,
    completeProfiles,
    // Each match is stored on both people.
    totalMatches: (matchAgg[0]?.n ?? 0) / 2,
    crews,
    byRole: byRole.map((r) => ({ role: r._id, count: r.count })),
    byInterest: byInterest.map((r) => ({ interest: r._id, count: r.count })),
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
