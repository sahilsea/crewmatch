import { ARCHIVE, CURRENT_HACKATHON_ID } from '../config/hackathons.js';
import { HttpError } from '../middleware/error.js';
import { rankCrews } from '../utils/leaderboard.js';

const currentName = () => process.env.HACKATHON_NAME || 'MERNOVA X 2026';

function findArchived(id) {
  const hackathon = ARCHIVE.find((h) => h.id === id);
  if (!hackathon) throw new HttpError(404, 'Hackathon not found');
  return hackathon;
}

// The crew this user was in at an archived hackathon, if any.
const myArchivedCrew = (hackathon, user) =>
  (hackathon.crews ?? []).find((c) => c.memberEmails.includes(user.email)) ?? null;

// GET /api/hackathons — every hackathon with your crew's rank at it, plus your
// record across them. Ranks are per hackathon; only points are summed.
export async function listHackathons(req, res) {
  const crews = await rankCrews();
  const myId = req.user.crew?.toString();
  const mine = crews.find((c) => c.id === myId);
  const current = {
    id: CURRENT_HACKATHON_ID,
    name: currentName(),
    status: 'live',
    crewCount: crews.length,
    myRank: mine?.rank ?? null,
    myCrewName: mine?.name ?? null,
    myPoints: mine?.points ?? null,
  };
  const others = ARCHIVE.map((h) => {
    const crew = myArchivedCrew(h, req.user);
    return {
      id: h.id,
      name: h.name,
      status: h.status,
      startsAt: h.startsAt ?? null,
      endedAt: h.endedAt ?? null,
      crewCount: h.crews?.length ?? 0,
      myRank: crew?.rank ?? null,
      myCrewName: crew?.name ?? null,
      myPoints: crew?.points ?? null,
    };
  });
  const hackathons = [current, ...others];
  const played = hackathons.filter((h) => h.myRank != null);
  res.json({
    hackathons,
    record: {
      hackathons: played.length,
      bestFinish: played.length ? Math.min(...played.map((h) => h.myRank)) : null,
      totalPoints: played.reduce((sum, h) => sum + h.myPoints, 0),
    },
  });
}

// GET /api/hackathons/:id/leaderboard — the same shape as GET /api/leaderboard.
// "current" is the live board; an upcoming hackathon has no crews yet.
export async function getHackathonLeaderboard(req, res) {
  if (req.params.id === CURRENT_HACKATHON_ID) {
    return res.json({
      title: currentName(),
      status: 'live',
      updatedAt: new Date(),
      myCrewId: req.user.crew ? req.user.crew.toString() : null,
      crews: await rankCrews(),
    });
  }
  const h = findArchived(req.params.id);
  res.json({
    title: h.name,
    status: h.status,
    startsAt: h.startsAt ?? null,
    updatedAt: h.endedAt ?? null,
    myCrewId: myArchivedCrew(h, req.user)?.id ?? null,
    crews: (h.crews ?? []).map(({ memberEmails, ...crew }) => ({ ...crew, members: [] })),
  });
}
