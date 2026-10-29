import { useState } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '../auth.jsx';
import { MenuBar } from '../components/Layout.jsx';
import { Window } from '../components/retro.jsx';
import { Avatar, ErrorNote, FieldError } from '../components/ui.jsx';

// Three of the illustrated avatars the app uses, for the welcome window.
const FACES = ['Tara Fernandes', 'Demo Web', 'Aisha Siddiqui']
  .map((name) => ({ name, src: `https://api.dicebear.com/9.x/notionists/png?seed=${encodeURIComponent(name)}` }));

export default function AuthPage({ mode }) {
  const isLogin = mode === 'login';
  const { login, register } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [form, setForm] = useState({ name: '', email: '', password: '' });
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);

  const set = (k) => (e) => setForm({ ...form, [k]: e.target.value });
  const fieldErrors = error?.fieldErrors ?? {};

  async function submit(e) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      const user = isLogin
        ? await login(form.email, form.password)
        : await register(form.name, form.email, form.password);
      const next = user.isAdmin ? '/admin' : user.profileComplete ? location.state?.from ?? '/' : '/profile';
      navigate(next, { replace: true });
    } catch (err) {
      setError(err);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="shell">
      <MenuBar />
      <main className="page auth">
        <Window title="Welcome.txt" className="auth-pitch" inset={false}>
          <div className="auth-art halftone blue">
            {FACES.map((f, i) => <Avatar key={f.name} src={f.src} name={f.name} size={i === 1 ? 92 : 74} tone={i === 1 ? 'desk' : 'pink'} />)}
          </div>
          <div className="auth-copy">
            <h1>Find the teammates your team is missing.</h1>
            <p>Swipe through students ranked by how well they fill your gaps in skills, schedule and interests. Match, form a crew, then take it to events and challenges.</p>
            <ul className="auth-points">
              <li><span className="dot pink" aria-hidden="true" />Ranked deck. Best fits first, with a match % and why.</li>
              <li><span className="dot desk" aria-hidden="true" />Mutual matches. Two right swipes and you can get in touch.</li>
              <li><span className="dot blue" aria-hidden="true" />Crews of 4. Earn points together and climb the leaderboard.</li>
            </ul>
          </div>
        </Window>

        <Window
          title={isLogin ? 'Sign in' : 'Create account'} titleAs="h2" className="auth-card" inset={false} front
          strip={<>{isLogin ? 'New here? ' : 'Already have an account? '}<Link to={isLogin ? '/register' : '/login'}>{isLogin ? 'Create an account' : 'Sign in'}</Link></>}
        >
          <form className="auth-form" onSubmit={submit} noValidate>
            <p className="serif-title">{isLogin ? 'Welcome back' : 'Join CrewMatch'}</p>
            <p className="muted">{isLogin ? 'Sign in to keep swiping.' : 'Takes 30 seconds. Then build your profile.'}</p>

            {!isLogin && (
              <label className="field">
                <span>Full name</span>
                <input value={form.name} onChange={set('name')} autoComplete="name" required />
                <FieldError>{fieldErrors.name}</FieldError>
              </label>
            )}
            <label className="field">
              <span>Email</span>
              <input type="email" value={form.email} onChange={set('email')} autoComplete="email" required />
              <FieldError>{fieldErrors.email}</FieldError>
            </label>
            <label className="field">
              <span>Password</span>
              <input
                type="password" value={form.password} onChange={set('password')} required
                autoComplete={isLogin ? 'current-password' : 'new-password'}
                minLength={isLogin ? undefined : 6}
              />
              <FieldError>{fieldErrors.password}</FieldError>
            </label>

            {error && !Object.keys(fieldErrors).length && <ErrorNote error={error} />}

            <button className="btn primary block" disabled={busy}>
              {busy ? 'Please wait…' : isLogin ? 'Sign in' : 'Create account'}
            </button>
          </form>
        </Window>
      </main>
    </div>
  );
}
