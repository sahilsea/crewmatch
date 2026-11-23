// End-to-end tests: boots the API on its own in-memory MongoDB, seeded the same way
// `npm run dev` seeds it, and calls it over HTTP. Run with `npm test`.
import { describe, test, before, after } from 'node:test';
import assert from 'node:assert/strict';

// Never touch a real database from the tests, whatever server/.env says.
process.env.NODE_ENV = 'test';
process.env.MONGO_URI = '';
process.env.LOCAL_DB_DIR = '';
process.env.JWT_SECRET ||= 'test-secret';
process.env.HACKATHON_NAME = 'Test Hack 2026';

const { default: app } = await import('../app.js');
const { connectDB, disconnectDB } = await import('../config/db.js');
const { default: Crew } = await import('../models/Crew.js');
const { default: Event } = await import('../models/Event.js');
const { MAX_CREW_SIZE, CHECKIN_CODE_CHARS } = await import('../config/options.js');
const { setGoogleVerifier } = await import('../utils/google.js');

// 127.0.0.1 so a port already taken fails loudly instead of reaching another server.
const PORT = Number(process.env.TEST_PORT) || 5083;
const BASE = `http://127.0.0.1:${PORT}/api`;
let server;

before(async () => {
  // Keep the seed log out of the test report.
  const { log, warn } = console;
  console.log = console.warn = () => {};
  try {
    await connectDB();
  } finally {
    Object.assign(console, { log, warn });
  }
  await new Promise((resolve, reject) => {
    server = app.listen(PORT, '127.0.0.1', resolve).on('error', reject);
  });
});

after(async () => {
  await new Promise((resolve) => server.close(resolve));
  await disconnectDB();
});

async function api(method, path, { token, body, headers } = {}) {
  const res = await fetch(BASE + path, {
    method,
    headers: {
      ...(body && { 'content-type': 'application/json' }),
      ...(token && { authorization: `Bearer ${token}` }),
      ...headers,
    },
    body: body && JSON.stringify(body),
  });
  const text = await res.text();
  return { status: res.status, body: text ? JSON.parse(text) : null, headers: res.headers };
}

async function login(email, password = 'password123') {
  const { status, body } = await api('POST', '/auth/login', { body: { email, password } });
  assert.equal(status, 200, `login ${email}`);
  return body.token;
}

const PROFILE = {
  role: 'backend', experienceLevel: 'beginner', schedule: 'flexible', commitment: 'committed',
  communication: 'chat', interests: ['ai'], skills: ['Node.js'],
};

let userCount = 0;
async function newUser({ profile = PROFILE } = {}) {
  userCount += 1;
  const { status, body } = await api('POST', '/auth/register', {
    // Names are letters only: 1 → "Tester B", 27 → "Tester BB".
    body: { name: `Tester ${(userCount + 26).toString(26).replace(/\d/g, (d) => 'abcdefghij'[d]).toUpperCase()}`, email: `tester${userCount}@test.dev`, password: 'secret123' },
  });
  assert.equal(status, 201);
  // Email codes are off by default; when a test turns them on, the code comes back in the response.
  if (body.devCode) assert.equal((await api('POST', '/auth/verify', { token: body.token, body: { code: body.devCode } })).status, 200);
  if (profile) await api('PUT', '/users/me', { token: body.token, body: profile });
  return { token: body.token, id: body.user.id };
}

// Two fresh users who match each other and form a crew.
async function newCrew(name) {
  const a = await newUser();
  const b = await newUser();
  await api('POST', '/swipe', { token: a.token, body: { targetId: b.id, direction: 'right' } });
  await api('POST', '/swipe', { token: b.token, body: { targetId: a.id, direction: 'right' } });
  const { status, body } = await api('POST', '/crews', { token: a.token, body: { name, memberIds: [b.id] } });
  assert.equal(status, 201, JSON.stringify(body));
  return { id: body.crew.id, name, a, b };
}

const minutesFromNow = (m) => new Date(Date.now() + m * 60 * 1000).toISOString();

let admin;
async function createEvent(fields = {}) {
  const { status, body } = await api('POST', '/admin/events', {
    token: admin,
    body: {
      kind: 'event', title: 'Test workshop', summary: 'Made by the tests', category: 'workshop',
      startsAt: minutesFromNow(-30), endsAt: minutesFromNow(60), points: 50, ...fields,
    },
  });
  assert.equal(status, 201, JSON.stringify(body));
  return body.event;
}

const createChallenge = (fields = {}) =>
  createEvent({ kind: 'challenge', title: 'Test challenge', category: 'build', points: 100, ...fields });

const getEvent = async (id, token) => (await api('GET', `/events/${id}`, { token })).body.event;
const adminEvent = async (id) => (await api('GET', '/admin/events', { token: admin })).body.events.find((e) => e.id === id);

function assertListOrder(events) {
  const order = { live: 0, upcoming: 1, ended: 2 };
  for (let i = 1; i < events.length; i++) {
    const [a, b] = [events[i - 1], events[i]];
    const where = `${a.title} (${a.state}) before ${b.title} (${b.state})`;
    assert.ok(order[a.state] <= order[b.state], where);
    if (a.state !== b.state) continue;
    if (a.state === 'live') assert.ok(a.endsAt <= b.endsAt, where);
    if (a.state === 'upcoming') assert.ok(a.startsAt <= b.startsAt, where);
    if (a.state === 'ended') assert.ok(a.endsAt >= b.endsAt, where);
  }
}

function assertLeaderboardOrder(crews) {
  crews.forEach((c, i) => assert.equal(c.rank, i + 1));
  for (let i = 1; i < crews.length; i++) {
    const [a, b] = [crews[i - 1], crews[i]];
    assert.ok(a.points >= b.points, `${a.name} before ${b.name}`);
    if (a.points !== b.points) continue;
    const [ta, tb] = [a.lastScoredAt ?? '~', b.lastScoredAt ?? '~']; // '~' sorts after any ISO date
    assert.ok(ta <= tb, `${a.name} scored before ${b.name}`);
    if (ta === tb) assert.ok(a.name.localeCompare(b.name) <= 0, `${a.name} before ${b.name} by name`);
  }
}

describe('basics', () => {
  test('register, log in, read yourself', async () => {
    const reg = await api('POST', '/auth/register', {
      body: { name: 'Basic Tester', email: 'Basic@Test.dev', password: 'secret123' },
    });
    assert.equal(reg.status, 201);
    assert.equal(reg.body.user.email, 'basic@test.dev');
    assert.equal(reg.body.user.profileComplete, false);

    const dup = await api('POST', '/auth/register', {
      body: { name: 'Basic Tester', email: 'basic@test.dev', password: 'secret123' },
    });
    assert.equal(dup.status, 409);

    const wrong = await api('POST', '/auth/login', { body: { email: 'basic@test.dev', password: 'nope-nope' } });
    assert.deepEqual([wrong.status, wrong.body.error], [401, 'Wrong email or password']);

    const token = await login('basic@test.dev', 'secret123');
    const me = await api('GET', '/auth/me', { token });
    assert.equal(me.body.user.name, 'Basic Tester');
    assert.equal((await api('GET', '/auth/me')).status, 401);
  });

  test('profile: validation, then complete', async () => {
    const { token } = await newUser({ profile: null });
    const bad = await api('PUT', '/users/me', { token, body: { role: 'wizard' } });
    assert.equal(bad.status, 400);
    assert.equal(bad.body.details[0].field, 'role');

    assert.equal((await api('GET', '/deck', { token })).status, 409);
    const ok = await api('PUT', '/users/me', { token, body: PROFILE });
    assert.equal(ok.body.user.profileComplete, true);
  });

  test('deck, swipe right on someone who likes you back, create a crew', async () => {
    const me = await newUser();
    const deck = await api('GET', '/deck?limit=50', { token: me.token });
    assert.equal(deck.status, 200);
    assert.ok(deck.body.deck.length > 0);
    assert.ok(deck.body.deck.every((c) => c.score >= 40 && Array.isArray(c.tags)));

    // `seed` on the admin list is autoLike: they swipe right back.
    admin = await login('admin@crewmatch.dev');
    const users = (await api('GET', '/admin/users', { token: admin })).body.users;
    const likesBack = users.find((u) => u.seed && !u.crewId && deck.body.deck.some((c) => c.id === u.id));
    assert.ok(likesBack, 'an autoLike student in the deck');

    const swipe = await api('POST', '/swipe', { token: me.token, body: { targetId: likesBack.id, direction: 'right' } });
    assert.equal(swipe.body.match, true);
    assert.equal(swipe.body.user.id, likesBack.id);

    const crew = await api('POST', '/crews', { token: me.token, body: { name: 'Swipe Squad', memberIds: [likesBack.id] } });
    assert.equal(crew.status, 201);
    assert.equal(crew.body.crew.members.length, 2);
    assert.equal(crew.body.crew.spotsLeft, MAX_CREW_SIZE - 2);
    assert.equal(crew.body.crew.points, 0);
    assert.equal(typeof crew.body.crew.rank, 'number');

    const mine = await api('GET', '/crews/mine', { token: me.token });
    assert.equal(mine.body.crew.id, crew.body.crew.id);
    assert.equal((await api('GET', '/auth/me', { token: me.token })).body.user.crewId, crew.body.crew.id);
  });
});

