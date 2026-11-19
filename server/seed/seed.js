// Fills the database with fake students, crews, events and challenges for the demo.
// Run with `npm run seed` (wipes users, crews and events first).
// Every seeded account uses the password below.
import 'dotenv/config';
import { fileURLToPath } from 'node:url';
import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';
import User from '../models/User.js';
import Crew from '../models/Crew.js';
import Event from '../models/Event.js';
import Post from '../models/Post.js';
import Message from '../models/Message.js';
import { OPTIONS, MAX_CREW_SIZE } from '../config/options.js';

export const SEED_PASSWORD = 'password123';

const NAMES = [
  'Aarav Sharma', 'Diya Patel', 'Rohan Iyer', 'Ananya Rao', 'Kabir Mehta', 'Ishita Nair',
  'Vivaan Reddy', 'Meera Pillai', 'Arjun Kulkarni', 'Saanvi Joshi', 'Aditya Menon', 'Priya Hegde',
  'Karthik Shetty', 'Nisha Verma', 'Rahul Bhat', 'Tara Fernandes', 'Siddharth Gowda', 'Zoya Khan',
  'Varun Krishnan', 'Pooja Desai', 'Nikhil Das', 'Riya Banerjee', 'Farhan Ali', 'Sneha Murthy',
  'Yash Agarwal', 'Lavanya Subramanian', 'Dev Malhotra', 'Aisha Siddiqui',
];

const SKILLS = {
  frontend: ['React', 'JavaScript', 'TypeScript', 'Tailwind', 'HTML/CSS', 'Next.js', 'Redux'],
  backend: ['Node.js', 'Express', 'MongoDB', 'PostgreSQL', 'Java', 'Spring Boot', 'Docker'],
  fullstack: ['React', 'Node.js', 'Express', 'MongoDB', 'TypeScript', 'Firebase', 'REST APIs'],
  designer: ['Figma', 'UI Design', 'Prototyping', 'Illustrator', 'User Research', 'Canva'],
  ml: ['Python', 'TensorFlow', 'PyTorch', 'Pandas', 'scikit-learn', 'NLP', 'OpenCV'],
  pm: ['Notion', 'Jira', 'Roadmapping', 'Presentations', 'Market Research', 'Agile'],
};

const BIOS = {
  frontend: 'I make interfaces that feel fast and look clean.',
  backend: 'APIs, databases and making sure nothing falls over at 2am.',
  fullstack: 'Happy anywhere in the stack, from schema to button.',
  designer: 'I turn rough ideas into screens people actually enjoy using.',
  ml: 'I like teaching models to do useful things with messy data.',
  pm: 'I keep the crew focused and I love a good pitch deck.',
};

// Small deterministic RNG so every seed run produces the same students.
function rng(seed) {
  let s = seed;
  return () => ((s = (s * 1664525 + 1013904223) % 4294967296) / 4294967296);
}

function buildStudents() {
  const rand = rng(42);
  const pick = (arr) => arr[Math.floor(rand() * arr.length)];
  const sample = (arr, n) => [...arr].sort(() => rand() - 0.5).slice(0, n);

  return NAMES.map((name, i) => {
    // Cycle roles so every role is well represented.
    const role = OPTIONS.role[i % OPTIONS.role.length];
    const superpowers = role === 'pm'
      ? ['pitching', pick(['project_management', 'research'])]
      : role === 'designer'
        ? ['ui_design', ...(rand() < 0.4 ? ['video_editing'] : [])]
        : rand() < 0.45 ? [pick(OPTIONS.superpowers)] : [];
    const [first, last] = name.toLowerCase().split(' ');

    return {
      name,
      email: `${first}.${last}@students.crewmatch.dev`,
      avatar: `https://api.dicebear.com/9.x/notionists/png?seed=${encodeURIComponent(name)}`,
      bio: BIOS[role],
      role,
      experienceLevel: pick(OPTIONS.experienceLevel),
      schedule: pick(OPTIONS.schedule),
      commitment: pick(OPTIONS.commitment),
      communication: pick(OPTIONS.communication),
      interests: sample(OPTIONS.interests, 1 + Math.floor(rand() * 3)),
      superpowers: [...new Set(superpowers)],
      skills: sample(SKILLS[role], 3 + Math.floor(rand() * 2)),
      profileComplete: true,
      // About half like you back, so swiping right on them makes a match.
      // Spread across every role (not i % 2, which lines up with the role cycle),
      // so whoever ranks top for you, some of them match quickly.
      autoLike: i % 4 === 0 || i % 4 === 3,
    };
  });
}

