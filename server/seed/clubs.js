// Adds the mock clubs to the database in MONGO_URI without erasing anything.
// Run with `npm run seed:clubs`. Running it again only adds what's missing.
import 'dotenv/config';
import mongoose from 'mongoose';
import { addMockClubs } from './seed.js';

if (!process.env.MONGO_URI) {
  console.error('Set MONGO_URI first, e.g.  MONGO_URI="mongodb+srv://…" npm run seed:clubs');
  process.exit(1);
}
await mongoose.connect(process.env.MONGO_URI);
const result = await addMockClubs();
console.log(`Created ${result.created.length} clubs${result.created.length ? `: ${result.created.join(', ')}` : ''}.`);
if (result.skipped) console.log(`Skipped ${result.skipped} that already existed.`);
console.log(`${result.studentsJoined} demo students joined a club; ${result.codingEvents} Coding Club events added.`);
await mongoose.disconnect();
