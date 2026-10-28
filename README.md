# CrewMatch

**Tinder for finding student teammates.** Swipe through students ranked by how well they fill your team's gaps, match when it's mutual, and form a crew of up to 4.

Built for **MERNOVA X 2026**: one topic, two apps, one backend.

```
 React web (client/)  ─┐
                       ├──>  Express REST API (server/)  ──>  MongoDB
 Flutter app (mobile/) ─┘
```

| Part | Stack | Focus |
|---|---|---|
| `server/` | Node.js, Express, MongoDB (Mongoose), JWT, zod | Auth, validation, matching, the only layer that touches the DB |
| `client/` | React (Vite) | Profile management, matches, crews, admin dashboard and stats |
| `mobile/` | Flutter | Swiping on the go, matches, notifications/camera later |

## Quick start

```bash
npm run install:server
cp .env.example server/.env    # set JWT_SECRET
npm run server                 # http://localhost:5050/api
```

With no `MONGO_URI`, the API runs on an auto-seeded in-memory database. See [server/README.md](server/README.md) for every endpoint, the seed logins and how to connect from a phone or emulator.

## Status

- [x] Shared Express API with auth, profiles, swipe deck, matches, crews and admin stats
- [ ] React web app (`client/`)
- [ ] Flutter mobile app (`mobile/`)
- [ ] Deploy (API on Render, web on Vercel, MongoDB on Atlas)
- [ ] AI features (match notes, crew project ideas)

## Team

| Member | Role |
|---|---|
| _Name_ | Backend and database |
| _Name_ | Web |
| _Name_ | Mobile |
