import mongoose from 'mongoose';

let memoryServer;

// Connects to MONGO_URI. With no MONGO_URI outside production, starts a
// throwaway in-memory MongoDB and seeds it, so the API runs with zero setup.
export async function connectDB() {
  let uri = process.env.MONGO_URI;

  if (!uri) {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('MONGO_URI is required in production');
    }
    const { MongoMemoryServer } = await import('mongodb-memory-server');
    memoryServer = await MongoMemoryServer.create();
    uri = memoryServer.getUri('crewmatch');
    console.warn('MONGO_URI not set: using an in-memory database (data resets on restart)');
  }

  await mongoose.connect(uri);
  console.log(`MongoDB connected: ${mongoose.connection.host}/${mongoose.connection.name}`);

  if (memoryServer) {
    const { seedDatabase } = await import('../seed/seed.js');
    await seedDatabase();
  }
}

export async function disconnectDB() {
  await mongoose.disconnect();
  if (memoryServer) await memoryServer.stop();
}
