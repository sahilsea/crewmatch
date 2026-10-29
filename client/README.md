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
| `/` | Discover desktop: the swipe deck (drag, the Pass / Like buttons, or ← → keys), undo last pass, skip, a role filter and a minimum-fit slider. Around it: why this card fits, who's next, your crew and this session's counts. "It's a match!" popup with confetti |
| `/matches` | Matches with contact email, add to crew, unmatch |
| `/crew` | Start a crew from matches, coverage checklist, add members, rename, leave, the crew's points and rank |
| `/events` | Events and challenges for your crew: RSVP or leave, check in with the code shown at the venue, accept a challenge and submit a link. Filter by live, upcoming or challenges. Students without a crew get a link to the Crew page |
| `/leaderboard` | Crews ranked by points, top 3 on a podium, your crew highlighted. Refreshes every 15 s, so it can stay on a projector. Admins can open it too |
| `/admin` | Admin only: totals (including events, challenges and submissions waiting for review), students by role and interest, searchable student table |
| `/admin/events` | Admin only: every event and challenge with its check-in code, a create / edit form that shows the API's message under each field, delete, and the submissions waiting for review (approve with an optional points override, or reject with a reason the crew sees) |

Sign in with the seed accounts in `../server/README.md` (`web@crewmatch.dev` / `password123`, or `admin@crewmatch.dev` for the admin pages).

## Look and feel

A retro desktop: a pink desk, cream windows with an ink outline, a menu bar of tabs along the top edge and a dock along the bottom. On wide screens the windows overlap a little; below 760 px they stack, the dock becomes a bottom bar and the menu bar keeps just the logo and your avatar. Fonts: Anton (window titles), Old Standard TT (headlines), Pixelify Sans (body), VT323 (labels and numbers). Light theme only.

The pieces live in `components/retro.jsx`: `Window` (its ✕ minimises it to the title bar and back), `Tabs`, `Segmented`, `Meter`, `Pill`, `StatusStrip` and `Dialog`.

## Layout

```
src/
├── api.js           fetch wrapper: base URL, JWT header, ApiError
├── auth.jsx         AuthProvider + useAuth (login, register, logout, session restore)
├── hooks.js         useOptions, useNow (clock), useWindowOrder (click a window to raise it)
├── labels.js        human labels for option values and event categories
├── format.js        dates, times and file-name labels
├── fit.js           the "why this match" counts for a deck card
├── confetti.js      confetti in the desktop's colours
├── App.jsx          routes and guards (signed in, profile complete, admin); pages load on demand
├── components/      Layout (menu bar + dock), retro kit, SwipeCard, MatchModal, ProfileDialog, EventCard, icons, ui
└── pages/           Auth, Profile, Discover, Matches, Crew, Events, Leaderboard, Admin, AdminEvents
```