describe('seed data', () => {
  let web;
  before(async () => {
    web = await login('web@crewmatch.dev');
    admin = await login('admin@crewmatch.dev');
  });

  test('6 events (1 ended, 2 live, 3 upcoming) and 5 challenges (1 ended, 4 open)', async () => {
    const count = (list, state) => list.filter((e) => e.state === state).length;
    // The hackathon's own events: official, and not hosted by a club.
    const official = (list) => list.filter((e) => e.status === 'official' && !e.club);
    const events = official((await api('GET', '/events?kind=event', { token: web })).body.events);
    const challenges = official((await api('GET', '/events?kind=challenge', { token: web })).body.events);
    assert.equal(events.length, 6);
    assert.deepEqual([count(events, 'ended'), count(events, 'live'), count(events, 'upcoming')], [1, 2, 3]);
    assert.equal(challenges.length, 5);
    assert.deepEqual([count(challenges, 'ended'), count(challenges, 'live')], [1, 4]);
    assert.ok(events.every((e) => e.kind === 'event') && challenges.every((e) => e.kind === 'challenge'));
  });

  test('every seeded event has a check-in code, challenges none', async () => {
    const { events } = (await api('GET', '/admin/events', { token: admin })).body;
    for (const e of events) {
      if (e.kind === 'event') assert.match(e.checkinCode, /^[A-Z2-9]{4}$/, e.title);
      else assert.equal(e.checkinCode, null);
    }
  });

  test('crews of 2 to 4 seeded students, crew field in sync, demo accounts crew-less', async () => {
    const { crews } = (await api('GET', '/leaderboard', { token: web })).body;
    const users = (await api('GET', '/admin/users', { token: admin })).body.users;
    const byId = new Map(users.map((u) => [u.id, u]));
    const seeded = crews.filter((c) => c.name !== 'Swipe Squad');
    assert.ok(seeded.length >= 6);
    for (const crew of seeded) {
      assert.ok(crew.members.length >= 2 && crew.members.length <= MAX_CREW_SIZE, crew.name);
      for (const m of crew.members) {
        const user = byId.get(m.id);
        assert.equal(user.crewId, crew.id, `${m.name} points at ${crew.name}`);
        assert.match(user.email, /@students\.crewmatch\.dev$/);
        assert.equal(user.seed, false, `${m.name} has autoLike off so demo matches stay free`);
      }
    }
    for (const email of ['web@crewmatch.dev', 'mobile@crewmatch.dev']) {
      assert.equal(users.find((u) => u.email === email).crewId, null);
    }
  });

  test('a clear leaderboard and submissions waiting for an admin', async () => {
    const { crews } = (await api('GET', '/leaderboard', { token: web })).body;
    const scored = crews.filter((c) => c.points > 0).map((c) => c.points);
    assert.ok(scored.length >= 4);
    assert.equal(new Set(scored).size, scored.length, 'no ties among scoring crews');

    const stats = (await api('GET', '/admin/stats', { token: admin })).body;
    assert.equal(stats.events, 6 + 3, 'six hackathon events and three Coding Club ones');
    assert.equal(stats.challenges, 5);
    assert.ok(stats.pendingSubmissions >= 2);
    assert.deepEqual([stats.pendingEvents, stats.communityEvents], [2, 1]);
  });
});

