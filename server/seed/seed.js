// Fills the database with fake students for the demo.
// Run with `npm run seed` (wipes users and crews first).
// Every seeded account uses the password below.
import 'dotenv/config';
import { fileURLToPath } from 'node:url';
import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';
import User from '../models/User.js';
import Crew from '../models/Crew.js';
import { OPTIONS } from '../config/options.js';

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

export async function seedDatabase() {
  await Promise.all([User.deleteMany({}), Crew.deleteMany({})]);

  // Insert with one shared hash: insertMany skips the save hook, and hashing 30 times is slow.
  const password = await bcrypt.hash(SEED_PASSWORD, 10);
  const docs = [...DEMO_USERS, ...buildStudents()].map((u) => ({
    avatar: `https://api.dicebear.com/9.x/notionists/png?seed=${encodeURIComponent(u.name)}`,
    ...u,
    password,
  }));
  await User.insertMany(docs);

  console.log(`Seeded ${docs.length} users. Every seeded account's password: ${SEED_PASSWORD}`);
  console.log('Demo logins: web@crewmatch.dev, mobile@crewmatch.dev, admin@crewmatch.dev');
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
