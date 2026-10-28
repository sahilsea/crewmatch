import { NavLink, useNavigate } from 'react-router-dom';
import { useAuth } from '../auth.jsx';
import { Avatar } from './ui.jsx';

export function Logo() {
  return (
    <span className="logo">
      <img src="/favicon.svg" alt="" width="28" height="28" />
      Crew<b>Match</b>
    </span>
  );
}

export default function Layout({ children }) {
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  const links = user.isAdmin
    ? [['/admin', 'Dashboard']]
    : [['/', 'Discover'], ['/matches', 'Matches'], ['/crew', 'Crew'], ['/profile', 'Profile']];

  return (
    <div className="shell">
      <header className="topbar">
        <NavLink to="/" className="brand"><Logo /></NavLink>
        <nav className="nav">
          {user.profileComplete || user.isAdmin
            ? links.map(([to, text]) => (
                <NavLink key={to} to={to} end className={({ isActive }) => (isActive ? 'active' : '')}>
                  {text}
                </NavLink>
              ))
            : <span className="muted">Finish your profile to start swiping</span>}
        </nav>
        <div className="me">
          <Avatar src={user.avatar} name={user.name} size={32} />
          <span className="me-name">{user.name}</span>
          <button className="btn ghost sm" onClick={() => { logout(); navigate('/login'); }}>Log out</button>
        </div>
      </header>
      <main className="page">{children}</main>
    </div>
  );
}