describe('events and challenges', () => {
  let a; let b; let loner;
  before(async () => {
    admin = await login('admin@crewmatch.dev');
    a = await newCrew('Alpha Crew');
    b = await newCrew('Bravo Crew');
    loner = await newUser();
  });

  test('members never see the check-in code; admins do', async () => {
    const event = await createEvent({ checkinCode: 'mine' });
    assert.equal(event.checkinCode, 'MINE');
    const list = (await api('GET', '/events', { token: a.a.token })).body.events;
    assert.ok(list.length > 0 && list.every((e) => !('checkinCode' in e) && !('entries' in e)));
    assert.ok(!('checkinCode' in (await getEvent(event.id, a.a.token))));
  });

  test('state comes from the clock on every response', async () => {
    const upcoming = await createEvent({ startsAt: minutesFromNow(60), endsAt: minutesFromNow(120) });
    const live = await createEvent({ startsAt: minutesFromNow(-30), endsAt: minutesFromNow(30) });
    const ended = await createEvent({ startsAt: minutesFromNow(-120), endsAt: minutesFromNow(-60) });
    assert.equal((await getEvent(upcoming.id, a.a.token)).state, 'upcoming');
    assert.equal((await getEvent(live.id, a.a.token)).state, 'live');
    assert.equal((await getEvent(ended.id, a.a.token)).state, 'ended');

    const moved = await api('PATCH', `/admin/events/${upcoming.id}`, {
      token: admin, body: { startsAt: minutesFromNow(-90), endsAt: minutesFromNow(-5) },
    });
    assert.equal(moved.body.event.state, 'ended');
  });

  test('list order: live (ending soonest), upcoming (starting soonest), ended (latest first)', async () => {
    const tag = `Order ${Date.now()}`;
    await createEvent({ title: `${tag} ended early`, startsAt: minutesFromNow(-300), endsAt: minutesFromNow(-240) });
    await createEvent({ title: `${tag} live long`, startsAt: minutesFromNow(-10), endsAt: minutesFromNow(300) });
    await createEvent({ title: `${tag} later`, startsAt: minutesFromNow(200), endsAt: minutesFromNow(260) });
    await createEvent({ title: `${tag} ended late`, startsAt: minutesFromNow(-100), endsAt: minutesFromNow(-50) });
    await createEvent({ title: `${tag} soon`, startsAt: minutesFromNow(20), endsAt: minutesFromNow(80) });
    await createEvent({ title: `${tag} live short`, startsAt: minutesFromNow(-10), endsAt: minutesFromNow(20) });

    for (const path of ['/events', '/admin/events']) {
      const { events } = (await api('GET', path, { token: path === '/events' ? a.a.token : admin })).body;
      assertListOrder(events);
      assert.deepEqual(
        events.filter((e) => e.title.startsWith(tag)).map((e) => e.title.slice(tag.length + 1)),
        ['live short', 'live long', 'soon', 'later', 'ended late', 'ended early']
      );
    }
    const challenges = (await api('GET', '/events?kind=challenge', { token: a.a.token })).body.events;
    assertListOrder(challenges);
    assert.equal((await api('GET', '/events?kind=party', { token: a.a.token })).status, 400);
  });

  test('no crew: join, check-in and submit are refused', async () => {
    const event = await createEvent({ checkinCode: 'NOCR' });
    const challenge = await createChallenge();
    for (const [path, body] of [
      [`/events/${event.id}/join`],
      [`/events/${event.id}/checkin`, { code: 'NOCR' }],
      [`/events/${challenge.id}/submit`, { url: 'https://example.com' }],
    ]) {
      const res = await api('POST', path, { token: loner.token, body });
      assert.deepEqual([res.status, res.body.error], [409, 'Join or create a crew first'], path);
    }
    const seen = await getEvent(event.id, loner.token);
    assert.equal(seen.myEntry, null);
  });

  test('unknown or malformed id: 404 Event not found', async () => {
    const missing = '6720aaaaaaaaaaaaaaaaaaaa';
    for (const [method, path, token] of [
      ['GET', `/events/${missing}`, a.a.token],
      ['GET', '/events/not-an-id', a.a.token],
      ['POST', `/events/${missing}/join`, a.a.token],
      ['DELETE', `/events/${missing}/join`, a.a.token],
      ['PATCH', `/admin/events/${missing}`, admin],
      ['DELETE', `/admin/events/${missing}`, admin],
      ['POST', `/admin/events/${missing}/entries/${a.id}/approve`, admin],
    ]) {
      const res = await api(method, path, { token, body: method === 'PATCH' ? { points: 5 } : undefined });
      assert.deepEqual([res.status, res.body.error], [404, 'Event not found'], `${method} ${path}`);
    }
  });

  test('join, join again, crewmates share the entry, leave', async () => {
    const event = await createEvent();
    const joined = await api('POST', `/events/${event.id}/join`, { token: a.a.token });
    assert.equal(joined.status, 200);
    assert.equal(joined.body.event.crewCount, 1);
    assert.equal(joined.body.event.myEntry.status, 'joined');
    assert.deepEqual(
      { ...joined.body.event.myEntry, joinedAt: undefined },
      { status: 'joined', submissionUrl: null, note: null, pointsAwarded: 0, joinedAt: undefined, completedAt: null }
    );

    // Any member acts for the crew; joining twice is a no-op.
    const again = await api('POST', `/events/${event.id}/join`, { token: a.b.token });
    assert.equal(again.body.event.crewCount, 1);
    assert.equal(again.body.event.myEntry.status, 'joined');

    const detail = await getEvent(event.id, b.a.token);
    assert.equal(detail.myEntry, null);
    assert.deepEqual(detail.crews, [{ id: a.id, name: 'Alpha Crew', memberCount: 2, status: 'joined' }]);

    const left = await api('DELETE', `/events/${event.id}/join`, { token: a.b.token });
    assert.equal(left.status, 200);
    assert.equal(left.body.event.myEntry, null);
    assert.equal(left.body.event.crewCount, 0);
  });

  test('two members tapping join at once add one entry', async () => {
    const event = await createEvent();
    const results = await Promise.all([a.a, a.b].map((m) => api('POST', `/events/${event.id}/join`, { token: m.token })));
    assert.deepEqual(results.map((r) => r.status), [200, 200]);
    assert.equal((await getEvent(event.id, a.a.token)).crewCount, 1);
  });

  test('capacity: a full event refuses new crews', async () => {
    const event = await createEvent({ capacity: 1 });
    await api('POST', `/events/${event.id}/join`, { token: a.a.token });
    const full = await api('POST', `/events/${event.id}/join`, { token: b.a.token });
    assert.deepEqual([full.status, full.body.error], [409, 'This is full']);

    // A crew already in can still "join" (no-op), and leaving frees the spot.
    assert.equal((await api('POST', `/events/${event.id}/join`, { token: a.b.token })).status, 200);
    await api('DELETE', `/events/${event.id}/join`, { token: a.a.token });
    assert.equal((await api('POST', `/events/${event.id}/join`, { token: b.a.token })).status, 200);

    // Submitting without accepting first takes a spot too.
    const challenge = await createChallenge({ capacity: 1 });
    await api('POST', `/events/${challenge.id}/join`, { token: a.a.token });
    const late = await api('POST', `/events/${challenge.id}/submit`, { token: b.a.token, body: { url: 'https://example.com' } });
    assert.deepEqual([late.status, late.body.error], [409, 'This is full']);
  });

  test('ended: no joining or submitting; check-in has a 30 minute grace period', async () => {
    const ended = await createEvent({ startsAt: minutesFromNow(-120), endsAt: minutesFromNow(-40), checkinCode: 'LATE' });
    const join = await api('POST', `/events/${ended.id}/join`, { token: a.a.token });
    assert.deepEqual([join.status, join.body.error], [409, 'This has ended']);
    const late = await api('POST', `/events/${ended.id}/checkin`, { token: a.a.token, body: { code: 'LATE' } });
    assert.deepEqual([late.status, late.body.error], [409, 'This has ended']);

    const justEnded = await createEvent({ startsAt: minutesFromNow(-90), endsAt: minutesFromNow(-10), checkinCode: 'GRCE' });
    const joinGrace = await api('POST', `/events/${justEnded.id}/join`, { token: a.a.token });
    assert.deepEqual([joinGrace.status, joinGrace.body.error], [409, 'This has ended']);
    const inGrace = await api('POST', `/events/${justEnded.id}/checkin`, { token: a.a.token, body: { code: 'GRCE' } });
    assert.equal(inGrace.status, 200);

    const closed = await createChallenge({ startsAt: minutesFromNow(-120), endsAt: minutesFromNow(-1) });
    const submit = await api('POST', `/events/${closed.id}/submit`, { token: a.a.token, body: { url: 'https://example.com' } });
    assert.deepEqual([submit.status, submit.body.error], [409, 'This has ended']);
  });

  test('check-in: wrong code, trimmed case-insensitive code, then once per crew', async () => {
    const event = await createEvent({ checkinCode: 'K7TQ', points: 75 });
    await api('POST', `/events/${event.id}/join`, { token: a.a.token });

    const wrong = await api('POST', `/events/${event.id}/checkin`, { token: a.a.token, body: { code: 'K7TX' } });
    assert.deepEqual([wrong.status, wrong.body.error], [400, 'Wrong check-in code']);
    const empty = await api('POST', `/events/${event.id}/checkin`, { token: a.a.token, body: { code: '' } });
    assert.deepEqual([empty.status, empty.body.error], [400, 'Wrong check-in code']);

    const ok = await api('POST', `/events/${event.id}/checkin`, { token: a.a.token, body: { code: '  k7tq ' } });
    assert.equal(ok.status, 200);
    assert.equal(ok.body.pointsAwarded, 75);
    assert.equal(ok.body.event.myEntry.status, 'completed');
    assert.equal(ok.body.event.myEntry.pointsAwarded, 75);
    assert.ok(ok.body.event.myEntry.completedAt);

    const twice = await api('POST', `/events/${event.id}/checkin`, { token: a.b.token, body: { code: 'K7TQ' } });
    assert.deepEqual([twice.status, twice.body.error], [409, 'Your crew already checked in']);
    const leave = await api('DELETE', `/events/${event.id}/join`, { token: a.b.token });
    assert.deepEqual([leave.status, leave.body.error], [409, "You can't leave after submitting"]);

    // No RSVP needed: checking in creates the entry.
    const walkIn = await api('POST', `/events/${event.id}/checkin`, { token: b.b.token, body: { code: 'k7tq' } });
    assert.equal(walkIn.status, 200);
    assert.equal(walkIn.body.event.crewCount, 2);

    const challenge = await createChallenge();
    const notEvent = await api('POST', `/events/${challenge.id}/checkin`, { token: a.a.token, body: { code: 'K7TQ' } });
    assert.equal(notEvent.status, 400);
  });

  test('two members checking in at once award the points once', async () => {
    const event = await createEvent({ checkinCode: 'DUAL', points: 40 });
    const results = await Promise.all([a.a, a.b].map((m) =>
      api('POST', `/events/${event.id}/checkin`, { token: m.token, body: { code: 'DUAL' } })));
    assert.deepEqual(results.map((r) => r.status).sort(), [200, 409]);
    const { entries } = await adminEvent(event.id);
    assert.equal(entries.length, 1);
    assert.equal(entries[0].pointsAwarded, 40);
  });

  test('submit, approve with a bonus, then the leaderboard and /crews/mine agree', async () => {
    const charlie = await newCrew('Charlie Crew');
    const challenge = await createChallenge({ points: 120 });
    const path = `/events/${challenge.id}/submit`;

    const badUrl = await api('POST', path, { token: charlie.a.token, body: { url: 'ftp://files.example.com/x' } });
    assert.equal(badUrl.status, 400);
    assert.equal(badUrl.body.details[0].field, 'url');
    const longNote = await api('POST', path, { token: charlie.a.token, body: { url: 'https://example.com', note: 'x'.repeat(281) } });
    assert.equal(longNote.status, 400);
    assert.equal(longNote.body.details[0].field, 'note');

    await api('POST', `/events/${challenge.id}/join`, { token: charlie.a.token });
    const sent = await api('POST', path, { token: charlie.a.token, body: { url: 'https://example.com/v1', note: 'First try' } });
    assert.equal(sent.status, 200);
    assert.equal(sent.body.event.myEntry.status, 'submitted');
    assert.equal(sent.body.event.myEntry.submissionUrl, 'https://example.com/v1');

    const leave = await api('DELETE', `/events/${challenge.id}/join`, { token: charlie.b.token });
    assert.deepEqual([leave.status, leave.body.error], [409, "You can't leave after submitting"]);

    // Allowed again until it's approved: replaces the link.
    const resent = await api('POST', path, { token: charlie.b.token, body: { url: 'https://example.com/v2' } });
    assert.equal(resent.body.event.myEntry.submissionUrl, 'https://example.com/v2');
    assert.equal(resent.body.event.myEntry.note, null);

    const checkin = await api('POST', `/events/${challenge.id}/checkin`, { token: charlie.a.token, body: { code: 'X' } });
    assert.equal(checkin.status, 400);
    const event = await createEvent();
    const notChallenge = await api('POST', `/events/${event.id}/submit`, { token: charlie.a.token, body: { url: 'https://example.com' } });
    assert.equal(notChallenge.status, 400);

    const approved = await api('POST', `/admin/events/${challenge.id}/entries/${charlie.id}/approve`, {
      token: admin, body: { points: 400 },
    });
    assert.equal(approved.status, 200);
    const entry = approved.body.event.entries.find((e) => e.crew.id === charlie.id);
    assert.deepEqual([entry.status, entry.pointsAwarded, entry.crew.name], ['completed', 400, 'Charlie Crew']);
    assert.ok(entry.completedAt);
    assert.equal(approved.body.event.myEntry, null);

    const after = await api('POST', path, { token: charlie.a.token, body: { url: 'https://example.com/v3' } });
    assert.deepEqual([after.status, after.body.error], [409, 'Already completed']);

    const board = (await api('GET', '/leaderboard', { token: charlie.a.token })).body;
    assert.equal(board.title, 'Test Hack 2026');
    assert.equal(board.myCrewId, charlie.id);
    assert.ok(!Number.isNaN(Date.parse(board.updatedAt)));
    assertLeaderboardOrder(board.crews);
    const row = board.crews.find((c) => c.id === charlie.id);
    assert.deepEqual([row.points, row.completed, row.events, row.challenges], [400, 1, 0, 1]);
    assert.equal(row.lastScoredAt, entry.completedAt);
    assert.deepEqual(Object.keys(row.members[0]).sort(), ['avatar', 'id', 'name', 'role']);

    const mine = (await api('GET', '/crews/mine', { token: charlie.b.token })).body.crew;
    assert.deepEqual([mine.points, mine.rank], [row.points, row.rank]);
    assert.equal(board.crews.length, await Crew.countDocuments());
  });

  test('reject sends the entry back to joined with a note', async () => {
    const challenge = await createChallenge();
    await api('POST', `/events/${challenge.id}/submit`, { token: b.a.token, body: { url: 'https://example.com/b' } });
    const rejected = await api('POST', `/admin/events/${challenge.id}/entries/${b.id}/reject`, {
      token: admin, body: { note: 'The link needs view access' },
    });
    assert.equal(rejected.status, 200);

    const seen = (await getEvent(challenge.id, b.b.token)).myEntry;
    assert.deepEqual(
      [seen.status, seen.note, seen.pointsAwarded, seen.completedAt],
      ['joined', 'The link needs view access', 0, null]
    );
    // Back to joined, so the crew can resubmit or leave.
    const again = await api('POST', `/events/${challenge.id}/submit`, { token: b.b.token, body: { url: 'https://example.com/b2' } });
    assert.equal(again.body.event.myEntry.status, 'submitted');

    // Approve works on any status, then reject can take the points back.
    await api('POST', `/admin/events/${challenge.id}/entries/${b.id}/approve`, { token: admin });
    assert.equal((await getEvent(challenge.id, b.a.token)).myEntry.pointsAwarded, 100);
    await api('POST', `/admin/events/${challenge.id}/entries/${b.id}/reject`, { token: admin });
    assert.equal((await getEvent(challenge.id, b.a.token)).myEntry.note, null);
    assert.equal((await api('DELETE', `/events/${challenge.id}/join`, { token: b.a.token })).body.event.myEntry, null);

    const noEntry = await api('POST', `/admin/events/${challenge.id}/entries/${a.id}/approve`, { token: admin });
    assert.deepEqual([noEntry.status, noEntry.body.error], [404, 'Entry not found']);
    const badCrew = await api('POST', `/admin/events/${challenge.id}/entries/nope/reject`, { token: admin });
    assert.equal(badCrew.status, 404);
  });

  test('leaderboard ties: whoever reached the score first, then name', async () => {
    const [late, early] = [await newCrew('Tie Late'), await newCrew('Tie Early')];
    const [zed, abe] = [await newCrew('Zed Zero'), await newCrew('Abe Zero')];
    const challenge = await createChallenge({ points: 333 });
    for (const crew of [early, late]) {
      await api('POST', `/events/${challenge.id}/submit`, { token: crew.a.token, body: { url: 'https://example.com' } });
      await api('POST', `/admin/events/${challenge.id}/entries/${crew.id}/approve`, { token: admin });
    }
    const { crews } = (await api('GET', '/leaderboard', { token: late.a.token })).body;
    assertLeaderboardOrder(crews);
    const at = (crew) => crews.findIndex((c) => c.id === crew.id);
    assert.ok(at(early) < at(late), 'Tie Early scored first');
    assert.ok(at(abe) < at(zed), 'zero-point crews by name');
    assert.equal(crews[at(zed)].lastScoredAt, null);
    assert.equal(crews[at(zed)].points, 0);
  });

  test('admin only: members get 403', async () => {
    const event = await createEvent();
    for (const [method, path, body] of [
      ['GET', '/admin/events'],
      ['POST', '/admin/events', {}],
      ['PATCH', `/admin/events/${event.id}`, { points: 1 }],
      ['DELETE', `/admin/events/${event.id}`],
      ['POST', `/admin/events/${event.id}/entries/${a.id}/approve`, {}],
      ['POST', `/admin/events/${event.id}/entries/${a.id}/reject`, {}],
      ['GET', '/admin/stats'],
    ]) {
      const res = await api(method, path, { token: a.a.token, body });
      assert.deepEqual([res.status, res.body.error], [403, 'Admins only'], `${method} ${path}`);
    }
  });

  test('admin create: validation, generated codes, defaults', async () => {
    const base = {
      kind: 'event', title: 'Validated', summary: 'Checks', category: 'talk',
      startsAt: minutesFromNow(60), endsAt: minutesFromNow(120), points: 10,
    };
    const post = (body) => api('POST', '/admin/events', { token: admin, body });
    const field = (res) => res.body.details?.map((d) => d.field);

    const backwards = await post({ ...base, endsAt: minutesFromNow(30) });
    assert.equal(backwards.status, 400);
    assert.deepEqual(field(backwards), ['endsAt']);
    assert.deepEqual(field(await post({ ...base, category: 'build' })), ['category']);
    assert.deepEqual(field(await post({ ...base, points: 1001 })), ['points']);
    assert.deepEqual(field(await post({ ...base, capacity: 0 })), ['capacity']);
    assert.deepEqual(field(await post({ ...base, startsAt: 'someday' })), ['startsAt']);
    assert.deepEqual(field(await post({ ...base, summary: 'x'.repeat(141) })), ['summary']);

    const created = await post(base);
    assert.equal(created.status, 201);
    const { event } = created.body;
    assert.equal(event.checkinCode.length, 4);
    assert.ok([...event.checkinCode].every((ch) => CHECKIN_CODE_CHARS.includes(ch)));
    assert.deepEqual([event.capacity, event.details, event.location, event.crewCount, event.entries], [null, '', 'TBA', 0, []]);
    assert.equal(event.state, 'upcoming');

    const blank = await post({ ...base, checkinCode: '' });
    assert.equal(blank.body.event.checkinCode.length, 4);

    const challenge = await post({ ...base, kind: 'challenge', category: 'pitch', checkinCode: 'NOPE' });
    assert.deepEqual([challenge.body.event.checkinCode, challenge.body.event.location], [null, 'Anywhere']);
  });

  test('admin edit and delete', async () => {
    const event = await createEvent({ checkinCode: 'EDIT' });
    const patch = (body) => api('PATCH', `/admin/events/${event.id}`, { token: admin, body });

    const edited = await patch({ title: 'Edited title', points: 99, capacity: 3 });
    assert.equal(edited.status, 200);
    assert.deepEqual(
      [edited.body.event.title, edited.body.event.points, edited.body.event.capacity, edited.body.event.checkinCode],
      ['Edited title', 99, 3, 'EDIT']
    );
    assert.equal((await patch({ startsAt: minutesFromNow(600) })).status, 400);
    assert.equal((await patch({ points: -1 })).status, 400);
    assert.equal((await patch({ checkinCode: null })).body.event.checkinCode.length, 4);

    // Echoing the whole object back is fine: unknown fields are ignored.
    const echoed = await patch({ ...edited.body.event, title: 'Echoed' });
    assert.equal(echoed.body.event.title, 'Echoed');

    assert.equal((await api('DELETE', `/admin/events/${event.id}`, { token: admin })).status, 204);
    assert.equal((await api('GET', `/events/${event.id}`, { token: a.a.token })).status, 404);
  });

  test('admin stats count events, challenges and pending submissions', async () => {
    const before = (await api('GET', '/admin/stats', { token: admin })).body;
    const challenge = await createChallenge();
    await api('POST', `/events/${challenge.id}/submit`, { token: a.a.token, body: { url: 'https://example.com/s' } });
    await createEvent();

    const after = (await api('GET', '/admin/stats', { token: admin })).body;
    assert.equal(after.challenges, before.challenges + 1);
    assert.equal(after.events, before.events + 1);
    assert.equal(after.pendingSubmissions, before.pendingSubmissions + 1);
    assert.equal(after.events + after.challenges, await Event.countDocuments({ status: 'official' }));
  });

  test('a crew that dissolves leaves its entries behind safely', async () => {
    const delta = await newCrew('Delta Crew');
    const event = await createEvent({ checkinCode: 'GONE', capacity: 2 });
    await api('POST', `/events/${event.id}/checkin`, { token: delta.a.token, body: { code: 'GONE' } });
    await api('POST', `/events/${event.id}/join`, { token: a.a.token });
    assert.equal((await getEvent(event.id, a.a.token)).crewCount, 2);

    // Leaving a crew of two dissolves it (leaveCrewById) and drops its entries.
    assert.equal((await api('DELETE', '/crews/mine', { token: delta.a.token })).status, 204);
    assert.equal((await getEvent(event.id, a.a.token)).crewCount, 1);
    assert.equal((await api('POST', `/events/${event.id}/join`, { token: b.a.token })).status, 200);
    const board = (await api('GET', '/leaderboard', { token: delta.b.token })).body;
    assert.ok(!board.crews.some((c) => c.id === delta.id));
    assert.equal(board.myCrewId, null);

    // A crew deleted behind our back (no clean-up) is skipped everywhere.
    const echo = await newCrew('Echo Crew');
    const ghost = await createChallenge();
    await api('POST', `/events/${ghost.id}/submit`, { token: echo.a.token, body: { url: 'https://example.com/e' } });
    await api('POST', `/admin/events/${ghost.id}/entries/${echo.id}/approve`, { token: admin });
    await Crew.deleteOne({ _id: echo.id });

    assert.equal((await getEvent(ghost.id, a.a.token)).crewCount, 0);
    assert.deepEqual((await getEvent(ghost.id, a.a.token)).crews, []);
    assert.equal((await api('GET', '/events', { token: echo.a.token })).status, 200);
    assert.deepEqual((await adminEvent(ghost.id)).entries, []);
    assert.equal((await api('PATCH', `/admin/events/${ghost.id}`, { token: admin, body: { points: 10 } })).status, 200);
    assert.ok(!(await api('GET', '/leaderboard', { token: a.a.token })).body.crews.some((c) => c.id === echo.id));
    assert.equal((await api('GET', '/admin/stats', { token: admin })).status, 200);
  });
});