// Accounts for the live demo: sign in as one on web and the other on mobile,
// swipe right on each other, and the match appears on both.
const DEMO_USERS = [
  {
    name: 'Demo Web', email: 'web@crewmatch.dev', role: 'backend', experienceLevel: 'intermediate',
    schedule: 'night_owl', commitment: 'here_to_win', communication: 'chat',
    interests: ['ai', 'education'], superpowers: [], skills: ['Node.js', 'Express', 'MongoDB'],
    bio: 'Backend dev looking for a designer and a pitcher.', profileComplete: true,
  },
  {
    name: 'Demo Mobile', email: 'mobile@crewmatch.dev', role: 'designer', experienceLevel: 'intermediate',
    schedule: 'night_owl', commitment: 'here_to_win', communication: 'chat',
    interests: ['ai', 'health'], superpowers: ['ui_design', 'pitching'], skills: ['Figma', 'Flutter', 'Prototyping'],
    bio: 'Designer who can pitch. Need someone to build the backend.', profileComplete: true,
  },
  { name: 'CrewMatch Admin', email: 'admin@crewmatch.dev', isAdmin: true },
];

// Crews for the leaderboard, by student name. Only students without autoLike, so every
// instant match the demo accounts make is still free to join their crew.
const CREWS = [
  { key: 'night', name: 'Night Shift', members: ['Diya Patel', 'Saanvi Joshi', 'Vivaan Reddy', 'Ishita Nair'] },
  { key: 'pixel', name: 'Pixel Pushers', members: ['Riya Banerjee', 'Rohan Iyer'] },
  { key: 'null', name: 'Null Pointers', members: ['Nisha Verma', 'Varun Krishnan'] },
  { key: 'chai', name: 'Chai & Commit', members: ['Zoya Khan', 'Rahul Bhat'] },
  { key: 'gradient', name: 'Gradient Descent', members: ['Aditya Menon', 'Lavanya Subramanian'] },
  { key: 'merge', name: 'Merge Conflict', members: ['Farhan Ali', 'Dev Malhotra'] },
];

const MINUTE = 60 * 1000;
const HOUR = 60 * MINUTE;

// Every time is relative to when the seed runs, so the demo always has something live.
// Rounded to the quarter hour so the schedule looks like a real one.
function hoursFromNow(hours) {
  const t = new Date(Date.now() + hours * HOUR);
  t.setMinutes(Math.round(t.getMinutes() / 15) * 15, 0, 0);
  return t;
}

// A clock time `days` from today (0 = today), in the server's time zone.
function dayAt(days, hour, minute = 0) {
  const t = new Date();
  t.setDate(t.getDate() + days);
  t.setHours(hour, minute, 0, 0);
  return t;
}

// What each crew has done so far. `ago` is in minutes; `points` overrides the event's.
const done = (crew, ago, points) => ({ crew, status: 'completed', ago, points });
const sent = (crew, ago, url, note) => ({ crew, status: 'submitted', ago, url, note });
const going = (crew, ago, note) => ({ crew, status: 'joined', ago, note });

