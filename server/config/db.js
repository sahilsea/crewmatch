import { mkdir } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import mongoose from 'mongoose';

const SERVER_DIR = fileURLToPath(new URL('..', import.meta.url));
let memoryServer;

// Connects to MONGO_URI. With no MONGO_URI outside production, starts a local MongoDB
// so the API runs with zero setup:
// - by default in memory, fresh and seeded on every start;
// - with LOCAL_DB_DIR (relative to server/), on disk, so data survives restarts.
//   It is seeded only while it has no users.
export async function connectDB() {
  let uri = process.env.MONGO_URI;
  const localDir = process.env.LOCAL_DB_DIR;

  if (!uri) {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('MONGO_URI is required in production');
    }
    const { MongoMemoryServer } = await import('mongodb-memory-server');
    if (localDir) {
      const dbPath = path.resolve(SERVER_DIR, localDir);
      await mkdir(dbPath, { recursive: true });
      memoryServer = await MongoMemoryServer.create({ instance: { dbPath, storageEngine: 'wiredTiger' } });
      console.warn(`MONGO_URI not set: using a local database in ${dbPath} (kept between restarts)`);
    } else {
      memoryServer = await MongoMemoryServer.create();
      console.warn('MONGO_URI not set: using an in-memory database (data resets on restart)');
    }
    uri = memoryServer.getUri('crewmatch');
  }

  await mongoose.connect(uri);
  console.log(`MongoDB connected: ${mongoose.connection.host}/${mongoose.connection.name}`);

  // A fresh in-memory database always needs the demo data; a LOCAL_DB_DIR one only until it has users.
  if (memoryServer) {
    const users = localDir ? await mongoose.connection.db.collection('users').estimatedDocumentCount() : 0;
    if (users === 0) {
      const { seedDatabase } = await import('../seed/seed.js');
      await seedDatabase();
    }
  }

  // Profile links need a handle; older accounts get one on the first start.
  const { default: User } = await import('../models/User.js');
  const filled = await User.backfillHandles();
  if (filled && process.env.NODE_ENV !== 'test') console.log(`Gave ${filled} accounts a profile handle`);
}

export async function disconnectDB() {
  await mongoose.disconnect();
  if (memoryServer) await memoryServer.stop();
}
