import { HttpError } from '../middleware/error.js';

export const IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp'];

// Documents a crew can share in its chat.
export const FILE_TYPES = [
  'application/pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'application/vnd.ms-powerpoint',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'text/plain',
  'text/csv',
  'application/zip',
  ...IMAGE_TYPES,
];

const MB = 1024 * 1024;

// "data:<type>;base64,<data>" → { type, data }, checked against the allowed
// types and size. The app sends files this way so the API stays plain JSON.
export function decodeDataUrl(dataUrl, { types = IMAGE_TYPES, maxMb = 3, what = 'Photos' } = {}) {
  const match = /^data:([\w.+-]+\/[\w.+-]+);base64,([A-Za-z0-9+/=\s]+)$/.exec(dataUrl ?? '');
  if (!match) throw new HttpError(400, `${what} must be sent as a data URL`);
  const type = match[1].toLowerCase();
  if (!types.includes(type)) {
    throw new HttpError(400, types === IMAGE_TYPES ? `${what} must be JPEG, PNG or WebP` : 'That file type isn’t supported');
  }
  const data = Buffer.from(match[2], 'base64');
  if (data.length > maxMb * MB) throw new HttpError(413, `${what} can be up to ${maxMb} MB`);
  return { type, data };
}

// "/api/photos/<id>" for a stored photo id, or null.
export const photoUrl = (id) => (id ? `/api/photos/${id}` : null);

// The photo id inside one of our own photo URLs, so a replaced picture can be deleted.
export function ownPhotoId(url) {
  const match = /^\/api\/photos\/([0-9a-f]{24})$/.exec(url ?? '');
  return match ? match[1] : null;
}
