// Thin wrapper around fetch for the CrewMatch API.
// Adds the JWT, parses JSON and turns error responses into ApiError.

export const API_URL = import.meta.env.VITE_API_URL ?? 'http://localhost:5050/api';
const TOKEN_KEY = 'crewmatch_token';

export const tokenStore = {
  get: () => localStorage.getItem(TOKEN_KEY),
  set: (t) => localStorage.setItem(TOKEN_KEY, t),
  clear: () => localStorage.removeItem(TOKEN_KEY),
};

export class ApiError extends Error {
  constructor(status, message, details) {
    super(message);
    this.status = status;
    this.details = details;
  }
  // { field: message } for showing errors next to form inputs
  get fieldErrors() {
    return Object.fromEntries((this.details ?? []).map((d) => [d.field, d.message]));
  }
}

// Called when the server says our token is no longer valid.
let onUnauthorized = () => {};
export const setUnauthorizedHandler = (fn) => { onUnauthorized = fn; };

export async function request(method, path, body) {
  const token = tokenStore.get();
  let res;
  try {
    res = await fetch(API_URL + path, {
      method,
      headers: {
        ...(body && { 'Content-Type': 'application/json' }),
        ...(token && { Authorization: `Bearer ${token}` }),
      },
      body: body ? JSON.stringify(body) : undefined,
    });
  } catch {
    throw new ApiError(0, "Can't reach the server. Is the API running?");
  }

  const data = res.status === 204 ? null : await res.json().catch(() => null);
  if (!res.ok) {
    if (res.status === 401 && token) onUnauthorized();
    throw new ApiError(res.status, data?.error ?? `Request failed (${res.status})`, data?.details);
  }
  return data;
}

export const api = {
  get: (p) => request('GET', p),
  post: (p, b) => request('POST', p, b ?? {}),
  put: (p, b) => request('PUT', p, b),
  patch: (p, b) => request('PATCH', p, b),
  del: (p) => request('DELETE', p),
};
