import { useEffect, useState } from 'react';
import { motion } from 'motion/react';
import { api } from '../api.js';
import { Pill, Window } from '../components/retro.jsx';
import { Avatar, Empty, ErrorNote, Spinner } from '../components/ui.jsx';
import { clockTime, toneFor } from '../format.js';

// Built to stay open on a projector, so it refreshes itself.
const REFRESH_MS = 15_000;

function Members({ members, size }) {
  return (
    <ul className="avatar-stack" aria-label="Members">
      {members.map((m) => (
        <li key={m.id} title={m.name}>
          <Avatar src={m.avatar} name={m.name} size={size} tone={toneFor(m.id)} />
          <span className="sr-only">{m.name}</span>
        </li>
      ))}
    </ul>
  );
}

const done = (c) => `${c.events} ${c.events === 1 ? 'event' : 'events'} · ${c.challenges} ${c.challenges === 1 ? 'challenge' : 'challenges'}`;

// How far your crew is from the one above it.
function standing(mine, ahead) {
  if (!ahead) return mine.points > 0 ? 'Top of the board. Keep it up.' : 'No points yet. Check in at an event to get on the board.';
  const gap = ahead.points - mine.points;
  if (gap === 0) return `Level on points with ${ahead.name}, who got there first.`;
  return `${gap} ${gap === 1 ? 'point' : 'points'} behind ${ahead.name} at #${ahead.rank}.`;
}

export default function LeaderboardPage() {
  const [board, setBoard] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    let live = true;
    const load = () => api.get('/leaderboard')
      .then((d) => { if (live) { setBoard(d); setError(null); } })
      .catch((err) => live && setError(err));
    load();
    const id = setInterval(load, REFRESH_MS);
    return () => { live = false; clearInterval(id); };
  }, []);

  if (!board) return error ? <div className="board-page"><ErrorNote error={error} /></div> : <Spinner text="Counting points" />;

  const { crews, myCrewId } = board;
  const mine = crews.find((c) => c.id === myCrewId);
  const ahead = mine && mine.rank > 1 ? crews[mine.rank - 2] : null;

  return (
    <div className="workspace board-desk">
      <div className="desk-main">
        <Window
          title="Leaderboard" titleAs="h1" inset={false} front
          strip={`${crews.length} crews · updated ${clockTime(board.updatedAt, true)} · refreshes every 15 s`}
        >
          <header className="board-masthead">
            <p className="label">The crew standings</p>
            <h2 className="board-title">{board.title}</h2>
            <p className="label">Points from events and challenges · <Pill>Live</Pill></p>
          </header>
          {error && <div className="window-messages"><ErrorNote error={error} /></div>}

          {crews.length === 0 ? (
            <div className="inset"><Empty title="No crews yet"><p>Crews show up here as soon as they form.</p></Empty></div>
          ) : (
            <>
              <ol className="podium">
                {crews.slice(0, 3).map((c) => (
                  <motion.li layout key={c.id} className={`podium-card rank-${c.rank} ${c.id === myCrewId ? 'mine' : ''}`}>
                    <span className="rank-num">#{c.rank}</span>
                    <h3 className="podium-name">{c.name}</h3>
                    {c.id === myCrewId && <Pill>Your crew</Pill>}
                    <Members members={c.members} size={40} />
                    <p className="points">{c.points}<span className="label"> pts</span></p>
                    <p className="label small ink">{c.completed} done · {done(c)}</p>
                  </motion.li>
                ))}
              </ol>
              {crews.length > 3 && (
                <ol className="board-list">
                  {crews.slice(3).map((c) => (
                    <motion.li layout key={c.id} className={`board-row ${c.id === myCrewId ? 'mine' : ''}`}>
                      <span className="rank-num">#{c.rank}</span>
                      <div className="board-crew">
                        <h3 className="board-name">{c.name} {c.id === myCrewId && <Pill>Your crew</Pill>}</h3>
                        <p className="label small">{c.completed} done · {done(c)}</p>
                      </div>
                      <Members members={c.members} size={32} />
                      <p className="points">{c.points}<span className="label"> pts</span></p>
                    </motion.li>
                  ))}
                </ol>
              )}
            </>
          )}
        </Window>
      </div>

      {mine && (
        <div className="desk-side">
          <Window title="Your crew" inset={false}>
            <div className="board-mine">
              <p className="rank-num">#{mine.rank}</p>
              <p className="report-headline">{mine.name}</p>
              <p className="label ink">{mine.points} points · of {crews.length} crews</p>
              <p className="side-copy">{standing(mine, ahead)}</p>
            </div>
          </Window>
        </div>
      )}
    </div>
  );
}
