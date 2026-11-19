import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api } from '../api.js';
import { useAuth } from '../auth.jsx';
import { useOptions } from '../hooks.js';
import { StatusStrip, Window } from '../components/retro.jsx';
import { Avatar, ErrorNote, FieldError, Spinner } from '../components/ui.jsx';
import { FIELD_LABELS, label } from '../labels.js';

const SINGLE = ['role', 'experienceLevel', 'schedule', 'commitment', 'communication'];
const FIELDS = ['name', 'bio', ...SINGLE, 'interests', 'superpowers', 'skills'];

function ChipGroup({ name, values, selected, multi, max, onChange }) {
  const isOn = (v) => (multi ? selected.includes(v) : selected === v);
  function toggle(v) {
    if (!multi) return onChange(v);
    if (selected.includes(v)) return onChange(selected.filter((x) => x !== v));
    if (max && selected.length >= max) return;
    onChange([...selected, v]);
  }
  return (
    <fieldset className="chip-group">
      <legend>{FIELD_LABELS[name]}</legend>
      <div className="chips">
        {values.map((v) => (
          <button
            type="button" key={v} aria-pressed={isOn(v)}
            className={`chip ${isOn(v) ? 'on' : ''}`}
            disabled={multi && max && !isOn(v) && selected.length >= max}
            onClick={() => toggle(v)}
          >
            {label(v)}
          </button>
        ))}
      </div>
    </fieldset>
  );
}

function SkillsInput({ skills, onChange }) {
  const [text, setText] = useState('');
  function add() {
    const parts = text.split(',').map((s) => s.trim()).filter(Boolean);
    const next = [...skills];
    for (const p of parts) if (!next.some((s) => s.toLowerCase() === p.toLowerCase())) next.push(p);
    onChange(next.slice(0, 15));
    setText('');
  }
  return (
    <fieldset className="chip-group">
      <legend>Skills <span className="muted">(type, then Enter)</span></legend>
      {skills.length > 0 && (
        <div className="chips">
          {skills.map((s) => (
            <span className="chip on removable" key={s}>
              {s}
              <button type="button" aria-label={`Remove ${s}`} onClick={() => onChange(skills.filter((x) => x !== s))}>×</button>
            </span>
          ))}
        </div>
      )}
      <input
        value={text} placeholder="React, Figma, Python…" maxLength={60} aria-label="Add a skill"
        onChange={(e) => setText(e.target.value)}
        onKeyDown={(e) => { if (e.key === 'Enter' || e.key === ',') { e.preventDefault(); add(); } }}
        onBlur={add}
      />
    </fieldset>
  );
}

export default function ProfilePage() {
  const { user, setUser, logout } = useAuth();
  const options = useOptions();
  const navigate = useNavigate();
  const firstTime = !user.profileComplete;

  const [form, setForm] = useState(() => ({
    ...Object.fromEntries(FIELDS.map((f) => [f, user[f] ?? ''])),
    interests: user.interests ?? [],
    superpowers: user.superpowers ?? [],
    skills: user.skills ?? [],
  }));
  const [error, setError] = useState(null);
  const [saved, setSaved] = useState(false);
  const [busy, setBusy] = useState(false);

  if (!options) return <Spinner />;

  const set = (k) => (v) => { setForm((f) => ({ ...f, [k]: v })); setSaved(false); };
  const fieldErrors = error?.fieldErrors ?? {};
  const missing = [
    ...SINGLE.filter((f) => !form[f]).map((f) => FIELD_LABELS[f].toLowerCase()),
    ...(form.interests.length ? [] : ['an interest']),
    ...(form.skills.length ? [] : ['a skill']),
  ];

  async function save(e) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      // Only send the fields the user has filled in.
      const body = Object.fromEntries(Object.entries(form).filter(([, v]) => v !== ''));
      const { user: updated } = await api.put('/users/me', body);
      setUser(updated);
      setSaved(true);
      if (firstTime && updated.profileComplete) navigate('/');
    } catch (err) {
      setError(err);
    } finally {
      setBusy(false);
    }
  }

  async function deleteAccount() {
    if (!confirm('Delete your account? Your matches and crew membership will be removed. This cannot be undone.')) return;
    try {
      await api.del('/users/me');
      logout();
      navigate('/login');
    } catch (err) {
      setError(err);
    }
  }

  return (
    <div className="workspace profile-desk">
      <div className="desk-main">
        <Window title={firstTime ? 'Build your profile' : 'Your profile'} titleAs="h1" inset={false} collapsible={false}>
          <form onSubmit={save}>
            <div className="profile-head halftone blue">
              <Avatar src={user.avatar} name={user.name} size={84} tone="desk" />
              <div>
                <p className="serif-title">{form.name || user.name}</p>
                <p className="label ink">
                  {firstTime ? 'Tap the options that fit. Your matches are scored on them.' : 'Changes reach your deck on web and mobile'}
                </p>
              </div>
            </div>

            <div className="form-body">
              <div className="two-col">
                <label className="field">
                  <span>Name</span>
                  <input value={form.name} onChange={(e) => set('name')(e.target.value)} required minLength={2} />
                  <FieldError>{fieldErrors.name}</FieldError>
                </label>
                <label className="field">
                  <span>Email</span>
                  <input value={user.email} disabled />
                </label>
              </div>
              <label className="field">
                <span>Bio ({280 - form.bio.length} left)</span>
                <textarea
                  rows={2} maxLength={280} value={form.bio} placeholder="One line about what you bring to a team."
                  onChange={(e) => set('bio')(e.target.value)}
                />
                <FieldError>{fieldErrors.bio}</FieldError>
              </label>

              <ChipGroup name="role" values={options.role} selected={form.role} onChange={set('role')} />
              <div className="chip-pair">
                {SINGLE.slice(1).map((f) => (
                  <ChipGroup key={f} name={f} values={options[f]} selected={form[f]} onChange={set(f)} />
                ))}
              </div>
              <ChipGroup name="interests" values={options.interests} selected={form.interests} multi onChange={set('interests')} />
              <ChipGroup
                name="superpowers" values={options.superpowers} selected={form.superpowers} multi
                max={options.maxSuperpowers} onChange={set('superpowers')}
              />
              <SkillsInput skills={form.skills} onChange={set('skills')} />
              <ErrorNote error={error} />
            </div>

            <div className="form-foot">
              <span className="label">
                {missing.length ? `Still needed: ${missing.join(', ')}` : saved ? 'Saved ✓' : 'Looks good!'}
              </span>
              <button className="btn primary" disabled={busy || missing.length > 0}>
                {busy ? 'Saving…' : firstTime ? 'Save and start swiping' : 'Save changes'}
              </button>
            </div>
          </form>
        </Window>
      </div>

      {!firstTime && (
        <div className="desk-side">
          <Window title="Account" inset={false}>
            <div className="side-body">
              <p>Signed in as <b>{user.email}</b>.</p>
              <button type="button" className="btn" onClick={() => { logout(); navigate('/login'); }}>Log out</button>
            </div>
            <div className="side-body danger">
              <p className="report-headline">Delete account</p>
              <p className="muted">Removes your profile, matches and crew membership everywhere.</p>
              <button type="button" className="btn dark" onClick={deleteAccount}>Delete account</button>
            </div>
            <StatusStrip>{user.matchCount} matches · {user.crewId ? 'in a crew' : 'no crew yet'}</StatusStrip>
          </Window>
        </div>
      )}
    </div>
  );
}
