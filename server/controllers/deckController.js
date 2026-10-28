import User from '../models/User.js';
import Crew from '../models/Crew.js';
import { compatibility, reasonTags } from '../utils/matching.js';
import { MIN_DECK_SCORE } from '../config/options.js';
import { HttpError } from '../middleware/error.js';

// The profiles the deck scores against: your whole crew if you have one, else just you.
async function teamFor(user) {
  if (!user.crew) return [user];
  const crew = await Crew.findById(user.crew).populate('members');
  return crew?.members.length ? crew.members : [user];
}

// GET /api/deck?limit=20
// Everyone with a complete profile you haven't swiped on, scored best-first.
export async function getDeck(req, res) {
  const me = req.user;
  const limit = Math.min(Number(req.query.limit) || 20, 50);
  const team = await teamFor(me);

  const exclude = [
    me._id, ...me.swipedRight, ...me.swipedLeft, ...me.matches, ...team.map((m) => m._id),
  ];
  const candidates = await User.find({
    _id: { $nin: exclude },
    profileComplete: true,
    isAdmin: false,
  });

  const deck = candidates
    .map((c) => ({ ...c.toPublic(), score: compatibility(team, c), tags: reasonTags(team, c) }))
    .filter((c) => c.score >= MIN_DECK_SCORE)
    .sort((a, b) => b.score - a.score)
    .slice(0, limit);

  res.json({ scoredAgainst: team.length > 1 ? 'crew' : 'you', count: deck.length, deck });
}

// POST /api/swipe  { targetId, direction }
// Two right swipes make a match.
export async function swipe(req, res) {
  const me = req.user;
  const { targetId, direction } = req.body;
  if (me._id.equals(targetId)) throw new HttpError(400, "You can't swipe on yourself");

  const target = await User.findById(targetId);
  if (!target || target.isAdmin) throw new HttpError(404, 'User not found');

  // Swiping again overrides the earlier choice.
  const field = direction === 'right' ? 'swipedRight' : 'swipedLeft';
  const other = direction === 'right' ? 'swipedLeft' : 'swipedRight';
  await User.updateOne({ _id: me._id }, { $addToSet: { [field]: target._id }, $pull: { [other]: target._id } });

  let match = false;
  if (direction === 'right') {
    const likedBack = target.autoLike || target.swipedRight.some((id) => id.equals(me._id));
    if (likedBack) {
      match = true;
      await Promise.all([
        User.updateOne({ _id: me._id }, { $addToSet: { matches: target._id } }),
        User.updateOne(
          { _id: target._id },
          { $addToSet: { matches: me._id, swipedRight: me._id } }
        ),
      ]);
    }
  }

  res.json({ match, user: match ? { ...target.toPublic(), email: target.email } : undefined });
}

// POST /api/swipe/reset — clears your left swipes so passed people come back.
export async function resetPasses(req, res) {
  await User.updateOne({ _id: req.user._id }, { $set: { swipedLeft: [] } });
  res.json({ ok: true });
}
