import { Navigate, Route, Routes, useLocation } from 'react-router-dom';
import { useAuth } from './auth.jsx';
import Layout from './components/Layout.jsx';
import { Spinner } from './components/ui.jsx';
import AuthPage from './pages/AuthPage.jsx';
import ProfilePage from './pages/ProfilePage.jsx';
import DiscoverPage from './pages/DiscoverPage.jsx';
import MatchesPage from './pages/MatchesPage.jsx';
import CrewPage from './pages/CrewPage.jsx';
import AdminPage from './pages/AdminPage.jsx';

// Guards a page: signed in, profile finished (for students), admin when asked.
function Guard({ children, needsProfile = false, adminOnly = false }) {
  const { user, loading } = useAuth();
  const location = useLocation();

  if (loading) return <Spinner full />;
  if (!user) return <Navigate to="/login" replace state={{ from: location.pathname }} />;
  if (adminOnly && !user.isAdmin) return <Navigate to="/" replace />;
  if (user.isAdmin && !adminOnly) return <Navigate to="/admin" replace />;
  if (needsProfile && !user.profileComplete) return <Navigate to="/profile" replace />;
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
      <Route path="/admin" element={<Guard adminOnly><AdminPage /></Guard>} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
