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
- **Using Atlas:** set `MONGO_URI`, then run `npm run seed` once to load the demo data.
- The API listens on `http://localhost:5050/api`. Port 5000 is avoided because macOS AirPlay Receiver uses it.

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
| DELETE 🔒 | `/crews/mine` | | Leave. A crew left with one person is dissolved |
| GET 🔒 admin | `/admin/stats` | | Totals plus breakdowns by role and interest, for the web dashboard |
| GET 🔒 admin | `/admin/users` | | Every student |

### Errors

Every error looks like `{ "error": "message", "details": [{ "field", "message" }] }` (`details` only on validation errors).

| Status | When |
|---|---|
| 400 | Validation failed, bad id, bad JSON |
| 401 | No token, bad or expired token, wrong password |
| 403 | Not an admin |
| 404 | Not found |
| 409 | Email taken, profile incomplete, already in a crew |

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
├── config/            db.js (Atlas or in-memory), options.js (chip values)
├── models/            User, Crew
├── controllers/       auth, user, deck (deck + swipe), match, crew, admin
├── routes/index.js    every route and the middleware it uses
├── middleware/        auth (JWT, admin, profile), validate (zod), error
├── utils/             matching.js, schemas.js (request validation)
└── seed/seed.js       demo data
```
