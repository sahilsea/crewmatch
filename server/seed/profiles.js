// Gives the demo students in MONGO_URI their richer bios and headlines.
// Run with `npm run seed:profiles`. Real users are never touched.
import 'dotenv/config';
import mongoose from 'mongoose';
import { refreshDemoProfiles } from './seed.js';

if (!process.env.MONGO_URI) {
  console.error('Set MONGO_URI first, e.g.  MONGO_URI="mongodb+srv://…" npm run seed:profiles');
  process.exit(1);
}
await mongoose.connect(process.env.MONGO_URI);
console.log(`Updated ${await refreshDemoProfiles()} demo profiles.`);
await mongoose.disconnect();
