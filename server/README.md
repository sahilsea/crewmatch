# CrewMatch API (server/)

Node.js + Express + MongoDB. This is the **only** layer that touches the database; the React web app and the Flutter app both call it.

## Run it

```bash
cd server
npm install
cp ../.env.example .env   # then set JWT_SECRET (and MONGO_URI for Atlas)
npm run dev
```

- **No `MONGO_URI`?** The server starts an in-memory MongoDB and seeds it automatically. Data resets on restart. The first run downloads a MongoDB binary (~77 MB).
- **Want data to survive restarts without Atlas?** Also set `LOCAL_DB_DIR=.data`. The same local MongoDB then keeps its files in `server/.data/` (gitignored) and is seeded only the first time, while it has no users. Times in the seed are relative to that first run, so delete the folder to get a fresh demo day.
- **Using Atlas:** set `MONGO_URI`, then run `npm run seed` once to load the demo data.
- The API listens on `http://localhost:5050/api`. Port 5000 is avoided because macOS AirPlay Receiver uses it.

### Environment variables (`server/.env`)

| Name | Default | What it does |
|---|---|---|
| `MONGO_URI` | empty | MongoDB connection string. Empty outside production: a local MongoDB is started for you |
| `LOCAL_DB_DIR` | empty | Only with no `MONGO_URI`. Folder (relative to `server/`) that keeps the local database between restarts. Empty: fresh in-memory database, re-seeded on every start |
| `JWT_SECRET` | required | Signs login tokens |
| `PORT` | `5050` | Port the API listens on |
| `CLIENT_URLS` | `http://localhost:5173` | Comma-separated browser origins allowed by CORS. Outside production, any `http://localhost:<port>` and `http://127.0.0.1:<port>` is allowed too (extra Vite ports, the Flutter web build) |
| `HACKATHON_NAME` | `MERNOVA X 2026` | Title of the leaderboard |
| `NODE_ENV` | | `production` requires `MONGO_URI` and limits CORS to `CLIENT_URLS` |

### Reaching the API from the mobile app

| Where the Flutter app runs | Base URL |
|---|---|
| iOS simulator | `http://localhost:5050/api` |
| Android emulator | `http://10.0.2.2:5050/api` |
| Physical phone (same Wi-Fi) | `http://<your-laptop-LAN-IP>:5050/api` (find it with `ipconfig getifaddr en0`) |

## Seed accounts

Every seeded account's password is `password123`.

| Email | Use |
|---|---|
| `web@crewmatch.dev` | Demo account to sign in on the **web** app |
| `mobile@crewmatch.dev` | Demo account to sign in on the **mobile** app |
| `admin@crewmatch.dev` | Admin: can call `/api/admin/*` |
| `firstname.lastname@students.crewmatch.dev` | 28 fake students. About half have `autoLike` on, so swiping right on them makes an instant match. |

