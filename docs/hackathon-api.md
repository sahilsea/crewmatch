# Hackathon hub API: events, challenges, leaderboard

Crews (not single users) take part. Everything here is under `/api`, needs
`Authorization: Bearer <token>`, and fails with the same shape as the rest of
the API: `{ "error": "message", "details"?: [{ field, message }] }`.

## Concepts

- **Event**: something a crew goes to together at a time and place (workshop,
  talk, social, expo walk). The crew RSVPs, then checks in at the venue with the
  code the organisers show on screen. Checking in awards the event's points.
- **Challenge**: a task a crew takes on (build, design, pitch, quiz). The crew
  accepts it, submits a link, and an admin approves it. Approval awards points
  (the admin can override the amount, e.g. a podium bonus).
- **Leaderboard**: crews ranked by the total points they have been awarded.

Both kinds are stored in one `Event` model with `kind: "event" | "challenge"`.

## Event object (what members see)

```json
{
  "id": "6720…",
  "kind": "event",
  "title": "Figma to Flutter Workshop",
  "summary": "One line for cards, max 140 chars",
  "details": "Longer text, can be empty",
  "category": "workshop",
  "location": "Lab 3, Block B",
  "startsAt": "2026-10-28T09:30:00.000Z",
  "endsAt": "2026-10-28T11:00:00.000Z",
  "points": 50,
  "capacity": 12,
  "crewCount": 5,
  "state": "live",
  "myEntry": {
    "status": "joined",
    "submissionUrl": null,
    "note": null,
    "pointsAwarded": 0,
    "joinedAt": "2026-10-28T08:00:00.000Z",
    "completedAt": null
  }
}
```

- `category`: `workshop | talk | social | expo` for events, `build | design | pitch | quiz` for challenges.
- `location`: a venue for events; challenges use `"Anywhere"` or `"Online"`.
- `startsAt` / `endsAt`: for challenges these are "opens" and "deadline".
- `capacity`: maximum crews, or `null` for unlimited. `crewCount` counts entries in any status.
- `state`: computed on every response: `upcoming` (now < startsAt), `live` (between), `ended` (now > endsAt).
- `myEntry`: the signed-in user's crew entry, or `null` (also `null` when the user has no crew).
- `myEntry.status`: `joined` (going / accepted), `submitted` (challenge link sent, waiting for review), `completed` (points awarded).
- The check-in code is never included for members.

## Member endpoints

| Method | Path | Body | Returns |
| --- | --- | --- | --- |
| GET | `/events?kind=event\|challenge` | | `{ events: [Event] }` (kind optional; both when omitted) |
| GET | `/events/:id` | | `{ event: Event & { crews: [{ id, name, memberCount, status }] } }` |
| POST | `/events/:id/join` | | `{ event }` |
| DELETE | `/events/:id/join` | | `{ event }` (only while `myEntry.status` is `joined`) |
| POST | `/events/:id/checkin` | `{ code }` | `{ event, pointsAwarded }` (events only) |
| POST | `/events/:id/submit` | `{ url, note? }` | `{ event }` (challenges only) |
| POST | `/events` | StudentEventInput | `201 { event }` (host your own event) |
| DELETE | `/events/:id` | | `204` (the host only, never an official event) |
| GET | `/leaderboard` | | see below |

List order: `live` first, then `upcoming` by `startsAt`, then `ended` with the most recent first.

Rules and errors:

- No crew: `409 "Join or create a crew first"` on join, check-in and submit.
- Unknown id: `404 "Event not found"`.
- Join or submit after `endsAt`: `409 "This has ended"`. Check-in gets a 30 minute grace period after `endsAt`.
- Join when `crewCount >= capacity`: `409 "This is full"`.
- Check-in: the code is compared trimmed and case-insensitive. A wrong code is `400 "Wrong check-in code"`. Check-in works without an RSVP first (it creates the entry). Checking in twice is `409 "Your crew already checked in"`.
- Submit: `url` must be an http(s) URL; `note` max 280 chars. Allowed again while not `completed` (it replaces the link). `409 "Already completed"` after approval.
- Leave (`DELETE …/join`) after submitting or completing: `409 "You can't leave after submitting"`.
- Any crew member can act for the crew.

