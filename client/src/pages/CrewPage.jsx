import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../api.js';
import { useAuth } from '../auth.jsx';
import { Window } from '../components/retro.jsx';
import { Avatar, Empty, ErrorNote, Meta, Scoreboard, Spinner, Tag } from '../components/ui.jsx';
import { CheckIcon, CloseIcon } from '../components/icons.jsx';
import { CHECKLIST_LABELS, label } from '../labels.js';
import { toneFor } from '../format.js';

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
      <Window title="Crew" titleAs="h1">
        <Empty title="Match with people first">
          <p>A crew is built from your matches. Swipe right on a few people to get started.</p>
          <Link className="btn primary" to="/">Start swiping</Link>
        </Empty>
      </Window>
    );
  }

  return (
    <Window title="Start a crew" titleAs="h1" inset={false} strip={`${picked.length} of ${MAX_CREW - 1} picked`}>
      <form className="form-body" onSubmit={submit}>
        <p>Pick up to {MAX_CREW - 1} of your matches. Once you have a crew, your deck looks for whoever fills its gaps, and you can take it to events and challenges.</p>
        <label className="field">
          <span>Crew name</span>
          <input value={name} onChange={(e) => setName(e.target.value)} placeholder="e.g. Night Owls" required minLength={2} maxLength={50} />
        </label>
        <fieldset className="chip-group pick-list">
          <legend>Members</legend>
          {free.length === 0 && <p className="muted">All your matches are already in crews. You can start one on your own.</p>}
          {free.map((m) => (
            <label key={m.id} className={`pick ${picked.includes(m.id) ? 'on' : ''}`}>
              <input
                type="checkbox" checked={picked.includes(m.id)} onChange={() => toggle(m.id)}
                disabled={!picked.includes(m.id) && picked.length >= MAX_CREW - 1}
              />
              <Avatar src={m.avatar} name={m.name} size={36} tone={toneFor(m.id)} />
              <span className="pick-text"><b>{m.name}</b><Meta person={m} /></span>
            </label>
          ))}
        </fieldset>
        <ErrorNote error={error} />
        <div className="row">
          <button className="btn primary" disabled={busy || name.trim().length < 2}>{busy ? 'Creating…' : 'Create crew'}</button>
        </div>
      </form>
    </Window>
  );
}

