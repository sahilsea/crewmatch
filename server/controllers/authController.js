import User from '../models/User.js';
import { signToken } from '../middleware/auth.js';
import { HttpError } from '../middleware/error.js';

const avatarFor = (name) => `https://api.dicebear.com/9.x/notionists/png?seed=${encodeURIComponent(name)}`;

// POST /api/auth/register
export async function register(req, res) {
  const { name, email, password } = req.body;
  if (await User.exists({ email })) throw new HttpError(409, 'An account with that email already exists');

  const user = await User.create({ name, email, password, avatar: avatarFor(name) });
  res.status(201).json({ token: signToken(user), user: user.toSelf() });
}

// POST /api/auth/login
export async function login(req, res) {
  const { email, password } = req.body;
  const user = await User.findOne({ email }).select('+password');
  if (!user || !(await user.checkPassword(password))) {
    throw new HttpError(401, 'Wrong email or password');
  }
  res.json({ token: signToken(user), user: user.toSelf() });
}

// GET /api/auth/me
export function me(req, res) {
  res.json({ user: req.user.toSelf() });
}
