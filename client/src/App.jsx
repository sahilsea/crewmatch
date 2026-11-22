import { lazy } from 'react';
import { Navigate, Route, Routes, useLocation } from 'react-router-dom';
import { useAuth } from './auth.jsx';
import Layout from './components/Layout.jsx';
import { Spinner } from './components/ui.jsx';
import AuthPage from './pages/AuthPage.jsx';

// Each page loads on first visit, so students never download the admin pages.
const ProfilePage = lazy(() => import('./pages/ProfilePage.jsx'));
const DiscoverPage = lazy(() => import('./pages/DiscoverPage.jsx'));
const MatchesPage = lazy(() => import('./pages/MatchesPage.jsx'));
const CrewPage = lazy(() => import('./pages/CrewPage.jsx'));
const EventsPage = lazy(() => import('./pages/EventsPage.jsx'));
const LeaderboardPage = lazy(() => import('./pages/LeaderboardPage.jsx'));
const AdminPage = lazy(() => import('./pages/AdminPage.jsx'));
const AdminEventsPage = lazy(() => import('./pages/AdminEventsPage.jsx'));

// Guards a page: signed in, profile finished (for students), admin when asked.
// Admins only see admin pages, plus any page marked `adminToo`.
function Guard({ children, needsProfile = false, adminOnly = false, adminToo = false }) {
  const { user, loading } = useAuth();
  const location = useLocation();

  if (loading) return <Spinner full />;
  if (!user) return <Navigate to="/login" replace state={{ from: location.pathname }} />;
  if (adminOnly && !user.isAdmin) return <Navigate to="/" replace />;
  if (user.isAdmin && !adminOnly && !adminToo) return <Navigate to="/admin" replace />;
  if (needsProfile && !user.isAdmin && !user.profileComplete) return <Navigate to="/profile" replace />;
  return <Layout>{children}</Layout>;
}

function PublicOnly({ children }) {
  const { user, loading } = useAuth();
  if (loading) return <Spinner full />;
  return user ? <Navigate to="/" replace /> : children;
}

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<PublicOnly><AuthPage mode="login" /></PublicOnly>} />
      <Route path="/register" element={<PublicOnly><AuthPage mode="register" /></PublicOnly>} />
      <Route path="/" element={<Guard needsProfile><DiscoverPage /></Guard>} />
      <Route path="/profile" element={<Guard><ProfilePage /></Guard>} />
      <Route path="/matches" element={<Guard needsProfile><MatchesPage /></Guard>} />
      <Route path="/crew" element={<Guard needsProfile><CrewPage /></Guard>} />
      <Route path="/events" element={<Guard needsProfile><EventsPage /></Guard>} />
      <Route path="/leaderboard" element={<Guard needsProfile adminToo><LeaderboardPage /></Guard>} />
      <Route path="/admin" element={<Guard adminOnly><AdminPage /></Guard>} />
      <Route path="/admin/events" element={<Guard adminOnly><AdminEventsPage /></Guard>} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
