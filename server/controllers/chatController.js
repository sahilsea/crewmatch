import Message from '../models/Message.js';
import { HttpError } from '../middleware/error.js';

const LIMIT = 100;

function crewOf(user) {
  if (!user.crew) throw new HttpError(409, 'Join or create a crew first');
  return user.crew;
}

const messageView = (m) => ({
  id: m.id,
  kind: m.kind,
  text: m.text,
  author: m.author ? { id: m.author.id, name: m.author.name, avatar: m.author.avatar } : null,
  createdAt: m.createdAt,
});

// GET /api/crews/mine/messages?after=<ISO date>
// Without `after`: the latest 100, oldest first. With it: only newer ones,
// which is what the app polls for while the chat is open.
export async function listMessages(req, res) {
  const crew = crewOf(req.user);
  const after = req.query.after ? new Date(req.query.after) : null;
  const filter = { crew };
  if (after && !Number.isNaN(after.getTime())) filter.createdAt = { $gt: after };
  const messages = await Message.find(filter).sort({ createdAt: -1 }).limit(LIMIT).populate('author', 'name avatar');
  res.json({ messages: messages.reverse().map(messageView) });
}

// POST /api/crews/mine/messages  { text }
export async function sendMessage(req, res) {
  const crew = crewOf(req.user);
  const message = await Message.create({ crew, author: req.user._id, text: req.body.text });
  await message.populate('author', 'name avatar');
  res.status(201).json({ message: messageView(message) });
}

// A line from the app itself ("Tara checked the crew in…"). Never throws:
// a chat note must not break the action that caused it.
export async function postSystemMessage(crewId, text) {
  try {
    await Message.create({ crew: crewId, kind: 'system', text });
  } catch (err) {
    console.warn('Could not post a crew chat note:', err.message);
  }
}
