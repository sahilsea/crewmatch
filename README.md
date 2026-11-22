# CrewMatch

**Tinder for finding student teammates.** Swipe through students ranked by how well they fill your team's gaps, match when it's mutual, form a crew of up to 4, then take your crew to events and challenges and climb the hackathon leaderboard.

Built for **MERNOVA X 2026**: one topic, two apps, one backend.

```
 React web (client/)  ─┐
                       ├──>  Express REST API (server/)  ──>  MongoDB
 Flutter app (mobile/) ─┘
```

| Part | Stack | Focus |
|---|---|---|
| `server/` | Node.js, Express, MongoDB (Mongoose), JWT, zod | Auth, validation, matching, events and scoring; the only layer that touches the DB |
| `client/` | React (Vite) | Profile management, swiping, matches, crews, events, leaderboard, admin dashboard |
| `mobile/` | Flutter | The same flows on a phone: swipe, matches, crew, events, leaderboard |

## What it does

- **Ranked deck.** Everyone you see is scored on complementary skills (50%), work style (30%) and shared interests (20%), against your whole crew once you have one.
- **Matches and crews.** Two right swipes make a match. Matches can form a crew of up to 4, with a checklist of which roles are still missing.
- **Hackathon hub.** Events a crew goes to together (RSVP, then check in at the venue with the code on screen) and challenges a crew takes on (submit a link, an organiser approves it). Both award points.
- **Leaderboard.** Crews ranked by points, refreshed live, built for the projector.
- **Admin dashboard.** Stats, users, creating events and challenges, check-in codes, reviewing submissions.

API details for the hub: [docs/hackathon-api.md](docs/hackathon-api.md). Every endpoint: [server/README.md](server/README.md).

## Quick start

```bash
npm run install:server
npm run install:client
cp .env.example server/.env    # then set JWT_SECRET
npm run dev:all                # API on http://localhost:5050/api, web on http://localhost:5173
```

`npm run dev` starts only the API and `npm run web` only the web app.

With no `MONGO_URI`, the API runs on an in-memory database that is seeded on every start. Set `LOCAL_DB_DIR=.data` in `server/.env` to keep that local data between restarts.

**Mobile:** see [mobile/README.md](mobile/README.md). In short:

```bash
cd mobile
flutter pub get
flutter run --dart-define=API_URL=http://<your-laptop-ip>:5050/api
```

On the Android emulator use `http://10.0.2.2:5050/api`. A real phone needs the laptop's Wi-Fi IP, and both must be on the same network.

## Tests

```bash
npm test                              # API: every endpoint, including events and the leaderboard
npm --prefix client run lint          # web app lint
cd mobile && flutter analyze && flutter test
```

## Demo accounts

All use the password `password123`:

| Email | Use it for |
|---|---|
| `web@crewmatch.dev` | Demo on the web app |
| `mobile@crewmatch.dev` | Demo on the phone |
| `admin@crewmatch.dev` | Admin dashboard, check-in codes, approving challenges |

The seed also creates students, crews with points, live and upcoming events, and challenges. Event check-in codes are printed in the API log and shown on the admin dashboard.

## Connecting MongoDB Atlas

1. Sign in at [cloud.mongodb.com](https://cloud.mongodb.com) and create a free **M0** cluster.
2. **Database Access**: add a database user with a password.
3. **Network Access**: add your IP address. For the expo, where the Wi-Fi IP may change, `0.0.0.0/0` works.
4. **Connect → Drivers**: copy the `mongodb+srv://…` string and add the database name before the `?`, for example `…mongodb.net/crewmatch?retryWrites=true&w=majority`.
5. Put it in `server/.env` as `MONGO_URI=…`.
6. Run `npm run seed` once to load the demo data. It wipes and refills users, crews and events.

## Expo demo script

1. **Web**: sign in as `web@crewmatch.dev`. Swipe right on the top cards; seeded students like you back, so a match pops up.
2. **Crew**: create a crew from your matches and watch the checklist fill in.
3. **Events**: RSVP your crew to a live event, then check in with its code from the admin dashboard. Your points go up.
4. **Challenges**: accept a challenge and submit a link. Sign in as admin in another window and approve it. For a quick show, approve the seeded crew **Null Pointers**' pending submission: they jump from #3 to #1.
5. **Leaderboard**: your crew climbs. Leave it open on a second screen; it refreshes by itself.
6. **Phone**: sign in on the Flutter app with the same account. It shows the same crew, events and points, because both apps share one API.

## Status

- [x] Shared Express API: auth, profiles, swipe deck, matches, crews, admin stats
- [x] React web app: sign-in, profile, swipe deck, matches, crews, admin dashboard
- [x] Hackathon hub: events, challenges, leaderboard (API, web and mobile)
- [x] Flutter mobile app
- [ ] MongoDB Atlas connected (steps above)
- [ ] Deploy (API on Render, web on Vercel)
- [ ] AI features (match notes, crew project ideas)

## Team

| Member | Role |
|---|---|
| _Name_ | Backend and database |
| _Name_ | Web |
| _Name_ | Mobile |
