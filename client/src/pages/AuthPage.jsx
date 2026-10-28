import { useState } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '../auth.jsx';
import { Logo } from '../components/Layout.jsx';
import { ErrorNote } from '../components/ui.jsx';

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
    <div className="auth">
      <section className="auth-pitch">
        <Logo />
        <h1>Find the teammates <em>your team is missing.</em></h1>
        <p>Swipe through students ranked by how well they fill your gaps in skills, schedule and interests. Match, form a crew, ship something great.</p>
        <ul className="auth-points">
          <li><b>Ranked deck.</b> Best fits first, with a match % and why.</li>
          <li><b>Mutual matches.</b> Two right swipes and you can get in touch.</li>
          <li><b>Crews of 4.</b> Your deck then hunts for whoever fills the crew's gaps.</li>
        </ul>
      </section>

      <form className="card auth-card" onSubmit={submit} noValidate>
        <h2>{isLogin ? 'Welcome back' : 'Create your account'}</h2>
        <p className="muted">{isLogin ? 'Sign in to keep swiping.' : 'Takes 30 seconds. Then build your profile.'}</p>

        {!isLogin && (
          <label className="field">
            <span>Full name</span>
            <input value={form.name} onChange={set('name')} autoComplete="name" required />
            {fieldErrors.name && <small className="field-error">{fieldErrors.name}</small>}
          </label>
        )}
        <label className="field">
          <span>Email</span>
          <input type="email" value={form.email} onChange={set('email')} autoComplete="email" required />
          {fieldErrors.email && <small className="field-error">{fieldErrors.email}</small>}
        </label>
        <label className="field">
          <span>Password</span>
          <input
            type="password" value={form.password} onChange={set('password')} required
            autoComplete={isLogin ? 'current-password' : 'new-password'}
            minLength={isLogin ? undefined : 6}
          />
          {fieldErrors.password && <small className="field-error">{fieldErrors.password}</small>}
        </label>

        {error && !Object.keys(fieldErrors).length && <ErrorNote error={error} />}

        <button className="btn primary block" disabled={busy}>
          {busy ? 'Please wait…' : isLogin ? 'Sign in' : 'Create account'}
        </button>
        <p className="switch">
          {isLogin ? 'New here? ' : 'Already have an account? '}
          <Link to={isLogin ? '/register' : '/login'}>{isLogin ? 'Create an account' : 'Sign in'}</Link>
        </p>
      </form>
    </div>
  );
}