export default function CrewPage() {
  const { user, refresh } = useAuth();
  const [crew, setCrew] = useState(undefined);
  const [matches, setMatches] = useState([]);
  const [error, setError] = useState(null);
  const [rename, setRename] = useState(null);
  const [version, setVersion] = useState(0);

  useEffect(() => {
    let live = true;
    Promise.all([api.get('/crews/mine'), api.get('/matches')])
      .then(([c, m]) => {
        if (!live) return;
        setCrew(c.crew);
        setMatches(m.matches);
      })
      .catch((err) => {
        if (!live) return;
        setError(err);
        setCrew(null);
      });
    return () => { live = false; };
  }, [version]);

  const reload = () => setVersion((v) => v + 1);

  async function act(fn) {
    setError(null);
    try { await fn(); } catch (err) { setError(err); }
  }

  const addMember = (id) => act(async () => {
    const { crew: c } = await api.post('/crews/mine/members', { userId: id });
    setCrew((old) => ({ ...old, ...c }));
    setMatches((list) => list.map((m) => (m.id === id ? { ...m, inCrew: true } : m)));
  });

  const saveName = (e) => {
    e.preventDefault();
    act(async () => {
      const { crew: c } = await api.patch('/crews/mine', { name: rename });
      setCrew((old) => ({ ...old, ...c }));
      setRename(null);
    });
  };

  const leave = () => act(async () => {
    if (!confirm(`Leave ${crew.name}?${crew.members.length === 2 ? ' The crew will be dissolved.' : ''}`)) return;
    await api.del('/crews/mine');
    await refresh();
    reload();
  });

  if (crew === undefined) return <Spinner />;

  if (!crew) {
    return (
      <div className="workspace single">
        <div className="desk-main">
          <ErrorNote error={error} />
          <CreateCrew matches={matches} onCreated={(c) => { setCrew(c); refresh(); reload(); }} />
        </div>
      </div>
    );
  }

  const addable = matches.filter((m) => !m.inCrew && !crew.members.some((c) => c.id === m.id));
  const missing = Object.entries(crew.checklist).filter(([, ok]) => !ok).map(([k]) => CHECKLIST_LABELS[k]);

  return (
    <div className="workspace crew-desk">
      <div className="desk-main">
        <Window title="Crew" titleAs="h1" inset={false} strip={`${crew.members.length} members · ${crew.spotsLeft} ${crew.spotsLeft === 1 ? 'spot' : 'spots'} left`}>
          <div className="crew-head halftone blue">
            <div className="crew-title">
              {rename === null ? (
                <h2 className="crew-name">{crew.name}</h2>
              ) : (
                <form className="rename" onSubmit={saveName}>
                  <label className="sr-only" htmlFor="crew-name">Crew name</label>
                  <input id="crew-name" value={rename} onChange={(e) => setRename(e.target.value)} autoFocus minLength={2} maxLength={50} />
                  <button className="btn sm primary">Save</button>
                  <button type="button" className="btn sm" onClick={() => setRename(null)}>Cancel</button>
                </form>
              )}
              <p className="label ink">
                {crew.members.length} of {MAX_CREW} members · {crew.spotsLeft} {crew.spotsLeft === 1 ? 'spot' : 'spots'} left
              </p>
            </div>
            <div className="row">
              {rename === null && <button type="button" className="btn sm" onClick={() => setRename(crew.name)}>Rename</button>}
              <button type="button" className="btn sm" onClick={leave}>Leave crew</button>
            </div>
          </div>

          {crew.points !== undefined && <Scoreboard crew={crew} />}

          <ErrorNote error={error} />
          <ul className="member-list">
            {crew.members.map((m) => (
              <li className="member" key={m.id}>
                <Avatar src={m.avatar} name={m.name} size={44} tone={toneFor(m.id)} />
                <div className="member-text">
                  <p className="member-name">{m.name} {m.id === user.id && <Tag tone="ink">You</Tag>}</p>
                  <p className="label small">{[m.role && label(m.role), ...m.skills].filter(Boolean).join(' · ')}</p>
                </div>
                {m.id !== user.id && <a className="label ink" href={`mailto:${m.email}`}>Email</a>}
              </li>
            ))}
          </ul>
        </Window>
      </div>

      <div className="desk-side">
        <Window title="Coverage" inset={false}>
          <ul className="checklist">
            {Object.entries(crew.checklist).map(([k, ok]) => (
              <li key={k} className={ok ? 'ok' : 'miss'}>
                <span className="check-box" aria-hidden="true">{ok ? <CheckIcon /> : <CloseIcon />}</span>
                {CHECKLIST_LABELS[k]}
                <span className="label small">{ok ? 'covered' : 'missing'}</span>
              </li>
            ))}
          </ul>
          {missing.length > 0 && crew.spotsLeft > 0 && (
            <p className="side-note">Still missing {missing.join(' and ')}. <Link to="/">Your deck</Link> now ranks people who fill that gap first.</p>
          )}
        </Window>

        {crew.spotsLeft > 0 && addable.length > 0 && (
          <Window title="Add members" inset={false}>
            <ul className="add-list">
              {addable.map((m) => (
                <li key={m.id}>
                  <Avatar src={m.avatar} name={m.name} size={34} tone={toneFor(m.id)} />
                  <span className="add-name">{m.name}<span className="label small">{label(m.role)}</span></span>
                  <button type="button" className="btn sm primary" onClick={() => addMember(m.id)}>Add<span className="sr-only"> {m.name}</span></button>
                </li>
              ))}
            </ul>
          </Window>
        )}

        <Window title="Ideas.txt">
          <div className="ideas">
            {crew.ideas.length
              ? crew.ideas.map((i) => <div key={i.title}><p className="report-headline">{i.title}</p><p>{i.pitch}</p></div>)
              : <p className="muted">AI-suggested projects for your crew are coming soon.</p>}
          </div>
        </Window>
      </div>
    </div>
  );
}
