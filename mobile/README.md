# CrewMatch mobile (mobile/)

The Flutter app. It calls the same Express API as the React web app (`../server`), so a match,
crew or check-in made on one shows up on the other.

Built with Flutter 3.47 (Dart 3.13). Dependencies are kept small: `http`, `shared_preferences`,
`google_fonts`, and `material_ui` (Flutter's Material library, which moved out of the SDK into its
own package; `google_fonts` 9 builds on it). State is plain `ChangeNotifier` and `setState`.

## Run it

Start the API first (`npm run dev` in `server/`; it listens on port 5050). Then:

```bash
cd mobile
flutter pub get
flutter run --dart-define=API_URL=<base URL>
```

`API_URL` is read with `String.fromEnvironment` and defaults to `http://localhost:5050/api`.

| Where the app runs | `API_URL` |
|---|---|
| iOS simulator, desktop, web | `http://localhost:5050/api` (the default) |
| Android emulator | `http://10.0.2.2:5050/api` |
| Physical phone on the same Wi-Fi | `http://<laptop-LAN-IP>:5050/api` (find it with `ipconfig getifaddr en0`) |

For example, on an Android emulator:

```bash
flutter run --dart-define=API_URL=http://10.0.2.2:5050/api
```

The API listens on `0.0.0.0`, so a phone on the same network can reach it. The dev API is plain HTTP,
so the platform projects allow that: Android has the `INTERNET` permission and
`usesCleartextTraffic`, and iOS has `NSAllowsLocalNetworking` (plus the local network usage
description iOS asks for). Use HTTPS and drop those for a real release.

To try it in a browser, build the web version and serve it. The API only accepts browser calls
from the origins in `CLIENT_URLS` in `server/.env`, so add yours there:

```bash
flutter build web --dart-define=API_URL=http://localhost:5050/api
python3 -m http.server 5175 -d build/web     # then open http://localhost:5175
```

Sign in with the seed accounts in `../server/README.md`: `mobile@crewmatch.dev` / `password123`.
Seeded students with auto-like on (e.g. Priya Hegde, Pooja Desai, Sneha Murthy) match straight away.
The check-in codes for seeded events are printed in the API's start-up log.

## Check it

```bash
flutter analyze
flutter test
```

Tests cover the API client (token, errors, field errors, 401 handling, offline), every response
shape the app parses, the session (restore, sign in, sign out on 401) and widgets (sign in to the
deck, field errors, event card statuses). Widget tests set `AppType.fetchFonts = false` so they never
download fonts.

## What's in the app

- **Sign in / register**, with the API's per-field errors under each input. The token is kept in
  `shared_preferences`; any 401 signs you out and back to this screen.
- **Profile** (first run, then from the avatar menu): chips from `GET /options`, up to two
  superpowers, free-text skills.
- **Discover**: the ranked deck. Drag a card, or use Pass / Like (or ← → on a keyboard). Fit % and
  reasons on each card, and an "It's a match!" window on a mutual like.
- **Matches**: contact email (tap to copy), add to your crew, unmatch.
- **Crew**: start one from your matches, add members, rename, leave, the coverage checklist, and the
  crew's hackathon points and rank.
- **Events**: events and challenges. Join or leave, check in with the code shown at the venue,
  submit a link and note for a challenge, see review status and any reviewer note. Without a crew it
  explains that crews take part and links to the Crew tab.
- **Ranks**: the leaderboard, with your crew highlighted. Pull to refresh.

## Code layout

```
lib/
├── main.dart            builds the API client and session, runs the app
├── app.dart             MaterialApp, theme, and the gate: sign in → profile → home
├── config.dart          API_URL
├── api/                 ApiClient (HTTP, token, errors), CrewMatchApi (typed endpoints), ApiException
├── models/              User, Crew, Deck, HubEvent, Leaderboard, ProfileOptions
├── state/               Session (ChangeNotifier) and the token store
├── ui/                  the retro desktop kit: palette, type, window, halftone, controls, glyphs…
├── screens/             auth, profile, shell (menu bar, dock), discover, matches, crew, events,
│                        leaderboard, admin
└── util/                labels, dates, parallel requests
```

The look is a retro desktop: pink desktop, inked windows with a title bar and status strip,
halftone fills, Anton titles, Old Standard TT headlines, Pixelify Sans body text and VT323 labels.
Pixelify Sans is used with ligatures off (its "fi" ligature draws a broken glyph).