function buildEvents() {
  const quizNight = new Date(Math.max(hoursFromNow(4), dayAt(0, 21)));
  return [
    // Events: 1 ended earlier today, 2 live now, 3 upcoming.
    {
      kind: 'event', category: 'talk', title: 'Opening Keynote: Build for Your Campus',
      summary: 'Why the best hackathon ideas start with a problem you walk past every day.',
      details: 'A short welcome from the organisers, then a talk by two alumni who turned a hostel ' +
        'laundry tracker into a project used across three campuses. Q&A at the end.',
      location: 'Main Auditorium', startsAt: hoursFromNow(-3), endsAt: hoursFromNow(-1.5),
      points: 30, checkinCode: 'SPRK',
      entries: [done('night', 170), done('pixel', 166), done('null', 162), done('chai', 158),
        done('gradient', 154), going('merge', 240)],
    },
    {
      kind: 'event', category: 'workshop', title: 'Wireframes to Widgets Workshop',
      summary: 'Turn a paper sketch into a working mobile screen in 90 minutes.',
      details: 'Bring one laptop per crew. We start from hand-drawn wireframes, build the layout ' +
        'as reusable widgets and finish with a clickable prototype you can demo on a phone.',
      location: 'Lab 3, Block B', startsAt: hoursFromNow(-1), endsAt: hoursFromNow(1.5),
      points: 50, capacity: 12, checkinCode: 'WDGT',
      entries: [done('night', 45), done('null', 40), going('pixel', 120), going('gradient', 90)],
    },
    {
      kind: 'event', category: 'expo', title: 'Stall Hop: Expo Floor Walk',
      summary: 'Visit every project stall on the expo floor and collect the stamp at the end.',
      details: 'Walk the expo floor as a crew, talk to at least five teams about how they built ' +
        'their project, and check in at the help desk when you are done.',
      location: 'Expo Hall, Ground Floor', startsAt: hoursFromNow(-0.5), endsAt: hoursFromNow(2.5),
      points: 40, checkinCode: 'HALL',
      entries: [done('night', 15), going('chai', 60)],
    },
    {
      kind: 'event', category: 'talk', title: 'From Side Project to Startup',
      summary: 'Three founders on what changed when their weekend project got real users.',
      details: 'A panel with founders who started out at student hackathons, on finding first ' +
        'users, splitting work in a small team and knowing when to stop adding features.',
      location: 'Seminar Hall 2', startsAt: hoursFromNow(2.5), endsAt: hoursFromNow(3.5),
      points: 30, checkinCode: 'LNCH',
      entries: [going('night', 100), going('merge', 80), going('gradient', 30)],
    },
    {
      kind: 'event', category: 'social', title: 'Late-Night Tech Quiz',
      summary: 'Five rounds of tech trivia, buzzer finals and free chai for every crew.',
      details: 'Crews of up to four. Rounds on computing history, guess-the-error, keyboard ' +
        'shortcuts and campus trivia. Buzzer final for the top three crews.',
      location: 'Cafeteria Lawn', startsAt: quizNight, endsAt: new Date(quizNight.getTime() + 1.5 * HOUR),
      points: 60, capacity: 20, checkinCode: 'BUZZ',
      entries: [going('pixel', 70), going('null', 65), going('chai', 50)],
    },
    {
      kind: 'event', category: 'workshop', title: 'Ship a REST API in 90 Minutes',
      summary: 'Routes, validation and a database, deployed before lunch.',
      details: 'A hands-on session for backend beginners: design the endpoints, validate input, ' +
        'store data and put it online. Every crew leaves with a live URL.',
      location: 'Lab 1, Block A', startsAt: dayAt(1, 10), endsAt: dayAt(1, 11, 30),
      points: 50, capacity: 10, checkinCode: 'REST',
      entries: [going('gradient', 25)],
    },

    // Challenges: 1 ended, 4 open.
    {
      kind: 'challenge', category: 'design', title: 'Logo Dash',
      summary: 'Design a logo for your crew in under an hour.',
      details: 'Any tool, any style. Submit a link to the image. The best three get a podium bonus.',
      location: 'Online', startsAt: hoursFromNow(-5), endsAt: hoursFromNow(-2),
      points: 40,
      entries: [done('pixel', 110, 60), done('night', 100), done('chai', 95)],
    },
    {
      kind: 'challenge', category: 'build', title: 'Fix One Campus Problem',
      summary: 'Ship a working prototype that fixes one everyday campus annoyance.',
      details: 'Pick something real: the canteen queue, lost ID cards, finding a free classroom. ' +
        'Submit a link to a live demo or a repo with a short video.',
      location: 'Anywhere', startsAt: hoursFromNow(-2), endsAt: dayAt(1, 12),
      points: 150,
      entries: [
        sent('night', 10, 'https://code.example.com/night-shift/free-room-finder', 'Live demo link is in the README.'),
        sent('null', 5, 'https://null-pointers.example.com', null),
        going('pixel', 100), going('chai', 90), going('gradient', 80), going('merge', 70),
      ],
    },
    {
      kind: 'challenge', category: 'pitch', title: 'One-Minute Pitch',
      summary: 'Record a 60-second video pitching what your crew is building.',
      details: 'Problem, solution, demo moment, ask. Phone videos are fine. Upload anywhere ' +
        'that gives a shareable link.',
      location: 'Online', startsAt: hoursFromNow(-3), endsAt: hoursFromNow(5),
      points: 80,
      entries: [
        done('pixel', 60), done('night', 30),
        sent('merge', 20, 'https://drive.example.com/merge-conflict-pitch.mp4', 'Shot it in one take!'),
      ],
    },
    {
      kind: 'challenge', category: 'quiz', title: 'Bug Hunt Quiz',
      summary: 'Find the bug in 15 short code snippets. Submit your answer sheet.',
      details: 'JavaScript, Python and SQL snippets, each with exactly one bug. Answer as a crew ' +
        'and submit a link to your answer sheet.',
      location: 'Online', startsAt: hoursFromNow(-1.5), endsAt: hoursFromNow(3),
      points: 50,
      entries: [done('null', 35), done('gradient', 25), going('night', 80)],
    },
    {
      kind: 'challenge', category: 'design', title: 'Accessibility Makeover',
      summary: 'Take one screen of your app and make it work for everyone.',
      details: 'Fix contrast, labels, focus order and touch targets on one screen. Submit ' +
        'before and after screenshots with a line on each change.',
      location: 'Anywhere', startsAt: hoursFromNow(-1), endsAt: dayAt(1, 16),
      points: 70,
      entries: [going('pixel', 50), going('chai', 40, 'The link asks for sign-in. Share it with view access and send it again.')],
    },
  ];
}