describe('student-hosted events', () => {
  const hosted = (fields = {}) => ({
    kind: 'event', title: 'Study jam', summary: 'Made by a student', category: 'workshop',
    startsAt: minutesFromNow(-10), endsAt: minutesFromNow(90), ...fields,
  });

  test('community right away, the host sees the code, others do not', async () => {
    const crew = await newCrew('Host Crew');
    const res = await api('POST', '/events', { token: crew.a.token, body: hosted({ points: 999 }) });
    assert.equal(res.status, 201, JSON.stringify(res.body));
    const { event } = res.body;
    assert.deepEqual([event.status, event.points, event.hosting, event.host.id], ['community', 0, true, crew.a.id]);
    assert.match(event.checkinCode, /^[A-Z2-9]{4}$/);

    const other = await newUser();
    const seen = await getEvent(event.id, other.token);
    assert.deepEqual([seen.hosting, seen.checkinCode, seen.host.id], [false, undefined, crew.a.id]);

    // Checking in at a community event earns no points.
    const visitor = await newCrew('Visitors');
    const checked = await api('POST', `/events/${event.id}/checkin`, { token: visitor.a.token, body: { code: event.checkinCode } });
    assert.deepEqual([checked.status, checked.body.pointsAwarded], [200, 0]);
  });

  test('asking for points waits for an organiser, who approves and back-fills', async () => {
    const host = await newUser();
    const { body } = await api('POST', '/events', { token: host.token, body: hosted({ askPoints: 30 }) });
    assert.deepEqual([body.event.status, body.event.askedPoints, body.event.points], ['pending', 30, 0]);

    const crew = await newCrew('Early Birds');
    const code = (await adminEvent(body.event.id)).checkinCode;
    await api('POST', `/events/${body.event.id}/checkin`, { token: crew.a.token, body: { code } });

    const approved = await api('POST', `/admin/events/${body.event.id}/official`, { token: admin, body: { points: 40 } });
    assert.equal(approved.status, 200);
    assert.deepEqual([approved.body.event.status, approved.body.event.points], ['official', 40]);
    assert.equal(approved.body.event.entries[0].pointsAwarded, 40);
    assert.equal((await api('POST', `/admin/events/${body.event.id}/official`, { token: admin, body: {} })).status, 409);
  });

  test('keep as community, or reject by deleting', async () => {
    const host = await newUser();
    const one = (await api('POST', '/events', { token: host.token, body: hosted({ askPoints: 20 }) })).body.event;
    const kept = await api('POST', `/admin/events/${one.id}/community`, { token: admin });
    assert.deepEqual([kept.status, kept.body.event.status, kept.body.event.points], [200, 'community', 0]);

    const two = (await api('POST', '/events', { token: host.token, body: hosted({ askPoints: 20 }) })).body.event;
    assert.equal((await api('DELETE', `/admin/events/${two.id}`, { token: admin })).status, 204);
    assert.equal((await api('GET', `/events/${two.id}`, { token: host.token })).status, 404);
  });

  test('validation, a limit of 3 at a time, and only the host can remove one', async () => {
    const host = await newUser();
    const post = (body) => api('POST', '/events', { token: host.token, body });
    assert.equal((await post(hosted({ askPoints: 101 }))).status, 400);
    assert.equal((await post(hosted({ category: 'build' }))).status, 400);
    assert.equal((await post(hosted({ startsAt: minutesFromNow(-120), endsAt: minutesFromNow(-60) }))).status, 400);

    const made = [];
    for (let i = 0; i < 3; i++) made.push((await post(hosted({ title: `Jam ${i}` }))).body.event);
    const fourth = await post(hosted());
    assert.deepEqual([fourth.status, fourth.body.error], [409, 'You can host up to 3 events at a time']);

    const stranger = await newUser();
    assert.equal((await api('DELETE', `/events/${made[0].id}`, { token: stranger.token })).status, 403);
    assert.equal((await api('DELETE', `/events/${made[0].id}`, { token: host.token })).status, 204);
    assert.equal((await post(hosted())).status, 201);
  });

  test('members cannot approve; official events cannot be removed by students', async () => {
    const host = await newUser();
    const mine = (await api('POST', '/events', { token: host.token, body: hosted({ askPoints: 10 }) })).body.event;
    for (const path of [`/admin/events/${mine.id}/official`, `/admin/events/${mine.id}/community`]) {
      assert.equal((await api('POST', path, { token: host.token, body: {} })).status, 403);
    }
    const official = await createEvent();
    assert.equal((await api('DELETE', `/events/${official.id}`, { token: host.token })).status, 403);
  });
});

