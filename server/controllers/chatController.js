import mongoose from 'mongoose';
import Message from '../models/Message.js';
import Photo from '../models/Photo.js';
import FileDoc from '../models/File.js';
import { decodeDataUrl, photoUrl, FILE_TYPES } from '../utils/uploads.js';
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
  attachment: m.attachment?.kind
    ? {
        kind: m.attachment.kind,
        // Photos load like any picture; files need your token (GET /crews/mine/files/:id).
        url: m.attachment.kind === 'photo' ? photoUrl(m.attachment.item) : `/api/crews/mine/files/${m.attachment.item}`,
        name: m.attachment.name,
        type: m.attachment.type,
        size: m.attachment.size,
      }
    : null,
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

// POST /api/crews/mine/messages  { text?, photo? (data URL), file? { name, data (data URL) } }
export async function sendMessage(req, res) {
  const crew = crewOf(req.user);
  let attachment = null;
  if (req.body.photo) {
    const { type, data } = decodeDataUrl(req.body.photo, { what: 'Photos', maxMb: 3 });
    const photo = await Photo.create({ owner: req.user._id, type, data });
    attachment = { kind: 'photo', item: photo._id, name: 'Photo', type, size: data.length };
  } else if (req.body.file) {
    const { type, data } = decodeDataUrl(req.body.file.data, { types: FILE_TYPES, maxMb: 10, what: 'Files' });
    const file = await FileDoc.create({ owner: req.user._id, crew, name: req.body.file.name, type, size: data.length, data });
    attachment = { kind: 'file', item: file._id, name: file.name, type, size: data.length };
  }
  const message = await Message.create({ crew, author: req.user._id, text: req.body.text ?? '', attachment });
  await message.populate('author', 'name avatar');
  res.status(201).json({ message: messageView(message) });
}

// GET /api/crews/mine/files/:id — a document from your crew's chat. Members only.
export async function getFile(req, res) {
  const crew = crewOf(req.user);
  const file = mongoose.isValidObjectId(req.params.id) ? await FileDoc.findById(req.params.id) : null;
  if (!file || !file.crew.equals(crew)) throw new HttpError(404, 'File not found');
  res.set({
    'Content-Type': file.type,
    'Content-Length': file.size,
    'Content-Disposition': `attachment; filename*=UTF-8''${encodeURIComponent(file.name)}`,
    'Cache-Control': 'private, max-age=3600',
  });
  res.send(file.data);
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
