import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../api.js';
import { Window } from '../components/retro.jsx';
import { Avatar, ErrorNote, Spinner, Tag } from '../components/ui.jsx';
import { label } from '../labels.js';
import { toneFor } from '../format.js';

// Horizontal bar list: one series, one hue, value printed at the end of each bar.
function BarList({ title, rows }) {
  const max = Math.max(...rows.map((r) => r.count), 1);
  return (
    <Window title={title} inset={false}>
      <ul className="bars">
        {rows.map((r) => (
          <li key={r.key} title={`${label(r.key)}: ${r.count}`}>
            <span className="bar-label">{label(r.key)}</span>
            <span className="bar-track"><span className="bar" style={{ width: `${(r.count / max) * 100}%` }} /></span>
            <span className="bar-value">{r.count}</span>
          </li>
        ))}
      </ul>
    </Window>
  );
}

export default function AdminPage() {
  const [stats, setStats] = useState(null);
  const [users, setUsers] = useState([]);
  const [query, setQuery] = useState('');
  const [error, setError] = useState(null);
  const [version, setVersion] = useState(0);

  useEffect(() => {
    let live = true;
    Promise.all([api.get('/admin/stats'), api.get('/admin/users')])
      .then(([s, u]) => {
        if (!live) return;
        setStats(s);
        setUsers(u.users);
        setError(null);
      })
      .catch((err) => live && setError(err));
    return () => { live = false; };
  }, [version]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return users;
    return users.filter((u) =>
      [u.name, u.email, u.role, ...(u.skills ?? [])].some((v) => v?.toLowerCase().includes(q)));
  }, [users, query]);

  if (!stats) return error ? <ErrorNote error={error} /> : <Spinner />;

  // [label, value, tile colour]
  const tiles = [
    ['Students', stats.totalUsers, 'pink'],
    ['Profiles complete', stats.completeProfiles, 'desk'],
    ['Matches made', stats.totalMatches, 'blue'],
    ['Crews formed', stats.crews, 'strip'],
  ];
  const hub = [
    ['Events', stats.events, 'blue'],
    ['Challenges', stats.challenges, 'pink'],
    ['Waiting for review', stats.pendingSubmissions, stats.pendingSubmissions ? 'dark' : 'strip'],
  ];

  return (
    <div className="admin-page">
      <Window
        title="Dashboard" titleAs="h1" inset={false}
        action={<button type="button" className="btn mono sm" onClick={() => setVersion((v) => v + 1)}>Refresh</button>}
        strip="Live from the shared database · web + mobile"
      >
        <ErrorNote error={error} />
        <div className="stat-row">
          {tiles.map(([k, v, tone]) => (
            <div className={`big-stat ${tone}`} key={k}><b>{v}</b><span>{k}</span></div>
          ))}
        </div>
        {stats.events !== undefined && (
          <div className="stat-row hub">
            {hub.map(([k, v, tone]) => (
              <Link className={`big-stat ${tone}`} key={k} to="/admin/events"><b>{v}</b><span>{k}</span></Link>
            ))}
          </div>
        )}
      </Window>

      <div className="two-up">
        <BarList title="Students by role" rows={stats.byRole.map((r) => ({ key: r.role, count: r.count }))} />
        <BarList title="Top interests" rows={stats.byInterest.map((r) => ({ key: r.interest, count: r.count }))} />
      </div>

      <Window title="All students" inset={false} strip={`${filtered.length} ${filtered.length === 1 ? 'item' : 'items'}`}>
        <div className="table-tools">
          <input
            type="search" placeholder="Search name, email, role, skill…" aria-label="Search students"
            value={query} onChange={(e) => setQuery(e.target.value)}
          />
        </div>
        <div className="table-wrap">
          <table>
            <thead>
              <tr><th>Student</th><th>Role</th><th>Skills</th><th className="num">Matches</th><th>Crew</th><th>Status</th></tr>
            </thead>
            <tbody>
              {filtered.map((u) => (
                <tr key={u.id}>
                  <td>
                    <div className="who">
                      <Avatar src={u.avatar} name={u.name} size={32} tone={toneFor(u.id)} />
                      <span><b>{u.name}</b><small>{u.email}</small></span>
                    </div>
                  </td>
                  <td>{u.role ? label(u.role) : '—'}</td>
                  <td className="skills-cell">{u.skills?.join(', ') || '—'}</td>
                  <td className="num">{u.matchCount}</td>
                  <td>{u.crewId ? 'Yes' : '—'}</td>
                  <td>
                    {u.profileComplete ? <Tag tone="blue">Active</Tag> : <Tag>Incomplete</Tag>}
                    {u.seed && <Tag>Seed</Tag>}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Window>
    </div>
  );
}
