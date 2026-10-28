import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { api, tokenStore, setUnauthorizedHandler } from './api.js';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(Boolean(tokenStore.get()));

  const logout = useCallback(() => {
    tokenStore.clear();
    setUser(null);
  }, []);

  // Restore the session from a saved token on first load.
  useEffect(() => {
    setUnauthorizedHandler(logout);
    if (!tokenStore.get()) return;
    api.get('/auth/me')
      .then((d) => setUser(d.user))
      .catch(() => tokenStore.clear())
      .finally(() => setLoading(false));
  }, [logout]);

  const value = useMemo(() => {
    const signIn = async (path, body) => {
      const d = await api.post(path, body);
      tokenStore.set(d.token);
      setUser(d.user);
      return d.user;
    };
    return {
      user,
      loading,
      setUser,
      logout,
      login: (email, password) => signIn('/auth/login', { email, password }),
      register: (name, email, password) => signIn('/auth/register', { name, email, password }),
      refresh: () => api.get('/auth/me').then((d) => { setUser(d.user); return d.user; }),
    };
  }, [user, loading, logout]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

// eslint-disable-next-line react/only-export-components
export const useAuth = () => useContext(AuthContext);
