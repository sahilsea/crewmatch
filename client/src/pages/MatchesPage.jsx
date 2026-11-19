import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../api.js';
import { useAuth } from '../auth.jsx';
import { Window } from '../components/retro.jsx';
import { Avatar, Empty, ErrorNote, Meta, Score, Spinner, Tag } from '../components/ui.jsx';
import { toneFor } from '../format.js';

export default function MatchesPage() {
  const { user, refresh } = useAuth();
  const [matches, setMatches] = useState(null);
  const [crew, setCrew] = useState(null);
  const [selectedId, setSelectedId] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    let live = true;
    Promise.all([api.get('/matches'), api.get('/crews/mine')])
      .then(([m, c]) => {
        if (!live) return;
        setMatches(m.matches);
        setCrew(c.crew);
      })
      .catch((err) => {
        if (!live) return;
        setError(err);
        setMatches([]);
      });
    return () => { live = false; };
  }, []);

  async function unmatch(person) {
    if (!confirm(`Unmatch ${person.name}? They won't appear in your deck again.`)) return;
    setError(null);
    try {
      await api.del(`/matches/${person.id}`);
      setMatches((list) => list.filter((m) => m.id !== person.id));
      setSelectedId(null);
      refresh();
    } catch (err) {
      setError(err);
    }
  }

  async function addToCrew(person) {
    setError(null);
    try {
      const { crew: updated } = await api.post('/crews/mine/members', { userId: person.id });
      setCrew(updated);
      setMatches((list) => list.map((m) => (m.id === person.id ? { ...m, inCrew: true } : m)));
    } catch (err) {
      setError(err);
    }
  }

  // On narrow screens the info window sits below the grid, so bring it into view.
  function select(person) {
    setSelectedId(person.id);
    if (matchMedia('(max-width: 999px)').matches) {
      document.getElementById('match-info')?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  }

  if (!matches) return <Spinner />;

  const crewIds = new Set(crew?.members.map((m) => m.id));
  const selected = matches.find((m) => m.id === selectedId) ?? matches[0];

  return (
    <div className="workspace matches-desk">
      <div className="desk-main">
        <Window title="Matches" titleAs="h1" inset={false} strip={`${matches.length} ${matches.length === 1 ? 'item' : 'items'}`}>
          <p className="strip-top">They swiped right on you too · pick one for info</p>
          <div className="inset">
            <ErrorNote error={error} />
            {matches.length === 0 ? (
              <Empty title="No matches yet">
                <p>Swipe right on people you'd team up with. When they like you back, they show up here.</p>
                <Link className="btn primary" to="/">Start swiping</Link>
              </Empty>
            ) : (
              <ul className="file-grid match-grid">
                {matches.map((p) => (
                  <li key={p.id}>
                    <button
                      type="button" className={`file ${p.id === selected.id ? 'selected' : ''}`}
                      aria-pressed={p.id === selected.id} onClick={() => select(p)}
                    >
                      <Avatar src={p.avatar} name={p.name} size={72} tone={toneFor(p.id)} />
                      <span className="file-name">{p.name.replace(/\s+/g, '_')}</span>
                      <span className="label">
                        {p.score}% fit{crewIds.has(p.id) ? ' · in crew' : p.inCrew ? ' · taken' : ''}
                      </span>
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </Window>
      </div>

      {selected && (
        <div className="desk-side">
          <Window title="Info" id="match-info" inset={false}>
            <div className="info-head halftone blue">
              <Avatar src={selected.avatar} name={selected.name} size={96} tone="desk" />
            </div>
            <div className="info-body">
              <div className="info-name">
                <h2 className="serif-title">{selected.name}</h2>
                <Score value={selected.score} />
              </div>
              <Meta person={selected} />
              {selected.bio && <p>{selected.bio}</p>}
              <div>{selected.skills.map((s) => <Tag key={s} tone="pink">{s}</Tag>)}</div>
              {selected.tags.length > 0 && <p className="label small">{selected.tags.join(' · ')}</p>}
              <a className="email" href={`mailto:${selected.email}`}>{selected.email}</a>
            </div>
            <div className="info-actions">
              {crewIds.has(selected.id) ? (
                <Tag tone="blue">In your crew</Tag>
              ) : selected.inCrew ? (
                <Tag>In another crew</Tag>
              ) : crew && crew.spotsLeft > 0 ? (
                <button type="button" className="btn primary sm" onClick={() => addToCrew(selected)}>+ Add to {crew.name}</button>
              ) : !user.crewId ? (
                <Link className="btn primary sm" to="/crew">Start a crew</Link>
              ) : null}
              <button type="button" className="btn sm" onClick={() => unmatch(selected)}>Unmatch</button>
            </div>
          </Window>
        </div>
      )}
    </div>
  );
}
