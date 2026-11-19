import { Suspense, useEffect, useRef, useState } from 'react';
import { Link, NavLink, useNavigate } from 'react-router-dom';
import { useAuth } from '../auth.jsx';
import { useNow } from '../hooks.js';
import { clockTime, menuDate } from '../format.js';
import { Avatar, Spinner } from './ui.jsx';
import {
  ClockIcon, CrewIcon, DashboardIcon, DiscoverIcon, EventsIcon, LeaderboardIcon, LogoIcon, MatchesIcon, ProfileIcon,
} from './icons.jsx';

// [path, label, icon, short label for the phone dock]
const MEMBER_DOCK = [
  ['/', 'Discover', DiscoverIcon],
  ['/matches', 'Matches', MatchesIcon],
  ['/crew', 'Crew', CrewIcon],
  ['/events', 'Events', EventsIcon],
  ['/leaderboard', 'Leaderboard', LeaderboardIcon, 'Ranks'],
  ['/profile', 'Profile', ProfileIcon],
];
const ADMIN_DOCK = [
  ['/admin', 'Dashboard', DashboardIcon],
  ['/admin/events', 'Events', EventsIcon],
  ['/leaderboard', 'Leaderboard', LeaderboardIcon, 'Ranks'],
];

// Tabs hanging from the top edge: logo, app name and who is signed in; the date and a live clock on the right.
export function MenuBar() {
  const { user } = useAuth();
  const now = useNow(10_000);

  return (
    <header className="menubar">
      <div className="menu-group">
        <Link to="/" className="menu-logo" aria-label="CrewMatch home"><LogoIcon /></Link>
        <span className="menu-tab menu-brand">CrewMatch{user?.isAdmin && ' · Admin'}</span>
        {user ? <UserMenu user={user} /> : <span className="menu-tab tone-blue">Join / Sign in</span>}
      </div>
      <div className="menu-group menu-right">
        <span className="menu-tab">{menuDate(now)}</span>
        <span className="menu-tab"><ClockIcon /><time dateTime={now.toISOString()}>{clockTime(now)}</time></span>
      </div>
    </header>
  );
}

// Avatar, name and Log out. On phones only the avatar shows; it opens a small menu with the rest.
function UserMenu({ user }) {
  const { logout } = useAuth();
  const navigate = useNavigate();
  const [open, setOpen] = useState(false);
  const ref = useRef(null);

  // Close on a press elsewhere or on Escape.
  useEffect(() => {
    if (!open) return;
    const onDown = (e) => { if (!ref.current.contains(e.target)) setOpen(false); };
    const onKey = (e) => { if (e.key === 'Escape') setOpen(false); };
    document.addEventListener('pointerdown', onDown);
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('pointerdown', onDown);
      document.removeEventListener('keydown', onKey);
    };
  }, [open]);

  function signOut() {
    logout();
    navigate('/login');
  }

  return (
    <div className="menu-user-wrap" ref={ref}>
      <div className="menu-tab menu-user">
        <button type="button" className="menu-who" aria-expanded={open} onClick={() => setOpen((o) => !o)}>
          <Avatar src={user.avatar} name={user.name} size={22} />
          <span className="menu-name">{user.name}</span>
          <span className="sr-only">: account menu</span>
        </button>
        <button type="button" className="menu-logout" onClick={signOut}>Log out</button>
      </div>
      {open && (
        <div className="menu-pop">
          <p className="menu-pop-name">{user.name}</p>
          <p className="label">{user.email}</p>
          {!user.isAdmin && <Link className="btn sm" to="/profile" onClick={() => setOpen(false)}>Edit profile</Link>}
          <button type="button" className="btn sm primary" onClick={signOut}>Log out</button>
        </div>
      )}
    </div>
  );
}

// The app switcher along the bottom edge. Students get it once their profile is complete.
function Dock() {
  const { user } = useAuth();
  const items = user.isAdmin ? ADMIN_DOCK : user.profileComplete ? MEMBER_DOCK : null;

  return (
    <nav className="dock" aria-label="Main">
      {items ? items.map(([to, text, Icon, short]) => (
        <NavLink key={to} to={to} end={to === '/' || to === '/admin'} className="dock-tile" aria-label={short && text}>
          <Icon />
          <span className={short ? 'dock-label long' : 'dock-label'}>{text}</span>
          {short && <span className="dock-label short">{short}</span>}
        </NavLink>
      )) : (
        <p className="dock-note">Finish your profile to start swiping</p>
      )}
    </nav>
  );
}

export default function Layout({ children }) {
  return (
    <div className="shell">
      <MenuBar />
      <main className="page"><Suspense fallback={<Spinner />}>{children}</Suspense></main>
      <Dock />
    </div>
  );
}
