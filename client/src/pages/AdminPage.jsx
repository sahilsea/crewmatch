import { useEffect, useMemo, useState } from 'react';
import { api } from '../api.js';
import { Avatar, ErrorNote, Spinner, Tag } from '../components/ui.jsx';
import { label } from '../labels.js';

// Horizontal bar list: one series, one hue, value printed at the end of each bar.
function BarList({ title, rows }) {
  const max = Math.max(...rows.map((r) => r.count), 1);
  return (
    <section className="card">
      <h2>{title}</h2>
      <ul className="bars">
        {rows.map((r) => (
          <li key={r.key} title={`${label(r.key)}: ${r.count}`}>
            <span className="bar-label">{label(r.key)}</span>
            <span className="bar-track"><span className="bar" style={{ width: `${(r.count / max) * 100}%` }} /></span>
            <span className="bar-value">{r.count}</span>
          </li>
        ))}
      </ul>
    </section>
  );
}

export default function AdminPage() {
  const [stats, setStats] = useState(null);
  const [users, setUsers] = useState([]);
  const [query, setQuery] = useState('');
  const [error, setError] = useState(null);

  async function load() {
    try {
      const [s, u] = await Promise.all([api.get('/admin/stats'), api.get('/admin/users')]);
      setStats(s);
      setUsers(u.users);
    } catch (err) {
      setError(err);
    }
  }

  useEffect(() => { load(); }, []);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return users;
    return users.filter((u) =>
      [u.name, u.email, u.role, ...(u.skills ?? [])].some((v) => v?.toLowerCase().includes(q)));
  }, [users, query]);

  if (error) return <ErrorNote error={error} />;
  if (!stats) return <Spinner />;

  const tiles = [
    ['Students', stats.totalUsers],
    ['Profiles complete', stats.completeProfiles],
    ['Matches made', stats.totalMatches],
    ['Crews formed', stats.crews],
  ];

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>Dashboard</h1>
          <p className="muted">Live numbers from the shared database. Activity on web and mobile shows up here.</p>
        </div>
        <button className="btn ghost" onClick={load}>Refresh</button>
      </div>

      <div className="tiles">
        {tiles.map(([k, v]) => (
          <div className="card tile" key={k}><b>{v}</b><span>{k}</span></div>
        ))}
      </div>

      <div className="two-col">
        <BarList title="Students by role" rows={stats.byRole.map((r) => ({ key: r.role, count: r.count }))} />
        <BarList title="Most popular interests" rows={stats.byInterest.map((r) => ({ key: r.interest, count: r.count }))} />
      </div>

      <section className="card">
        <div className="table-head">
          <h2>All students <span className="count">{filtered.length}</span></h2>
          <input type="search" placeholder="Search name, email, role, skill…" value={query} onChange={(e) => setQuery(e.target.value)} />
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
                      <Avatar src={u.avatar} name={u.name} size={32} />
                      <span><b>{u.name}</b><small>{u.email}</small></span>
                    </div>
                  </td>
                  <td>{u.role ? label(u.role) : '—'}</td>
                  <td className="skills-cell">{u.skills?.join(', ') || '—'}</td>
                  <td className="num">{u.matchCount}</td>
                  <td>{u.crewId ? 'Yes' : '—'}</td>
                  <td>
                    {u.profileComplete ? <Tag tone="ok">Active</Tag> : <Tag>Incomplete</Tag>}
                    {u.seed && <Tag>Seed</Tag>}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