// Seeded students only; the demo accounts stay crew-less so the demo can show forming a crew.
async function seedCrews() {
  const students = await User.find({ name: { $in: CREWS.flatMap((c) => c.members) } }, 'name');
  const idOf = new Map(students.map((u) => [u.name, u._id]));
  const crews = await Crew.insertMany(CREWS.map((c) => {
    const members = c.members.slice(0, MAX_CREW_SIZE).map((name) => idOf.get(name));
    return { name: c.name, createdBy: members[0], members };
  }));

  // Crewmates matched each other first, the same as in the app.
  await User.bulkWrite(crews.flatMap((crew) => crew.members.map((id) => {
    const others = crew.members.filter((m) => !m.equals(id));
    return {
      updateOne: {
        filter: { _id: id },
        update: { $set: { crew: crew._id }, $addToSet: { matches: { $each: others }, swipedRight: { $each: others } } },
      },
    };
  })));
  return Object.fromEntries(CREWS.map((c, i) => [c.key, crews[i]._id]));
}

async function seedEvents(crewIds) {
  const now = Date.now();
  const admin = await User.findOne({ isAdmin: true }, '_id');
  const docs = buildEvents().map((e) => ({
    ...e,
    createdBy: admin._id,
    entries: e.entries.map(({ crew, status, ago, points, url, note }) => {
      const at = new Date(now - ago * MINUTE);
      return {
        crew: crewIds[crew],
        status,
        submissionUrl: url ?? null,
        note: note ?? null,
        pointsAwarded: status === 'completed' ? points ?? e.points : 0,
        joinedAt: status === 'completed' ? new Date(at - 30 * MINUTE) : at,
        completedAt: status === 'completed' ? at : null,
      };
    }),
  }));
  return Event.create(docs);
}

