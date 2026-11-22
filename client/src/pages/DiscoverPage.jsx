import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../api.js';
import { useAuth } from '../auth.jsx';
import { useOptions, useWindowOrder } from '../hooks.js';
import SwipeCard from '../components/SwipeCard.jsx';
import MatchModal from '../components/MatchModal.jsx';
import ProfileDialog from '../components/ProfileDialog.jsx';
import { Meter, Segmented, Tabs, Window } from '../components/retro.jsx';
import { Avatar, Empty, ErrorNote, Spinner } from '../components/ui.jsx';
import { CardIcon, CaretIcon, HeartIcon, PassIcon, SkipIcon, UndoIcon } from '../components/icons.jsx';
import { CHECKLIST_LABELS, label } from '../labels.js';
import { fitReport } from '../fit.js';
import { fileName, shortName, toneFor } from '../format.js';

// The API never sends anyone under 40% fit, so the slider starts there.
const DECK_FLOOR = 40;

// Swipes and new matches in this browser tab, kept across page changes and reloads.
const sessionKey = (userId) => `crewmatch_session_${userId}`;
function readSession(userId) {
  try {
    return JSON.parse(sessionStorage.getItem(sessionKey(userId))) ?? { swipes: 0, matches: 0 };
  } catch {
    return { swipes: 0, matches: 0 };
  }
}