describe('continue with Google', () => {
  // Fake tokens: "ok|<sub>|<email>|<name>"; anything else fails like a bad signature.
  before(() => setGoogleVerifier(async (token) => {
    const [kind, sub, email, name, verified = 'yes'] = token.split('|');
    if (kind !== 'ok') throw new Error('bad token');
    return { sub, email, name, email_verified: verified === 'yes', picture: 'https://example.com/me.png' };
  }));
  const google = (idToken) => api('POST', '/auth/google', { body: { idToken } });
  const tok = (...parts) => ['ok', ...parts].join('|').padEnd(24, ' ');

  test('a new person gets a verified account, and signs in again with the same Google id', async () => {
    const first = await google(tok('g-100', 'Nova.Rao@Gmail.com', 'Nova Rao'));
    assert.equal(first.status, 201, JSON.stringify(first.body));
    assert.deepEqual(
      [first.body.created, first.body.user.email, first.body.user.name, first.body.user.emailVerified, first.body.user.profileComplete],
      [true, 'nova.rao@gmail.com', 'Nova Rao', true, false]
    );
    // Verified straight away: past the email check, on to the profile.
    assert.equal((await api('GET', '/matches', { token: first.body.token })).status, 200);

    const again = await google(tok('g-100', 'nova.rao@gmail.com', 'Nova Rao'));
    assert.deepEqual([again.status, again.body.created, again.body.user.id], [200, false, first.body.user.id]);
  });

  test('links Google to an existing password account with the same email and verifies it', async () => {
    process.env.REQUIRE_EMAIL_VERIFICATION = 'true';
    const reg = await api('POST', '/auth/register', { body: { name: 'Link Me', email: 'link.me@test.dev', password: 'secret123' } });
    delete process.env.REQUIRE_EMAIL_VERIFICATION;
    assert.equal(reg.body.user.emailVerified, false);
    const res = await google(tok('g-200', 'link.me@test.dev', 'Link Me'));
    assert.deepEqual([res.status, res.body.user.id, res.body.user.emailVerified], [200, reg.body.user.id, true]);
    // The password still works too.
    assert.equal((await api('POST', '/auth/login', { body: { email: 'link.me@test.dev', password: 'secret123' } })).status, 200);
  });

  test('bad tokens and unverified Google emails are refused', async () => {
    assert.deepEqual([(await google('x'.repeat(40))).status], [401]);
    assert.equal((await google(tok('g-300', 'nope@test.dev', 'No', 'no'))).status, 401);
    assert.equal((await google('short')).status, 400);
  });
});

