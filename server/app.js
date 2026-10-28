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

app.use(helmet());
// Browsers are limited to CLIENT_URLS. Requests with no Origin (the Flutter app, curl) pass through.
app.use(cors({ origin: (origin, cb) => cb(null, !origin || allowed.includes(origin)) }));
app.use(express.json({ limit: '100kb' }));
if (process.env.NODE_ENV !== 'test') app.use(morgan('dev'));

app.get('/', (req, res) => res.json({ name: 'CrewMatch API', docs: 'See server/README.md' }));
app.use('/api', routes);

app.use(notFound);
app.use(errorHandler);

export default app;
