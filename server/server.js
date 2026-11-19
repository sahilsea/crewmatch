import 'dotenv/config';
import app from './app.js';
import { connectDB, disconnectDB } from './config/db.js';

if (!process.env.JWT_SECRET) {
  console.error('JWT_SECRET is missing. Copy .env.example to server/.env and set it.');
  process.exit(1);
}

const PORT = Number(process.env.PORT) || 5050;

await connectDB();

// 0.0.0.0 so a phone or emulator on the same network can reach the API.
app.listen(PORT, '0.0.0.0', () => {
  console.log(`CrewMatch API on http://localhost:${PORT}/api`);
});

// Stop the database cleanly on Ctrl+C or a --watch restart, so a LOCAL_DB_DIR
// database is flushed and unlocked before the next start opens it.
for (const signal of ['SIGINT', 'SIGTERM']) {
  process.once(signal, async () => {
    await disconnectDB();
    process.exit(0);
  });
}
