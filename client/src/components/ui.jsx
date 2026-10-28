// Small shared building blocks.
import { useEffect, useState } from 'react';
import { api } from '../api.js';
import { label } from '../labels.js';

export function Spinner({ full, text }) {
  return (
    <div className={full ? 'spinner-wrap full' : 'spinner-wrap'}>
      <div className="spinner" aria-label="Loading" />
      {text && <p className="muted">{text}</p>}
    </div>
  );
}

export function Avatar({ src, name, size = 48 }) {
  const [broken, setBroken] = useState(false);
  const initials = name?.split(' ').map((w) => w[0]).slice(0, 2).join('') ?? '?';
  if (!src || broken) {
    return <span className="avatar fallback" style={{ width: size, height: size, fontSize: size * 0.38 }}>{initials}</span>;
  }
  return <img className="avatar" src={src} alt="" width={size} height={size} onError={() => setBroken(true)} />;
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
  return <div className="error-note" role="alert">{error.message ?? String(error)}</div>;
}

export function Score({ value }) {
  const tone = value >= 75 ? 'great' : value >= 55 ? 'good' : 'ok';
  return <span className={`score ${tone}`}>{value}% fit</span>;
}

// One line of role, level and schedule, e.g. "Backend · Advanced · Night owl".
export function Meta({ person }) {
  return (
    <p className="meta">
      {[person.role, person.experienceLevel, person.schedule].filter(Boolean).map(label).join(' · ')}
    </p>
  );
}

// The option lists never change while the app runs, so fetch them once.
let optionsCache;
export function useOptions() {
  const [options, setOptions] = useState(optionsCache);
  useEffect(() => {
    if (optionsCache) return;
    api.get('/options').then((o) => { optionsCache = o; setOptions(o); });
  }, []);
  return options;
}