// Feed posts: [author, crew key or null, minutes ago, tag, text, likers, comments [author, text]].
const POSTS = [
  ['Diya Patel', 'night', 12, 'win', 'We just demoed our campus marketplace to the judges 🚀 Come try it at Table 14!', 9,
    [['Riya Banerjee', 'The checkout flow is so smooth 🔥'], ['Nisha Verma', 'Coming over after the quiz!']]],
  ['Riya Banerjee', 'pixel', 40, 'looking', 'Need a backend dev who loves Node. We have a designer and a pitcher already. DM me!', 4,
    [['Farhan Ali', 'What are you building?']]],
  ['Nisha Verma', 'null', 65, null, 'The check-in code hunt on the expo floor was pure chaos 😂', 7,
    [['Zoya Khan', 'We found it in 2 minutes 😎']]],
  ['Zoya Khan', 'chai', 110, 'update', 'Chai count: 14. Commits: 61. Sleep: optional.', 12, []],
  ['Aditya Menon', 'gradient', 190, 'update', 'Our model finally beats the baseline. Pitch practice at 6 in Lab 2 if anyone wants feedback.', 5,
    [['Saanvi Joshi', 'We’ll be there!']]],
];

// A short history in each seeded crew's chat. [author index, minutes ago, text]
const CHAT = [
  [0, 95, 'Who’s taking the demo video?'],
  [1, 92, 'I can, after lunch'],
  [0, 60, 'Stall Hop code is up near the expo hall 👀'],
  [1, 58, 'On my way'],
];

async function seedFeed(crewIds) {
  const people = await User.find({ name: { $in: CREWS.flatMap((c) => c.members) } }, 'name');
  const idOf = new Map(people.map((u) => [u.name, u._id]));
  const crewName = Object.fromEntries(CREWS.map((c) => [c.key, c.name]));
  const now = Date.now();
  const ids = people.map((u) => u._id);
  await Post.insertMany(POSTS.map(([author, crew, ago, tag, text, likes, comments]) => ({
    author: idOf.get(author),
    crewName: crew ? crewName[crew] : null,
    text,
    tag,
    likes: ids.filter((id) => !id.equals(idOf.get(author))).slice(0, likes),
    comments: comments.map(([who, t], i) => ({ author: idOf.get(who), text: t, createdAt: new Date(now - (ago - 5 - i) * MINUTE) })),
    createdAt: new Date(now - ago * MINUTE),
    updatedAt: new Date(now - ago * MINUTE),
  })));

  const crews = CREWS.map((c) => ({ id: crewIds[c.key], members: c.members.map((n) => idOf.get(n)) }));
  await Message.insertMany(crews.flatMap((crew) => CHAT.map(([who, ago, text]) => ({
    crew: crew.id,
    author: crew.members[who % crew.members.length],
    text,
    createdAt: new Date(now - ago * MINUTE),
  }))));
}

export async function seedDatabase() {
  await Promise.all([User.deleteMany({}), Crew.deleteMany({}), Event.deleteMany({}), Post.deleteMany({}), Message.deleteMany({})]);

  // Insert with one shared hash: insertMany skips the save hook, and hashing 30 times is slow.
  const password = await bcrypt.hash(SEED_PASSWORD, 10);
  const docs = [...DEMO_USERS, ...buildStudents()].map((u) => ({
    avatar: `https://api.dicebear.com/9.x/notionists/png?seed=${encodeURIComponent(u.name)}`,
    ...u,
    password,
  }));
  await User.insertMany(docs);

  const crewIds = await seedCrews();
  const events = await seedEvents(crewIds);
  await seedFeed(crewIds);

  console.log(`Seeded ${docs.length} users. Every seeded account's password: ${SEED_PASSWORD}`);
  console.log('Demo logins: web@crewmatch.dev, mobile@crewmatch.dev, admin@crewmatch.dev');
  const challenges = events.filter((e) => e.kind === 'challenge').length;
  console.log(`Seeded ${CREWS.length} crews, ${events.length - challenges} events and ${challenges} challenges. Check-in codes:`);
  for (const e of events.filter((ev) => ev.kind === 'event')) {
    console.log(`  ${e.checkinCode}  ${e.title} (${e.state})`);
  }
}

// `node seed/seed.js` runs it against MONGO_URI.
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  if (!process.env.MONGO_URI) {
    console.error('Set MONGO_URI in server/.env first. (Without it, `npm run dev` seeds an in-memory DB on its own.)');
    process.exit(1);
  }
  await mongoose.connect(process.env.MONGO_URI);
  await seedDatabase();
  await mongoose.disconnect();
}
