import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../api.js';
import { useAuth } from '../auth.jsx';
import { Avatar, Empty, ErrorNote, Meta, Spinner, Tag } from '../components/ui.jsx';
import { CHECKLIST_LABELS } from '../labels.js';

const MAX_CREW = 4;

function CreateCrew({ matches, onCreated }) {
  const free = matches.filter((m) => !m.inCrew);
  const [name, setName] = useState('');
  const [picked, setPicked] = useState([]);
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);

  const toggle = (id) =>
    setPicked((p) => (p.includes(id) ? p.filter((x) => x !== id) : p.length < MAX_CREW - 1 ? [...p, id] : p));

  async function submit(e) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      const { crew } = await api.post('/crews', { name, memberIds: picked });
      onCreated(crew);
    } catch (err) {
      setError(err);
    } finally {
      setBusy(false);
    }
  }

  if (matches.length === 0) {
    return (
      <Empty title="Match with people first">
        <p className="muted">A crew is built from your matches. Swipe right on a few people to get started.</p>
        <Link className="btn primary" to="/">Start swiping</Link>
      </Empty>
    );
  }

  return (
    <form className="card form-card" onSubmit={submit}>
      <h2>Start a crew</h2>
      <p className="muted">Pick up to {MAX_CREW - 1} of your matches. Once you have a crew, your deck looks for whoever fills its gaps.</p>
      <label className="field">
        <span>Crew name</span>
        <input value={name} onChange={(e) => setName(e.target.value)} placeholder="e.g. Night Owls" required minLength={2} maxLength={50} />
      </label>
      <fieldset className="pick-list">
        <legend>Members <span className="muted">({picked.length}/{MAX_CREW - 1})</span></legend>
        {free.length === 0 && <p className="muted">All your matches are already in crews. You can start one on your own.</p>}
        {free.map((m) => (
          <label key={m.id} className={`pick ${picked.includes(m.id) ? 'on' : ''}`}>
            <input type="checkbox" checked={picked.includes(m.id)} onChange={() => toggle(m.id)}
              disabled={!picked.includes(m.id) && picked.length >= MAX_CREW - 1} />
            <Avatar src={m.avatar} name={m.name} size={36} />
            <span><b>{m.name}</b><Meta person={m} /></span>
          </label>
        ))}
      </fieldset>
      <ErrorNote error={error} />
      <button className="btn primary" disabled={busy || name.trim().length < 2}>{busy ? 'Creating…' : 'Create crew'}</button>
    </form>
  );
}

export default function CrewPage() {
  const { user, refresh } = useAuth();
  const [crew, setCrew] = useState(undefined);
  const [matches, setMatches] = useState([]);
  const [error, setError] = useState(null);
  const [rename, setRename] = useState(null);

  const load = useCallback(async () => {
    try {
      const [c, m] = await Promise.all([api.get('/crews/mine'), api.get('/matches')]);
      setCrew(c.crew);
      setMatches(m.matches);
    } catch (err) {
      setError(err);
      setCrew(null);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  async function act(fn) {
    setError(null);
    try { await fn(); } catch (err) { setError(err); }
  }

  const addMember = (id) => act(async () => {
    const { crew: c } = await api.post('/crews/mine/members', { userId: id });
    setCrew(c);
    setMatches((list) => list.map((m) => (m.id === id ? { ...m, inCrew: true } : m)));
  });

  const saveName = (e) => {
    e.preventDefault();
    act(async () => {
      const { crew: c } = await api.patch('/crews/mine', { name: rename });
      setCrew(c);
      setRename(null);
    });
  };

  const leave = () => act(async () => {
    if (!confirm(`Leave ${crew.name}?${crew.members.length === 2 ? ' The crew will be dissolved.' : ''}`)) return;
    await api.del('/crews/mine');
    await refresh();
    load();
  });

  if (crew === undefined) return <Spinner />;

  if (!crew) {
    return (
      <div>
        <div className="page-head"><div><h1>Crew</h1></div></div>
        <ErrorNote error={error} />
        <CreateCrew matches={matches} onCreated={(c) => { setCrew(c); refresh(); load(); }} />
      </div>
    );
  }

  const addable = matches.filter((m) => !m.inCrew && !crew.members.some((c) => c.id === m.id));
  const missing = Object.entries(crew.checklist).filter(([, ok]) => !ok).map(([k]) => CHECKLIST_LABELS[k]);

  return (
    <div>
      <div className="page-head">
        <div>
          {rename === null ? (
            <h1>{crew.name} <button className="link" onClick={() => setRename(crew.name)}>Rename</button></h1>
          ) : (
            <form className="rename" onSubmit={saveName}>
              <input value={rename} onChange={(e) => setRename(e.target.value)} autoFocus minLength={2} maxLength={50} />
              <button className="btn sm primary">Save</button>
              <button type="button" className="btn sm ghost" onClick={() => setRename(null)}>Cancel</button>
            </form>
          )}
          <p className="muted">{crew.members.length} of {MAX_CREW} members · {crew.spotsLeft} spot{crew.spotsLeft === 1 ? '' : 's'} left</p>
        </div>
        <button className="btn ghost" onClick={leave}>Leave crew</button>
      </div>

      <ErrorNote error={error} />

      <section className="card checklist">
        <h2>What your crew covers</h2>
        <ul>
          {Object.entries(crew.checklist).map(([k, ok]) => (
            <li key={k} className={ok ? 'ok' : 'miss'}>
              <span aria-hidden>{ok ? '✓' : '✗'}</span> {CHECKLIST_LABELS[k]}
              <span className="sr-only">{ok ? 'covered' : 'missing'}</span>
            </li>
          ))}
        </ul>
        {missing.length > 0 && crew.spotsLeft > 0 && (
          <p className="muted">Still missing {missing.join(' and ')}. <Link to="/">Your deck</Link> now ranks people who fill that gap first.</p>
        )}
      </section>

      <div className="grid">
        {crew.members.map((m) => (
          <article className="card person" key={m.id}>
            <div className="person-head">
              <Avatar src={m.avatar} name={m.name} size={56} />
              <div>
                <h3>{m.name} {m.id === user.id && <Tag>You</Tag>}</h3>
                <Meta person={m} />
              </div>
            </div>
            <div className="tags">{m.skills.map((s) => <Tag key={s}>{s}</Tag>)}</div>
            {m.id !== user.id && <a className="email" href={`mailto:${m.email}`}>✉ {m.email}</a>}
          </article>
        ))}
      </div>

      {crew.spotsLeft > 0 && addable.length > 0 && (
        <section className="card add-members">
          <h2>Add from your matches</h2>
          {addable.map((m) => (
            <div className="pick" key={m.id}>
              <Avatar src={m.avatar} name={m.name} size={36} />
              <span><b>{m.name}</b><Meta person={m} /></span>
              <button className="btn sm" onClick={() => addMember(m.id)}>Add</button>
            </div>
          ))}
        </section>
      )}

      <section className="card ideas">
        <h2>Project ideas</h2>
        {crew.ideas.length
          ? crew.ideas.map((i) => <div key={i.title}><h3>{i.title}</h3><p>{i.pitch}</p></div>)
          : <p className="muted">AI-suggested projects for your crew are coming soon.</p>}
      </section>
    </div>
  );
}