describe('finding people: handles, search and team-up requests', () => {
  const register = async (name, email) => {
    const { body } = await api('POST', '/auth/register', { body: { name, email, password: 'secret123' } });
    await api('PUT', '/users/me', { token: body.token, body: PROFILE });
    return { token: body.token, id: body.user.id, handle: body.user.handle };
  };
  const send = (from, to, extra = {}) => api('POST', '/requests', { token: from.token, body: { to: to.id, ...extra } });

  test('everyone gets a unique handle, and the public link works without signing in', async () => {
    const a = await register('Handle Twin', 'twin.one@test.dev');
    const b = await register('Handle Twin', 'twin.two@test.dev');
    assert.deepEqual([a.handle, b.handle], ['handle-twin', 'handle-twin-2']);

    const pub = await api('GET', '/public/u/handle-twin');
    assert.equal(pub.status, 200);
    assert.equal(pub.body.user.name, 'Handle Twin');
    assert.equal(pub.body.user.email, undefined);
    assert.equal((await api('GET', '/public/u/nobody-here')).status, 404);

    const seeded = await api('GET', '/public/u/tara-fernandes');
    assert.equal(seeded.body.user.name, 'Tara Fernandes');
    const viaApp = await api('GET', '/users/handle/tara-fernandes', { token: a.token });
    assert.equal(typeof viaApp.body.user.score, 'number');
    const byId = await api('GET', `/users/handle/${viaApp.body.user.id}`, { token: a.token });
    assert.equal(byId.body.user.handle, 'tara-fernandes');
  });

  test('search by skill or name, best fit first, never yourself', async () => {
    const me = await register('Search Person', 'search.person@test.dev');
    const byName = await api('GET', `/users/search?q=${encodeURIComponent('Tara')}`, { token: me.token });
    assert.ok(byName.body.results.some((u) => u.name === 'Tara Fernandes'));
    const all = (await api('GET', '/users/search', { token: me.token })).body.results;
    assert.ok(all.every((u) => u.id !== me.id));
    for (let i = 1; i < all.length; i++) assert.ok(all[i - 1].score >= all[i].score);
    const free = (await api('GET', '/users/search?free=1', { token: me.token })).body.results;
    assert.ok(free.length > 0 && free.every((u) => u.crewName === null));
    assert.equal((await api('GET', '/users/search?q=%5B(', { token: me.token })).status, 200);
  });

  test('send, see it in their Requests with the note, accept, and you are matched', async () => {
    const a = await register('Req Sender', 'req.sender@test.dev');
    const b = await register('Req Receiver', 'req.receiver@test.dev');
    const sent = await send(a, b, { note: 'Want to build together?', source: 'qr' });
    assert.equal(sent.status, 201, JSON.stringify(sent.body));
    assert.equal((await send(a, b)).status, 409);
    assert.equal((await send(a, a)).status, 400);

    const theirs = (await api('GET', '/requests', { token: b.token })).body;
    assert.equal(theirs.incoming.length, 1);
    assert.deepEqual([theirs.incoming[0].note, theirs.incoming[0].source, theirs.incoming[0].user.id], ['Want to build together?', 'qr', a.id]);
    assert.equal((await api('GET', '/requests', { token: a.token })).body.sent[0].user.relation, 'sent');

    const accepted = await api('POST', `/requests/${theirs.incoming[0].id}/accept`, { token: b.token });
    assert.deepEqual([accepted.status, accepted.body.match], [200, true]);
    const matches = (await api('GET', '/matches', { token: a.token })).body.matches;
    assert.ok(matches.some((m) => m.id === b.id));
    assert.equal((await send(a, b)).body.error, "You're already matched");
  });

  test('asking someone who already asked you makes the match straight away', async () => {
    const a = await register('Mutual Ask', 'mutual.a@test.dev');
    const b = await register('Mutual Bee', 'mutual.b@test.dev');
    await send(a, b);
    const back = await send(b, a);
    assert.deepEqual([back.status, back.body.match], [200, true]);
  });

  test('decline is final for that sender; withdraw lets you ask again', async () => {
    const a = await register('Decline Me', 'decline.a@test.dev');
    const b = await register('Decline You', 'decline.b@test.dev');
    await send(a, b);
    const id = (await api('GET', '/requests', { token: b.token })).body.incoming[0].id;
    assert.equal((await api('POST', `/requests/${id}/decline`, { token: b.token })).status, 200);
    assert.equal((await api('POST', `/requests/${id}/accept`, { token: b.token })).status, 409);
    assert.equal((await send(a, b)).status, 409);
    assert.equal((await api('GET', '/requests', { token: a.token })).body.sent.length, 0);

    const c = await register('Withdraw Me', 'withdraw.c@test.dev');
    await send(a, c);
    const mine = (await api('GET', '/requests', { token: a.token })).body.sent[0].id;
    assert.equal((await api('DELETE', `/requests/${mine}`, { token: c.token })).status, 404);
    assert.equal((await api('DELETE', `/requests/${mine}`, { token: a.token })).status, 204);
    assert.equal((await send(a, c)).status, 201);
  });

  test('a right swipe in Discover shows up in their Requests', async () => {
    const a = await register('Swipe Asker', 'swipe.a@test.dev');
    const b = await register('Swipe Target', 'swipe.b@test.dev');
    await api('POST', '/swipe', { token: a.token, body: { targetId: b.id, direction: 'right' } });
    const inc = (await api('GET', '/requests', { token: b.token })).body.incoming;
    assert.deepEqual([inc.length, inc[0].source], [1, 'discover']);
  });

  test(`at most 20 requests a day`, async () => {
    const a = await register('Busy Asker', 'busy.asker@test.dev');
    const targets = (await api('GET', '/users/search', { token: a.token })).body.results.filter((u) => !u.relation).slice(0, 21);
    assert.equal(targets.length, 21);
    for (const t of targets.slice(0, 20)) assert.equal((await send(a, t)).status, 201);
    assert.equal((await send(a, targets[20])).status, 429);
  });
});

describe('clubs', () => {
  const clubsFor = async (token) => (await api('GET', '/clubs', { token })).body.clubs;

  test('eight seeded clubs; the demo account is in Coding Club and Design Guild', async () => {
    const web = await login('web@crewmatch.dev');
    const clubs = await clubsFor(web);
    assert.equal(clubs.length, 8);
    assert.deepEqual(clubs.filter((c) => c.joined).map((c) => c.name).sort(), ['Coding Club', 'Design Guild']);
    const cc = clubs.find((c) => c.name === 'Coding Club');
    assert.equal(cc.isLead, true);
    assert.ok(cc.memberCount >= 3 && cc.weekEvents >= 1);

    const page = (await api('GET', `/clubs/${cc.id}`, { token: web })).body;
    assert.equal(page.events.length, 3);
    assert.ok(page.events.every((e) => e.club.name === 'Coding Club' && e.status === 'official'));
    assert.ok(page.members.length >= 2 && page.members.every((m) => m.clubs.some((c) => c.id === cc.id)));
  });

  test('join, leave, the picker, and at most five clubs', async () => {
    const u = await newUser();
    const clubs = await clubsFor(u.token);
    const joined = await api('POST', `/clubs/${clubs[0].id}/join`, { token: u.token });
    assert.deepEqual(joined.body.user.clubIds, [clubs[0].id]);
    const left = await api('DELETE', `/clubs/${clubs[0].id}/join`, { token: u.token });
    assert.deepEqual(left.body.user.clubIds, []);

    const five = clubs.slice(0, 5).map((c) => c.id);
    assert.equal((await api('PUT', '/users/me/clubs', { token: u.token, body: { clubIds: five } })).status, 200);
    assert.equal((await api('POST', `/clubs/${clubs[5].id}/join`, { token: u.token })).status, 400);
    assert.equal((await api('PUT', '/users/me/clubs', { token: u.token, body: { clubIds: clubs.slice(0, 6).map((c) => c.id) } })).status, 400);
  });

  test('search by club, and a shared club boosts the fit', async () => {
    const u = await newUser();
    const cc = (await clubsFor(u.token)).find((c) => c.name === 'Coding Club');
    const before = (await api('GET', `/users/search?club=${cc.id}`, { token: u.token })).body.results;
    assert.ok(before.length > 0 && before.every((p) => p.clubs.some((c) => c.id === cc.id)));

    await api('POST', `/clubs/${cc.id}/join`, { token: u.token });
    const after = (await api('GET', `/users/search?club=${cc.id}`, { token: u.token })).body.results;
    const one = before[0];
    const again = after.find((p) => p.id === one.id);
    assert.ok(again.score >= one.score && again.score <= 100);
    assert.ok(after.some((p) => p.tags.includes('In your club')));
  });

  test("club leads post events for the club; a verified club's count straight away", async () => {
    const web = await login('web@crewmatch.dev');
    const clubs = await clubsFor(web);
    const cc = clubs.find((c) => c.name === 'Coding Club');
    const body = { kind: 'event', title: 'Lead Night', summary: 'By the lead', category: 'talk', startsAt: minutesFromNow(30), endsAt: minutesFromNow(90), askPoints: 25, clubId: cc.id };
    const made = await api('POST', '/events', { token: web, body });
    assert.equal(made.status, 201, JSON.stringify(made.body));
    assert.deepEqual([made.body.event.status, made.body.event.points, made.body.event.club.name], ['official', 25, 'Coding Club']);

    const other = await newUser();
    assert.equal((await api('POST', '/events', { token: other.token, body })).status, 403);
    const dg = clubs.find((c) => c.name === 'Design Guild');
    await api('PATCH', `/admin/clubs/${dg.id}`, { token: admin, body: { leads: ['web@crewmatch.dev'] } });
    const unverified = await api('POST', '/events', { token: web, body: { ...body, title: 'Poster Jam', clubId: dg.id } });
    assert.deepEqual([unverified.body.event.status, unverified.body.event.points], ['pending', 0]);
  });

  test('organisers create, edit and delete clubs; members only can not', async () => {
    const u = await newUser();
    assert.equal((await api('POST', '/admin/clubs', { token: u.token, body: { name: 'Nope', short: 'NO' } })).status, 403);
    const made = await api('POST', '/admin/clubs', { token: admin, body: { name: 'Chess Club', short: 'cg', category: 'culture', tone: 'navy', leads: ['Lead@Test.dev'] } });
    assert.equal(made.status, 201, JSON.stringify(made.body));
    assert.deepEqual([made.body.club.short, made.body.club.leads], ['CG', ['lead@test.dev']]);
    assert.equal((await api('POST', '/admin/clubs', { token: admin, body: { name: 'chess club', short: 'CC' } })).status, 409);
    assert.equal((await api('POST', '/admin/clubs', { token: admin, body: { name: 'Bad', short: 'B', leads: ['not-an-email'] } })).status, 400);

    const edited = await api('PATCH', `/admin/clubs/${made.body.club.id}`, { token: admin, body: { verified: true } });
    assert.equal(edited.body.club.verified, true);
    await api('POST', `/clubs/${made.body.club.id}/join`, { token: u.token });
    assert.equal((await api('DELETE', `/admin/clubs/${made.body.club.id}`, { token: admin })).status, 204);
    assert.deepEqual((await api('GET', '/auth/me', { token: u.token })).body.user.clubIds, []);
  });
});

