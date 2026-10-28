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
    body: { name: `Tester ${userCount}`, email: `tester${userCount}@test.dev`, password: 'secret123' },
  });
  assert.equal(status, 201);
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
    const events = (await api('GET', '/events?kind=event', { token: web })).body.events;
    const challenges = (await api('GET', '/events?kind=challenge', { token: web })).body.events;
    assert.equal(events.length, 6);
    assert.deepEqual([count(events, 'ended'), count(events, 'live'), count(events, 'upcoming')], [1, 2, 3]);
    assert.equal(challenges.length, 5);
    assert.deepEqual([count(challenges, 'ended'), count(challenges, 'live')], [1, 4]);
    assert.ok(events.every((e) => e.kind === 'event') && challenges.every((e) => e.kind === 'challenge'));
  });

  test('every seeded event has a check-in code, challenges none', async () => {
    const { events } = (await api('GET', '/admin/events', { token: admin })).body;
    for (const e of events) {
      if (e.kind === 'event') assert.match(e.checkinCode, /^[A-Z2-9]{4}$/);
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
    assert.equal(stats.events, 6);
    assert.equal(stats.challenges, 5);
    assert.ok(stats.pendingSubmissions >= 2);
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
    assert.equal(after.events + after.challenges, await Event.countDocuments());
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
