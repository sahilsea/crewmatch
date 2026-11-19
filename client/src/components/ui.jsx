// Small shared building blocks.
import { useState } from 'react';
import { Link } from 'react-router-dom';
import { label } from '../labels.js';

export function Spinner({ full, text = 'Loading' }) {
  return (
    <div className={full ? 'spinner-wrap full' : 'spinner-wrap'} role="status">
      <span className="loading-bar" aria-hidden="true"><span /></span>
      <p className="label">{text}…</p>
    </div>
  );
}

// A round portrait on a pink, blue or desk-pink backdrop (the illustrations are transparent line art).
export function Avatar({ src, name, size = 48, tone = 'desk' }) {
  const [broken, setBroken] = useState(false);
  const initials = name?.split(' ').map((w) => w[0]).slice(0, 2).join('') ?? '?';
  if (!src || broken) {
    return (
      <span className={`avatar fallback tone-${tone}`} style={{ width: size, height: size, fontSize: size * 0.42 }} aria-hidden="true">
        {initials}
      </span>
    );
  }
  return <img className={`avatar tone-${tone}`} src={src} alt="" width={size} height={size} onError={() => setBroken(true)} />;
}

// A big square portrait with the halftone print over it, for cards and info panels.
export function Photo({ src, name, children }) {
  const [broken, setBroken] = useState(false);
  return (
    <div className="photo">
      {src && !broken
        ? <img src={src} alt="" draggable="false" onError={() => setBroken(true)} />
        : <span className="photo-initials" aria-hidden="true">{name?.split(' ').map((w) => w[0]).slice(0, 2).join('')}</span>}
      {children}
    </div>
  );
}

export function Tag({ children, tone }) {
  return <span className={`tag ${tone ?? ''}`}>{children}</span>;
}

export function Empty({ title, children }) {
  return (
    <div className="empty">
      <h3>{title}</h3>
      {children}
    </div>
  );
}

export function ErrorNote({ error }) {
  if (!error) return null;
  return (
    <div className="error-note" role="alert">
      <b aria-hidden="true">!</b>
      <span>{error.message ?? String(error)}</span>
    </div>
  );
}

// The API's message for one form field, under the input.
export function FieldError({ children }) {
  return children ? <small className="field-error">{children}</small> : null;
}

export function Score({ value }) {
  const tone = value >= 75 ? 'great' : value >= 55 ? 'good' : 'ok';
  return <span className={`score ${tone}`}>{value}% fit</span>;
}

// A crew's points and leaderboard rank (from GET /crews/mine), linking to the leaderboard.
export function Scoreboard({ crew }) {
  return (
    <Link to="/leaderboard" className="scoreboard">
      <span className="score-num">{crew.points}</span>
      <span className="label">points</span>
      <span className="score-rank">{crew.rank ? `Rank #${crew.rank}` : 'Not ranked yet'}</span>
      <span className="label score-link">Leaderboard →</span>
    </Link>
  );
}

// One line of role, level and schedule, e.g. "Backend · Advanced · Night owl".
export function Meta({ person }) {
  return (
    <p className="meta">
      {[person.role, person.experienceLevel, person.schedule].filter(Boolean).map(label).join(' · ')}
    </p>
  );
}