describe('CORS', () => {
  const allowOrigin = async (origin) =>
    (await api('GET', '/health', { headers: { origin } })).headers.get('access-control-allow-origin');

  test('CLIENT_URLS and any localhost port are allowed outside production', async () => {
    assert.equal(await allowOrigin('http://localhost:5173'), 'http://localhost:5173');
    assert.equal(await allowOrigin('http://localhost:61234'), 'http://localhost:61234');
    assert.equal(await allowOrigin('http://127.0.0.1:8080'), 'http://127.0.0.1:8080');
  });

  test('other origins are not', async () => {
    assert.equal(await allowOrigin('https://evil.example.com'), null);
    assert.equal(await allowOrigin('http://localhost.evil.example.com:80'), null);
  });
});

describe('hackathon switcher', () => {
  test('lists every hackathon with your rank at each, never a combined rank', async () => {
    const token = await login('web@crewmatch.dev');
    const { hackathons, record } = (await api('GET', '/hackathons', { token })).body;
    assert.equal(hackathons[0].id, 'current');
    assert.equal(hackathons[0].name, 'Test Hack 2026');
    assert.equal(hackathons[0].status, 'live');
    const past = hackathons.filter((h) => h.status === 'ended');
    assert.deepEqual(past.map((h) => h.myRank), [6, 12]);
    assert.equal(hackathons.find((h) => h.status === 'upcoming').myRank, null);
    // No crew at the live one yet, so only the two past ones count.
    assert.deepEqual(record, { hackathons: 2, bestFinish: 6, totalPoints: 480 });
  });

  test('a past board marks your crew there; the live board matches /leaderboard', async () => {
    const token = await login('web@crewmatch.dev');
    const past = (await api('GET', '/hackathons/devfest-hack-mumbai-2026/leaderboard', { token })).body;
    assert.equal(past.crews.find((c) => c.id === past.myCrewId).name, 'Stack Smashers');
    assert.ok(past.crews.every((c) => !('memberEmails' in c)), 'emails stay on the server');

    const live = (await api('GET', '/hackathons/current/leaderboard', { token })).body;
    const plain = (await api('GET', '/leaderboard', { token })).body;
    assert.deepEqual(live.crews.map((c) => c.id), plain.crews.map((c) => c.id));

    assert.equal((await api('GET', '/hackathons/nope/leaderboard', { token })).status, 404);
  });
});

describe('removing a crew member', () => {
  test('frees their spot, but never empties the crew or removes yourself', async () => {
    const crew = await newCrew('Trim Team');
    const c = await newUser();
    await api('POST', '/swipe', { token: crew.a.token, body: { targetId: c.id, direction: 'right' } });
    await api('POST', '/swipe', { token: c.token, body: { targetId: crew.a.id, direction: 'right' } });
    assert.equal((await api('POST', '/crews/mine/members', { token: crew.a.token, body: { userId: c.id } })).status, 200);

    const removed = await api('DELETE', `/crews/mine/members/${c.id}`, { token: crew.a.token });
    assert.equal(removed.status, 200);
    assert.deepEqual(removed.body.crew.members.map((m) => m.id).sort(), [crew.a.id, crew.b.id].sort());
    assert.equal((await api('GET', '/crews/mine', { token: c.token })).body.crew, null);

    assert.equal((await api('DELETE', `/crews/mine/members/${crew.b.id}`, { token: crew.a.token })).status, 409);
    assert.equal((await api('DELETE', `/crews/mine/members/${crew.a.id}`, { token: crew.a.token })).status, 400);
    assert.equal((await api('DELETE', `/crews/mine/members/${c.id}`, { token: crew.a.token })).status, 404);
  });
});

// A 1×1 PNG.
const PIXEL = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

describe('hackathon feed', () => {
  test('seeded posts come newest first with like and comment counts', async () => {
    const token = await login('web@crewmatch.dev');
    const { posts } = (await api('GET', '/posts', { token })).body;
    assert.ok(posts.length >= 5);
    const times = posts.map((p) => new Date(p.createdAt).getTime());
    assert.deepEqual(times, [...times].sort((a, b) => b - a));
    assert.ok(posts[0].likeCount > 0 && posts[0].commentCount === 2 && posts[0].comments.length === 2);
    assert.equal(posts[0].author.name, 'Diya Patel');
  });

  test('post with a photo, like, comment and delete', async () => {
    const crew = await newCrew('Feed Crew');
    const created = await api('POST', '/posts', { token: crew.a.token, body: { text: 'Shipped!', tag: 'win', photo: PIXEL } });
    assert.equal(created.status, 201, JSON.stringify(created.body));
    const { post } = created.body;
    assert.equal(post.crewName, 'Feed Crew');
    assert.match(post.photoUrl, /^\/api\/photos\/[0-9a-f]{24}$/);

    // Photos load without a token, so images can show them.
    const photo = await fetch(`http://127.0.0.1:${PORT}${post.photoUrl}`);
    assert.equal(photo.status, 200);
    assert.equal(photo.headers.get('content-type'), 'image/png');

    const liked = (await api('POST', `/posts/${post.id}/like`, { token: crew.b.token })).body.post;
    assert.deepEqual([liked.likeCount, liked.likedByMe], [1, true]);
    const unliked = (await api('POST', `/posts/${post.id}/like`, { token: crew.b.token })).body.post;
    assert.deepEqual([unliked.likeCount, unliked.likedByMe], [0, false]);

    const commented = await api('POST', `/posts/${post.id}/comments`, { token: crew.b.token, body: { text: 'Congrats' } });
    assert.equal(commented.status, 201);
    assert.equal(commented.body.post.commentCount, 1);
    assert.equal((await api('GET', `/posts/${post.id}/comments`, { token: crew.a.token })).body.comments[0].text, 'Congrats');

    assert.equal((await api('DELETE', `/posts/${post.id}`, { token: crew.b.token })).status, 403);
    assert.equal((await api('DELETE', `/posts/${post.id}`, { token: crew.a.token })).status, 204);
    assert.equal((await fetch(`http://127.0.0.1:${PORT}${post.photoUrl}`)).status, 404);
  });

  test('rejects empty posts and files that are not images', async () => {
    const { token } = await newUser();
    assert.equal((await api('POST', '/posts', { token, body: { text: '  ' } })).status, 400);
    const bad = await api('POST', '/posts', { token, body: { text: 'hi', photo: 'data:text/html;base64,PGI+' } });
    assert.equal(bad.status, 400);
  });
});

describe('crew chat', () => {
  test('only your crew sees its messages; polling returns just the new ones', async () => {
    const crew = await newCrew('Chatty');
    const other = await newCrew('Elsewhere');
    const first = await api('POST', '/crews/mine/messages', { token: crew.a.token, body: { text: 'hello crew' } });
    assert.equal(first.status, 201);
    const since = first.body.message.createdAt;
    await new Promise((r) => setTimeout(r, 5));
    await api('POST', '/crews/mine/messages', { token: crew.b.token, body: { text: 'hey!' } });

    const all = (await api('GET', '/crews/mine/messages', { token: crew.b.token })).body.messages;
    assert.deepEqual(all.map((m) => m.text), ['hello crew', 'hey!']);
    const fresh = (await api('GET', `/crews/mine/messages?after=${encodeURIComponent(since)}`, { token: crew.a.token })).body.messages;
    assert.deepEqual(fresh.map((m) => m.text), ['hey!']);
    assert.deepEqual((await api('GET', '/crews/mine/messages', { token: other.a.token })).body.messages, []);

    const loner = await newUser();
    assert.equal((await api('GET', '/crews/mine/messages', { token: loner.token })).status, 409);
  });

  test('a check-in posts a note in the crew chat', async () => {
    const crew = await newCrew('Noted');
    const event = await createEvent({ checkinCode: 'NOTE' });
    assert.equal((await api('POST', `/events/${event.id}/checkin`, { token: crew.a.token, body: { code: 'note' } })).status, 200);
    const { messages } = (await api('GET', '/crews/mine/messages', { token: crew.b.token })).body;
    const note = messages.find((m) => m.kind === 'system');
    assert.match(note.text, /checked the crew in at Test workshop · \+50/);
    assert.equal(note.author, null);
  });
});

