import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../api.js';
import { useAuth } from '../auth.jsx';
import { Avatar, Empty, ErrorNote, Meta, Score, Spinner, Tag } from '../components/ui.jsx';

export default function MatchesPage() {
  const { user, refresh } = useAuth();
  const [matches, setMatches] = useState(null);
  const [crew, setCrew] = useState(null);
  const [error, setError] = useState(null);

  const load = useCallback(async () => {
    try {
      const [m, c] = await Promise.all([api.get('/matches'), api.get('/crews/mine')]);
      setMatches(m.matches);
      setCrew(c.crew);
    } catch (err) {
      setError(err);
      setMatches([]);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  async function unmatch(person) {
    if (!confirm(`Unmatch ${person.name}? They won't appear in your deck again.`)) return;
    setError(null);
    try {
      await api.del(`/matches/${person.id}`);
      setMatches((list) => list.filter((m) => m.id !== person.id));
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

  if (!matches) return <Spinner />;

  const crewIds = new Set(crew?.members.map((m) => m.id));

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>Matches <span className="count">{matches.length}</span></h1>
          <p className="muted">People who swiped right on you too. Reach out by email.</p>
        </div>
        {!user.crewId && matches.length > 0 && <Link className="btn primary" to="/crew">Start a crew</Link>}
      </div>

      <ErrorNote error={error} />

      {matches.length === 0 ? (
        <Empty title="No matches yet">
          <p className="muted">Swipe right on people you'd team up with. When they like you back, they show up here.</p>
          <Link className="btn primary" to="/">Start swiping</Link>
        </Empty>
      ) : (
        <div className="grid">
          {matches.map((p) => (
            <article className="card person" key={p.id}>
              <div className="person-head">
                <Avatar src={p.avatar} name={p.name} size={56} />
                <div>
                  <h3>{p.name}</h3>
                  <Meta person={p} />
                </div>
                <Score value={p.score} />
              </div>
              {p.bio && <p className="bio">{p.bio}</p>}
              <div className="tags">{p.skills.map((s) => <Tag key={s}>{s}</Tag>)}</div>
              <a className="email" href={`mailto:${p.email}`}>✉ {p.email}</a>
              <div className="person-actions">
                {crewIds.has(p.id) ? (
                  <Tag tone="ok">In your crew</Tag>
                ) : p.inCrew ? (
                  <Tag>In another crew</Tag>
                ) : crew && crew.spotsLeft > 0 ? (
                  <button className="btn sm" onClick={() => addToCrew(p)}>+ Add to {crew.name}</button>
                ) : null}
                <button className="btn ghost sm" onClick={() => unmatch(p)}>Unmatch</button>
              </div>
            </article>
          ))}
        </div>
      )}
    </div>
  );
}
