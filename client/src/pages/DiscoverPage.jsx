import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../api.js';
import { useAuth } from '../auth.jsx';
import SwipeCard from '../components/SwipeCard.jsx';
import MatchModal from '../components/MatchModal.jsx';
import { Empty, ErrorNote, Spinner } from '../components/ui.jsx';

export default function DiscoverPage() {
  const { user, setUser } = useAuth();
  const [deck, setDeck] = useState(null);
  const [scoredAgainst, setScoredAgainst] = useState('you');
  const [fling, setFling] = useState(null);
  const [match, setMatch] = useState(null);
  const [error, setError] = useState(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      const d = await api.get('/deck');
      setDeck(d.deck);
      setScoredAgainst(d.scoredAgainst);
    } catch (err) {
      setError(err);
      setDeck([]);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  // Called by the card once its fly-out animation finishes.
  async function handleSwipe(direction) {
    const [top, ...rest] = deck;
    setDeck(rest);
    setFling(null);
    try {
      const res = await api.post('/swipe', { targetId: top.id, direction });
      if (res.match) {
        setMatch(res.user);
        setUser((u) => ({ ...u, matchCount: u.matchCount + 1 }));
      }
    } catch (err) {
      setError(err);
    }
    if (rest.length === 0) load();
  }

  // Arrow keys swipe too.
  useEffect(() => {
    const onKey = (e) => {
      if (match || fling || !deck?.length) return;
      if (e.key === 'ArrowRight') setFling('right');
      if (e.key === 'ArrowLeft') setFling('left');
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [deck, fling, match]);

  async function resetPasses() {
    await api.post('/swipe/reset');
    setDeck(null);
    load();
  }

  if (!deck) return <Spinner text="Ranking your best fits…" />;

  return (
    <div className="discover">
      <div className="discover-head">
        <h1>Discover</h1>
        <p className="muted">
          {scoredAgainst === 'crew'
            ? <>Ranked by who fills your <Link to="/crew">crew's</Link> gaps.</>
            : 'Ranked by who fills your gaps. Best fits first.'}
        </p>
      </div>

      <ErrorNote error={error} />

      {deck.length === 0 ? (
        <Empty title="You've seen everyone for now">
          <p className="muted">New students join all the time. Check back soon, or give the people you passed another look.</p>
          <div className="row">
            <button className="btn primary" onClick={resetPasses}>Show passed people again</button>
            <Link className="btn ghost" to="/matches">See matches</Link>
          </div>
        </Empty>
      ) : (
        <>
          <div className="deck">
            {deck.slice(0, 2).reverse().map((p) => (
              <SwipeCard
                key={p.id} person={p} active={p.id === deck[0].id}
                fling={p.id === deck[0].id ? fling : null}
                onSwipe={handleSwipe}
              />
            ))}
          </div>
          <div className="swipe-actions">
            <button className="round pass" onClick={() => setFling('left')} disabled={!!fling} aria-label="Pass">✕</button>
            <span className="muted hint">Drag the card, or use ← →</span>
            <button className="round like" onClick={() => setFling('right')} disabled={!!fling} aria-label="Like">♥</button>
          </div>
        </>
      )}

      {match && <MatchModal me={user} them={match} onClose={() => setMatch(null)} />}
    </div>
  );
}