describe('swipe cards', () => {
  test('profile picture, cover photo and card settings show on the public profile', async () => {
    const me = await newUser();
    const other = await newUser();
    const avatar = await api('POST', '/users/me/avatar', { token: me.token, body: { photo: PIXEL } });
    assert.equal(avatar.status, 200, JSON.stringify(avatar.body));
    assert.match(avatar.body.user.avatar, /^\/api\/photos\/[0-9a-f]{24}$/);

    assert.equal((await api('PUT', '/users/me', { token: me.token, body: { cover: 'photo' } })).status, 400);
    const cover = await api('POST', '/users/me/cover', { token: me.token, body: { photo: PIXEL } });
    assert.equal(cover.body.user.cover, 'photo');
    const saved = await api('PUT', '/users/me', {
      token: me.token, body: { headline: 'Ship it 🚀', accent: 'teal', cardFields: ['skills', 'interests'] },
    });
    assert.equal(saved.status, 200, JSON.stringify(saved.body));

    const seen = (await api('GET', `/users/${me.id}`, { token: other.token })).body.user;
    assert.equal(seen.headline, 'Ship it 🚀');
    assert.equal(seen.accent, 'teal');
    assert.deepEqual(seen.cardFields, ['skills', 'interests']);
    assert.match(seen.coverUrl, /^\/api\/photos\//);

    // Replacing the picture deletes the old one.
    const oldUrl = avatar.body.user.avatar;
    await api('POST', '/users/me/avatar', { token: me.token, body: { photo: PIXEL } });
    assert.equal((await fetch(`http://127.0.0.1:${PORT}${oldUrl}`)).status, 404);
    assert.equal((await api('DELETE', '/users/me/avatar', { token: me.token })).body.user.avatar, '');
    assert.equal((await api('DELETE', '/users/me/cover', { token: me.token })).body.user.cover, 'dusk');
    assert.equal((await api('PUT', '/users/me', { token: me.token, body: { accent: 'neon' } })).status, 400);
  });

  test("someone's posts and activity", async () => {
    const crew = await newCrew('Busy Crew');
    await api('POST', '/posts', { token: crew.a.token, body: { text: 'First post' } });
    const event = await createEvent({ checkinCode: 'BUSY' });
    await api('POST', `/events/${event.id}/checkin`, { token: crew.a.token, body: { code: 'BUSY' } });

    const posts = (await api('GET', `/users/${crew.a.id}/posts`, { token: crew.b.token })).body.posts;
    assert.deepEqual(posts.map((p) => p.text), ['First post']);
    const { activity } = (await api('GET', `/users/${crew.a.id}/activity`, { token: crew.b.token })).body;
    const texts = activity.map((a) => a.text);
    assert.ok(texts.includes('Busy Crew checked in at Test workshop · +50'), texts.join(' | '));
    assert.ok(texts.includes('Posted “First post”'));
    assert.ok(texts.includes('Joined Busy Crew'));
    assert.equal(texts.at(-1), 'Matched with you');
  });
});

describe('chat attachments', () => {
  const DOC = `data:application/pdf;base64,${Buffer.from('%PDF-1.4 hello').toString('base64')}`;

  test('photos and documents; documents are crew-only', async () => {
    const crew = await newCrew('Sharers');
    const outsider = await newCrew('Outsiders');
    const photo = await api('POST', '/crews/mine/messages', { token: crew.a.token, body: { photo: PIXEL } });
    assert.equal(photo.status, 201, JSON.stringify(photo.body));
    assert.equal(photo.body.message.attachment.kind, 'photo');
    assert.equal(photo.body.message.text, '');

    const doc = await api('POST', '/crews/mine/messages', {
      token: crew.a.token, body: { text: 'Deck v1', file: { name: 'Pitch deck.pdf', data: DOC } },
    });
    const att = doc.body.message.attachment;
    assert.deepEqual([att.kind, att.name, att.type], ['file', 'Pitch deck.pdf', 'application/pdf']);

    const mine = await fetch(`http://127.0.0.1:${PORT}${att.url}`, { headers: { Authorization: `Bearer ${crew.b.token}` } });
    assert.equal(mine.status, 200);
    assert.equal(await mine.text(), '%PDF-1.4 hello');
    const theirs = await fetch(`http://127.0.0.1:${PORT}${att.url}`, { headers: { Authorization: `Bearer ${outsider.a.token}` } });
    assert.equal(theirs.status, 404);

    assert.equal((await api('POST', '/crews/mine/messages', { token: crew.a.token, body: {} })).status, 400);
    const exe = await api('POST', '/crews/mine/messages', {
      token: crew.a.token, body: { file: { name: 'x.exe', data: 'data:application/x-msdownload;base64,TVo=' } },
    });
    assert.equal(exe.status, 400);
  });
});

describe('sign-up checks and email verification', () => {
  // These run with email codes switched on (REQUIRE_EMAIL_VERIFICATION=true).
  before(() => { process.env.REQUIRE_EMAIL_VERIFICATION = 'true'; });
  after(() => { delete process.env.REQUIRE_EMAIL_VERIFICATION; });

  test('with codes off (the default), a new email account can use the app straight away', async () => {
    delete process.env.REQUIRE_EMAIL_VERIFICATION;
    const reg = await api('POST', '/auth/register', { body: { name: 'No Code', email: 'no.code@test.dev', password: 'secret123' } });
    process.env.REQUIRE_EMAIL_VERIFICATION = 'true';
    assert.equal(reg.status, 201);
    assert.deepEqual([reg.body.user.emailVerified, reg.body.devCode], [true, undefined]);
  });

  test('weak passwords, bad names and bad emails are refused with a reason', async () => {
    const cases = [
      [{ name: 'Ana Gomez', email: 'ana@test.dev', password: 'short1' }, 'password', 'Use at least 8 characters'],
      [{ name: 'Ana Gomez', email: 'ana@test.dev', password: 'lettersonly' }, 'password', 'Add at least one number'],
      [{ name: 'Ana Gomez', email: 'ana@test.dev', password: '12345678' }, 'password', 'Add at least one letter'],
      [{ name: 'A', email: 'ana@test.dev', password: 'secret123' }, 'name', 'Enter your full name'],
      [{ name: 'R2D2', email: 'ana@test.dev', password: 'secret123' }, 'name', 'Use letters only in your name'],
      [{ name: 'Ana Gomez', email: 'not-an-email', password: 'secret123' }, 'email', 'Enter a valid email address'],
    ];
    for (const [body, field, message] of cases) {
      const res = await api('POST', '/auth/register', { body });
      assert.equal(res.status, 400, JSON.stringify(body));
      assert.deepEqual(res.body.details.find((d) => d.field === field)?.message, message);
    }
  });

  test('a new account must verify its email before using the app', async () => {
    const reg = await api('POST', '/auth/register', { body: { name: 'Vera Fied', email: 'vera@test.dev', password: 'secret123' } });
    assert.equal(reg.status, 201);
    assert.equal(reg.body.user.emailVerified, false);
    assert.match(reg.body.devCode, /^\d{6}$/);
    const token = reg.body.token;

    assert.equal((await api('GET', '/deck', { token })).status, 403);
    assert.equal((await api('GET', '/auth/me', { token })).status, 200, 'you can still see yourself');

    const wrongCode = reg.body.devCode === '000000' ? '111111' : '000000';
    const wrong = await api('POST', '/auth/verify', { token, body: { code: wrongCode } });
    assert.deepEqual([wrong.status, wrong.body.error], [400, 'Wrong code. 4 tries left']);
    assert.equal((await api('POST', '/auth/verify', { token, body: { code: '12' } })).status, 400);

    // Asking again straight away is throttled.
    assert.equal((await api('POST', '/auth/resend', { token })).status, 429);

    const ok = await api('POST', '/auth/verify', { token, body: { code: reg.body.devCode } });
    assert.equal(ok.status, 200);
    assert.equal(ok.body.user.emailVerified, true);
    assert.equal((await api('GET', '/posts', { token })).status, 200);
  });

  test('five wrong passwords lock the account for a while', async () => {
    await newUser();
    const email = `tester${userCount}@test.dev`;
    for (let i = 0; i < 5; i++) {
      assert.equal((await api('POST', '/auth/login', { body: { email, password: 'wrong-pass1' } })).status, 401);
    }
    const locked = await api('POST', '/auth/login', { body: { email, password: 'secret123' } });
    assert.equal(locked.status, 429);
    assert.match(locked.body.error, /Too many wrong passwords/);
  });
});
