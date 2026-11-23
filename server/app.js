import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import routes from './routes/index.js';
import { notFound, errorHandler } from './middleware/error.js';

const app = express();

const allowed = (process.env.CLIENT_URLS ?? 'http://localhost:5173')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);
// Outside production, any local port too: extra Vite ports and the Flutter web build.
const localDev = process.env.NODE_ENV !== 'production';
const LOCALHOST = /^http:\/\/(localhost|127\.0\.0\.1):\d+$/;

app.use(helmet());
// Browsers are limited to CLIENT_URLS. Requests with no Origin (the Flutter app, curl) pass through.
app.use(cors({
  origin: (origin, cb) => cb(null, !origin || allowed.includes(origin) || (localDev && LOCALHOST.test(origin))),
  // Browsers check permission (OPTIONS) before each call; let them remember it
  // for 2 hours (Chrome's maximum) instead of asking every time.
  maxAge: 7200,
}));
// Posts may carry a photo as a data URL; everything else stays small.
app.use('/api/posts', express.json({ limit: '5mb' }));
app.use('/api/users/me', express.json({ limit: '5mb' }));
app.use(express.json({ limit: '100kb' }));
if (process.env.NODE_ENV !== 'test') app.use(morgan('dev'));

app.get('/', (req, res) => res.json({ name: 'CrewMatch API', docs: 'See server/README.md' }));
app.use('/api', routes);

app.use(notFound);
app.use(errorHandler);

export default app;