### Student-hosted events

- `StudentEventInput`: `{ kind, title, summary, category, location?, startsAt, endsAt, capacity?, askPoints? (0-100) }`.
- Every event has `status`: `official` (organisers), `community` (a student's, no points) or `pending`
  (a student's that asked for `askedPoints`, waiting for an organiser). Only `official` events award points.
- Student events go live straight away as `community`, or `pending` with `askPoints > 0`.
- `host: { id, name }` names the student who made it (null for organisers' events). The host gets
  `hosting: true` and the event's `checkinCode`, to show at their venue.
- A student can host up to 3 events that haven't ended: `409 "You can host up to 3 events at a time"`.

## Leaderboard

`GET /leaderboard`

```json
{
  "title": "MERNOVA X 2026",
  "updatedAt": "2026-10-28T10:15:00.000Z",
  "myCrewId": "6720…",
  "crews": [
    {
      "rank": 1,
      "id": "6720…",
      "name": "Night Shift",
      "points": 320,
      "completed": 6,
      "events": 3,
      "challenges": 3,
      "lastScoredAt": "2026-10-28T09:50:00.000Z",
      "members": [{ "id": "…", "name": "Tara Fernandes", "role": "backend", "avatar": "…" }]
    }
  ]
}
```

- `title` comes from the `HACKATHON_NAME` env var (default `MERNOVA X 2026`).
- Every crew is listed, including crews with 0 points.
- Sort: `points` descending, then whoever reached their score first (`lastScoredAt` ascending, `null` last), then `name`. `rank` is the 1-based position.
- `myCrewId` is the signed-in user's crew id, or `null`.
- `GET /crews/mine` also gains `points` and `rank` on the crew object.

## Admin endpoints (`isAdmin` only)

| Method | Path | Body | Returns |
| --- | --- | --- | --- |
| GET | `/admin/events` | | `{ events: [AdminEvent] }` |
| POST | `/admin/events` | EventInput | `201 { event: AdminEvent }` |
| PATCH | `/admin/events/:id` | partial EventInput | `{ event: AdminEvent }` |
| DELETE | `/admin/events/:id` | | `204` |
| POST | `/admin/events/:id/official` | `{ points? }` | `{ event: AdminEvent }` (approve a student's event) |
| POST | `/admin/events/:id/community` | | `{ event: AdminEvent }` (keep it, no points) |
| POST | `/admin/events/:id/entries/:crewId/approve` | `{ points? }` | `{ event: AdminEvent }` |
| POST | `/admin/events/:id/entries/:crewId/reject` | `{ note? }` | `{ event: AdminEvent }` |

- `AdminEvent` = Event fields (with `myEntry: null`) plus `checkinCode` (events only, else `null`) and
  `entries: [{ crew: { id, name }, status, submissionUrl, note, pointsAwarded, joinedAt, completedAt }]`.
- `EventInput`: `{ kind, title, summary, details?, category, location?, startsAt, endsAt, points (0-1000), capacity? (null or 1-500), checkinCode? }`.
  Creating an event without `checkinCode` generates a 4-character code from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`. `endsAt` must be after `startsAt`.
- Approve: sets `completed`, `pointsAwarded = points ?? event.points`, `completedAt = now`. Works on any entry status.
- Reject: back to `joined`, `pointsAwarded = 0`, stores `note` so the crew sees why.
- Official: `points = points ?? askedPoints`; crews that already checked in get the points too.
  Rejecting a student's event is `DELETE /admin/events/:id`.
- `GET /admin/stats` gains `events` and `challenges` (official only), `pendingSubmissions`,
  `pendingEvents`, `communityEvents` and `liveEvents` counts.

## Seed data

`npm run seed` (and the in-memory auto-seed) also creates, with times relative to "now" so the demo always has something live:

- 6 or more crews of 2 to 4 seeded students (the demo accounts stay crew-less so the demo can show forming a crew).
- 6 events: 1 ended earlier today, 2 live now, 3 upcoming (later today and tomorrow). Each has a check-in code, printed in the seed log.
- 5 challenges: 1 ended, 4 open with deadlines later today or tomorrow.
- Entries spread across the crews so the leaderboard has a clear order, plus at least 2 `submitted` entries waiting for an admin.
