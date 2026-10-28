# CrewMatch web (client/)

React + Vite. Talks only to the shared Express API in `../server`.

```bash
cd client
npm install
npm run dev        # http://localhost:5173
```

Start the API first (`npm run dev` in `server/`). To point at a different API, copy `.env.example` to `.env` and set `VITE_API_URL`.

## Pages

| Route | What it does |
|---|---|
| `/login`, `/register` | Email + password sign-in (JWT saved in localStorage) |
| `/profile` | Chip-based profile form. New users land here first |
| `/` | Swipe deck: drag, the ✕ / ♥ buttons, or ← → keys. "It's a match!" popup with confetti |
| `/matches` | Matches with contact email, add to crew, unmatch |
| `/crew` | Start a crew from matches, coverage checklist, add members, rename, leave |
| `/admin` | Admin only: totals, students by role and interest, searchable student table |

Sign in with the seed accounts in `../server/README.md` (`web@crewmatch.dev` / `password123`, or `admin@crewmatch.dev` for the dashboard).

## Layout

```
src/
├── api.js           fetch wrapper: base URL, JWT header, ApiError
├── auth.jsx         AuthProvider + useAuth (login, register, logout, session restore)
├── labels.js        human labels for option values
├── App.jsx          routes and guards (signed in, profile complete, admin)
├── components/      Layout, SwipeCard, MatchModal, ui (Avatar, Tag, Spinner…)
└── pages/           Auth, Profile, Discover, Matches, Crew, Admin
```