export default function DiscoverPage() {
  const { user, setUser } = useAuth();
  const options = useOptions();
  const win = useWindowOrder(['report', 'today', 'next', 'crew', 'deck']);
  const [deck, setDeck] = useState(null);
  const [scoredAgainst, setScoredAgainst] = useState('you');
  const [crew, setCrew] = useState(null);
  const [version, setVersion] = useState(0);
  const [role, setRole] = useState('all');
  const [minFit, setMinFit] = useState(DECK_FLOOR);
  const [fling, setFling] = useState(null);
  const [lastPassed, setLastPassed] = useState(null);
  const [match, setMatch] = useState(null);
  const [details, setDetails] = useState(false);
  const [error, setError] = useState(null);
  const [session, setSession] = useState(() => readSession(user.id));

  useEffect(() => {
    try { sessionStorage.setItem(sessionKey(user.id), JSON.stringify(session)); } catch { /* private mode: counts just reset */ }
  }, [user.id, session]);

  useEffect(() => {
    let live = true;
    Promise.all([api.get('/deck?limit=50'), api.get('/crews/mine')])
      .then(([d, c]) => {
        if (!live) return;
        setDeck(d.deck);
        setScoredAgainst(d.scoredAgainst);
        setCrew(c.crew);
      })
      .catch((err) => {
        if (!live) return;
        setError(err);
        setDeck([]);
      });
    return () => { live = false; };
  }, [version]);

  // The role menu and the slider narrow the deck without asking the API again.
  const visible = useMemo(
    () => (deck ?? []).filter((p) => (role === 'all' || p.role === role) && p.score >= minFit),
    [deck, role, minFit],
  );
  const top = visible[0];

  // Called by the card once its fly-out animation finishes.
  async function handleSwipe(person, direction) {
    const rest = deck.filter((p) => p.id !== person.id);
    setDeck(rest);
    setFling(null);
    setLastPassed(direction === 'left' ? person : null);
    setSession((s) => ({ ...s, swipes: s.swipes + 1 }));
    try {
      const res = await api.post('/swipe', { targetId: person.id, direction });
      if (res.match) {
        setSession((s) => ({ ...s, matches: s.matches + 1 }));
        setMatch(res.user);
        setUser((u) => ({ ...u, matchCount: u.matchCount + 1 }));
      }
    } catch (err) {
      setError(err);
    }
    if (rest.length === 0) setVersion((v) => v + 1);
  }

  // Brings back the last person you passed. The API keeps the pass until you
  // swipe on them again, and a new swipe replaces the old one.
  function undo() {
    setDeck((d) => [lastPassed, ...d]);
    if (lastPassed.score < minFit) setMinFit(DECK_FLOOR);
    if (role !== 'all' && role !== lastPassed.role) setRole('all');
    setLastPassed(null);
  }

  // Sends the top card to the back of the deck without recording a swipe.
  const skip = () => setDeck((d) => [...d.filter((p) => p.id !== top.id), top]);
  const showFirst = (person) => setDeck((d) => [person, ...d.filter((p) => p.id !== person.id)]);

  function decide(direction) {
    setDetails(false);
    setFling(direction);
  }

  // Arrow keys swipe too, unless you're typing or moving the slider.
  useEffect(() => {
    const onKey = (e) => {
      if (match || fling || details || !top) return;
      if (e.target.closest?.('input, select, textarea')) return;
      if (e.key === 'ArrowRight') setFling('right');
      if (e.key === 'ArrowLeft') setFling('left');
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [top, fling, match, details]);

  async function resetPasses() {
    setError(null);
    try {
      await api.post('/swipe/reset');
      setDeck(null);
      setLastPassed(null);
      setVersion((v) => v + 1);
    } catch (err) {
      setError(err);
    }
  }

  if (!deck) return <Spinner text="Ranking your best fits" />;

  const team = crew ? crew.members : [user];
  const fill = ((minFit - DECK_FLOOR) / (100 - DECK_FLOOR)) * 100;

  return (
    <div className="discover-desk">
      <div className="desk-col col-center">
        <Window title="Discover" titleAs="h1" front inset={false} className="dsk-deck" {...win('deck')}>
          <div className="deck-body">
            <ErrorNote error={error} />
            {top ? (
              <div className="deck-stage">
                {visible.slice(0, 2).reverse().map((p) => (
                  <SwipeCard
                    key={p.id} person={p} active={p.id === top.id}
                    fling={p.id === top.id ? fling : null}
                    onSwipe={(direction) => handleSwipe(p, direction)}
                    position={p.id === top.id ? 1 : 2} total={visible.length}
                  />
                ))}
              </div>
            ) : deck.length > 0 ? (
              <Empty title="Nobody left at this setting">
                <p>{deck.length} more {deck.length === 1 ? 'person is' : 'people are'} in your deck outside this filter.</p>
                <button type="button" className="btn primary" onClick={() => { setRole('all'); setMinFit(DECK_FLOOR); }}>
                  Show everyone
                </button>
              </Empty>
            ) : (
              <Empty title="You've seen everyone for now">
                <p>New students join all the time. Check back soon, or give the people you passed another look.</p>
                <div className="row">
                  <button type="button" className="btn primary" onClick={resetPasses}>Show passed people again</button>
                  <Link className="btn" to="/matches">See matches</Link>
                </div>
              </Empty>
            )}

            <div className="deck-controls">
              <Segmented label="Decide">
                <button type="button" aria-label="Pass" title="Pass (←)" onClick={() => setFling('left')} disabled={!top || !!fling}>
                  <PassIcon />
                </button>
                <button type="button" className="primary" aria-label="Like" title="Like (→)" onClick={() => setFling('right')} disabled={!top || !!fling}>
                  <HeartIcon />
                </button>
                <button
                  type="button" aria-label={lastPassed ? `Undo pass on ${lastPassed.name}` : 'Undo last pass'} title="Undo last pass"
                  onClick={undo} disabled={!lastPassed || !!fling}
                >
                  <UndoIcon />
                </button>
                <button type="button" aria-label="Skip for now" title="Skip for now" onClick={skip} disabled={visible.length < 2 || !!fling}>
                  <SkipIcon />
                </button>
              </Segmented>
              <button type="button" className="btn primary icon" aria-label="Full profile" title="Full profile" onClick={() => setDetails(true)} disabled={!top}>
                <CardIcon />
              </button>
              <span className="label hint" aria-hidden="true">Drag or ← →</span>
            </div>

            <label className="dropdown">
              <span className="pill">Live</span>
              <span className="sr-only">Deck</span>
              <select value={role} onChange={(e) => setRole(e.target.value)}>
                <option value="all">Deck: best fits first</option>
                {options?.role.map((r) => <option key={r} value={r}>Deck: {label(r)} only</option>)}
              </select>
              <CaretIcon />
            </label>

            <label className="slider-row">
              <span className="label">Min fit</span>
              <input
                type="range" className="slider" min={DECK_FLOOR} max={100} step={5} value={minFit}
                onChange={(e) => setMinFit(Number(e.target.value))} style={{ '--fill': `${fill}%` }}
              />
              <span className="label slider-value">{minFit}%</span>
            </label>
          </div>
        </Window>
      </div>

      <div className="desk-col col-left">
        <FitReport person={top} team={team} scoredAgainst={scoredAgainst} {...win('report')} />
        <Window title="This session" className="dsk-today" inset={false} {...win('today')}>
          <div className="stat-tiles">
            <Stat value={session.swipes} text="Swipes" />
            <Stat value={user.matchCount} text="Matches" />
            <Stat value={session.matches} text="New" tone={session.matches ? 'pink' : ''} />
          </div>
        </Window>
      </div>

      <div className="desk-col col-right">
        <NextUp people={visible.slice(1)} onPick={showFirst} {...win('next')} />
        <CrewStatus crew={crew} matchCount={user.matchCount} {...win('crew')} />
      </div>

      {match && <MatchModal me={user} them={match} onClose={() => setMatch(null)} />}
      {details && top && <ProfileDialog person={top} onClose={() => setDetails(false)} onDecide={decide} />}
    </div>
  );
}

const PARTS = [['all', 'All'], ['skills', 'Skills'], ['style', 'Style'], ['interests', 'Interests']];
const PART_TONES = { skills: 'pink', style: 'blue', interests: 'desk' };

// Why the top card fits: skills, style and interests, each with a plain count.
function FitReport({ person, team, scoredAgainst, ...win }) {
  const [part, setPart] = useState('all');
  const against = scoredAgainst === 'crew' ? 'your crew' : 'you';
  const parts = person ? fitReport(team, person).filter((r) => part === 'all' || r.key === part) : [];

  return (
    <Window title="Why this match" className="dsk-report" strip={`Scored against ${against} · weights are fixed`} {...win}>
      <div className="masthead">
        <p className="masthead-title">The Fit Report</p>
        <p className="label">{person ? `${person.name} × ${against} · ${person.score}% fit` : 'No card on the deck'}</p>
      </div>
      {person && (
        <>
          <div className="report-tabs"><Tabs label="Show" options={PARTS} value={part} onChange={setPart} /></div>
          {parts.map((r) => (
            <div className="report-row" key={r.key}>
              <span className={`swatch halftone ${PART_TONES[r.key]}`} aria-hidden="true" />
              <div className="report-text">
                <p className="label">{r.key} · weight {r.weight}%</p>
                <p className="report-headline">{r.headline}</p>
                <Meter value={r.have} max={r.of} />
                <p className="label small">{r.caption}</p>
              </div>
            </div>
          ))}
        </>
      )}
    </Window>
  );
}

// The next few cards as a file grid. Pressing one moves that person to the top of the deck.
function NextUp({ people, onPick, ...win }) {
  const shown = people.slice(0, 5);
  const more = people.length - shown.length;

  return (
    <Window title="Next up" className="dsk-next" strip={`${people.length} waiting · sorted by fit`} {...win}>
      {people.length === 0 ? (
        <p className="inset-note">Nobody else is waiting at this setting.</p>
      ) : (
        <ul className="file-grid">
          {shown.map((p) => (
            <li key={p.id}>
              <button type="button" className="file" onClick={() => onPick(p)} title={`Show ${p.name} next`}>
                <Avatar src={p.avatar} name={p.name} size={72} tone={toneFor(p.id)} />
                <span className="file-name">{fileName(shortName(p.name), 'crew')}</span>
                <span className="label">{p.score}% · {label(p.role)}</span>
                <span className="sr-only">{p.name}: show next</span>
              </button>
            </li>
          ))}
          {more > 0 && (
            <li className="file">
              <span className="more-ring">+{more}</span>
              <span className="file-name">more_in_deck</span>
              <span className="label">down to {people.at(-1).score}%</span>
            </li>
          )}
        </ul>
      )}
    </Window>
  );
}

const seatText = (n) => (n === 0 ? 'Crew is full' : n === 1 ? 'One seat open' : `${n} seats open`);

// Your crew at a glance: who's in, open seats, which roles are covered and its points.
function CrewStatus({ crew, matchCount, ...win }) {
  if (!crew) {
    return (
      <Window title="No crew yet" className="dsk-crew" {...win}>
        <div className="crew-empty">
          <p>Matches can team up as a crew of up to 4. Your deck then looks for whoever fills the crew's gaps.</p>
          <p className="label">{matchCount} {matchCount === 1 ? 'match' : 'matches'} so far</p>
          <Link className="btn primary sm" to="/crew">{matchCount ? 'Start a crew' : 'How crews work'}</Link>
        </div>
      </Window>
    );
  }

  return (
    <Window title={crew.name} className="dsk-crew" inset={false} {...win}>
      <div className="crew-status">
        <div className="dark-panel">
          <ul className="avatar-stack" aria-label="Members">
            {crew.members.map((m) => (
              <li key={m.id} title={m.name}>
                <Avatar src={m.avatar} name={m.name} size={40} tone={toneFor(m.id)} />
                <span className="sr-only">{m.name}</span>
              </li>
            ))}
            {Array.from({ length: crew.spotsLeft }, (_, i) => <li key={i} className="seat" aria-hidden="true" />)}
          </ul>
          <div className="crew-count">
            <p className="big-num">{crew.members.length}/{crew.members.length + crew.spotsLeft}</p>
            <p className="label">{seatText(crew.spotsLeft)}</p>
          </div>
        </div>
        <ul className="coverage-grid">
          {Object.entries(crew.checklist).map(([k, ok]) => (
            <li key={k} className={ok ? 'ok' : 'miss'}>
              <span className="dot" aria-hidden="true" />
              {CHECKLIST_LABELS[k]}{ok ? <span className="sr-only">: covered</span> : ' · needed'}
            </li>
          ))}
        </ul>
        <p className="crew-links">
          {crew.rank != null && <Link to="/leaderboard">#{crew.rank} · {crew.points} pts</Link>}
          <Link to="/crew">Open crew</Link>
        </p>
      </div>
    </Window>
  );
}

function Stat({ value, text, tone = '' }) {
  return (
    <div className={`stat ${tone}`}>
      <p className="stat-num">{value}</p>
      <p className="label">{text}</p>
    </div>
  );
}