**Cross-platform demo:** sign in as `web@` on the web and `mobile@` on the phone. Swipe right on each other (they rank near the top of each other's decks), and the match appears on both.

**Hackathon hub demo data:** 6 crews of 2 to 4 students (only students without `autoLike`, so every instant match is still free to join your crew; the demo accounts start crew-less), 6 events (1 ended earlier today, 2 live, 3 upcoming), 5 challenges (1 ended, 4 open) and entries that give the leaderboard a clear order, with 3 submissions waiting for an admin. Times are relative to when the seed runs. The check-in codes are printed in the server log:

```
Seeded 6 crews, 6 events and 5 challenges. Check-in codes:
  SPRK  Opening Keynote: Build for Your Campus (ended)
  WDGT  Wireframes to Widgets Workshop (live)
  ...
```

## Auth

Send the token from register/login as `Authorization: Bearer <token>`. Tokens last 7 days.

## Endpoints

All paths start with `/api`. 🔒 means a token is required.

| Method | Path | Body | Notes |
|---|---|---|---|
| GET | `/health` | | `{ ok: true }` |
| GET | `/options` | | Allowed values for every profile chip |
| POST | `/auth/register` | `{ name, email, password }` | Returns `{ token, user }`. New users have `profileComplete: false` |
| POST | `/auth/login` | `{ email, password }` | Returns `{ token, user }` |
| GET 🔒 | `/auth/me` | | Current user |
| PUT 🔒 | `/users/me` | any of `name, avatar, bio, role, experienceLevel, schedule, commitment, communication, interests[], superpowers[] (max 2), skills[]` | Partial update. Sets `profileComplete` once role, level, schedule, commitment, communication, ≥1 interest and ≥1 skill are present |
| DELETE 🔒 | `/users/me` | | Deletes the account and removes it from matches and crews |
| GET 🔒 | `/users/:id` | | Public profile |
| GET 🔒 | `/deck?limit=20` | | Ranked swipe deck (needs a complete profile). Each card has `score` (0–100) and `tags`. Scored against your crew if you're in one |
| POST 🔒 | `/swipe` | `{ targetId, direction: "left" \| "right" }` | Returns `{ match: true, user }` when it's mutual |
| POST 🔒 | `/swipe/reset` | | Clears your passes so those people come back |
| GET 🔒 | `/matches` | | Your matches, with email |
| DELETE 🔒 | `/matches/:id` | | Unmatch |
| GET 🔒 | `/crews/mine` | | `{ crew }` with members, `checklist` and `spotsLeft`, or `{ crew: null }` |
| POST 🔒 | `/crews` | `{ name, memberIds[] }` | Members must be your matches and not in another crew. Max 4 people |
| PATCH 🔒 | `/crews/mine` | `{ name }` | Rename |
| POST 🔒 | `/crews/mine/members` | `{ userId }` | Add a match to your crew |
| DELETE 🔒 | `/crews/mine` | | Leave. A crew left with one person is dissolved, and its event entries go with it |
| GET 🔒 | `/events?kind=event\|challenge` | | `{ events }`: both kinds when `kind` is omitted. Live first (ending soonest), then upcoming (starting soonest), then ended (latest first) |
| GET 🔒 | `/events/:id` | | `{ event }` plus `crews: [{ id, name, memberCount, status }]` |
| POST 🔒 | `/events/:id/join` | | RSVP to an event or accept a challenge, for your whole crew |
| DELETE 🔒 | `/events/:id/join` | | Leave, only while your entry is `joined` |
| POST 🔒 | `/events/:id/checkin` | `{ code }` | Events only. Returns `{ event, pointsAwarded }`. Works without an RSVP, up to 30 minutes after the end |
| POST 🔒 | `/events/:id/submit` | `{ url, note? }` | Challenges only. Send or replace your crew's link until an admin approves it |
| GET 🔒 | `/leaderboard` | | `{ title, updatedAt, myCrewId, crews }`: every crew ranked by points |
| GET 🔒 admin | `/admin/stats` | | Totals plus breakdowns by role and interest, and `events`, `challenges`, `pendingSubmissions` counts |
| GET 🔒 admin | `/admin/users` | | Every student |
| GET 🔒 admin | `/admin/events` | | Every event and challenge with its `checkinCode` and every crew's entry |
| POST 🔒 admin | `/admin/events` | `{ kind, title, summary, details?, category, location?, startsAt, endsAt, points, capacity?, checkinCode? }` | `201 { event }`. Events without a `checkinCode` get a 4-character one |
| PATCH 🔒 admin | `/admin/events/:id` | any of the above | Partial update |
| DELETE 🔒 admin | `/admin/events/:id` | | `204` |
| POST 🔒 admin | `/admin/events/:id/entries/:crewId/approve` | `{ points? }` | Completes the entry and awards `points` (default: the event's) |
| POST 🔒 admin | `/admin/events/:id/entries/:crewId/reject` | `{ note? }` | Back to `joined` with 0 points and the note, so the crew can resubmit |

`GET /crews/mine` (and every other crew response) also has `points` and `rank`, the same numbers as the leaderboard.

### Hackathon hub: events, challenges, leaderboard

Crews, not single users, take part. **[docs/hackathon-api.md](../docs/hackathon-api.md) is the contract** for these endpoints: the event object, every rule and the exact error messages. In short:

- One `Event` model with `kind: "event" | "challenge"`. `state` (`upcoming`, `live`, `ended`) is worked out from the clock on every response.
- Events: RSVP, then check in at the venue with the code the organisers show on screen. Checking in awards the points. Members never see the code.
- Challenges: accept, submit a link, an admin approves (optionally with bonus points) or rejects with a note.
- Leaderboard: every crew, most points first; ties go to whoever reached the score first, then by name. `utils/leaderboard.js` computes it for both `/leaderboard` and `/crews/mine`.
- Two crewmates tapping at the same moment can't add two entries or score twice: entries are changed with single atomic updates.

### Errors

Every error looks like `{ "error": "message", "details": [{ "field", "message" }] }` (`details` only on validation errors).

| Status | When |
|---|---|
| 400 | Validation failed, bad id, bad JSON |
| 401 | No token, bad or expired token, wrong password |
| 403 | Not an admin |
| 404 | Not found |
| 409 | Email taken, profile incomplete, already in a crew, no crew for an event, event full or ended, already checked in or completed |

## How matching works

`utils/matching.js` scores each candidate against you, or against your whole crew:

| Part | Weight | Scores high when… |
|---|---|---|
| Complementary skills | 50% | They bring a role, superpower or skills the team lacks |
| Working style | 30% | Same schedule, commitment level and communication style |
| Shared interests | 20% | You care about the same domains |

The deck hides anyone under 40% and shows the best fit first. The reason tags ("Fills your design gap", "Fellow night owl") come from the same file.

## Folder layout

```
server/
├── server.js          entry point: env check, DB connect, listen
├── app.js             Express app: security headers, CORS, JSON, routes, errors
├── config/            db.js (Atlas, in-memory or LOCAL_DB_DIR), options.js (chip values, event rules)
├── models/            User, Crew, Event (events and challenges, with crew entries)
├── controllers/       auth, user, deck (deck + swipe), match, crew, event (hub + its admin), admin
├── routes/index.js    every route and the middleware it uses
├── middleware/        auth (JWT, admin, profile), validate (zod), error
├── utils/             matching.js, leaderboard.js, schemas.js (request validation)
├── seed/seed.js       demo data
└── test/              end-to-end API tests (npm test)
```

## Tests

```bash
npm test
```

Boots the API on its own fresh in-memory MongoDB (seeded like `npm run dev`, whatever `server/.env` says) on `127.0.0.1:5083` (`TEST_PORT` to change it) and calls every endpoint over HTTP with `node:test`: sign-up to crew, the seed data, and every hub endpoint with its error cases.
