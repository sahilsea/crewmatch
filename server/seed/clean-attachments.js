// Frees database space: deletes every photo and document ever sent in a crew
// chat (the chat now takes text only). The messages themselves stay.
// Run with `npm run clean:attachments`. Safe to run more than once.
import 'dotenv/config';
import mongoose from 'mongoose';

if (!process.env.MONGO_URI) {
  console.error('Set MONGO_URI first, e.g.  MONGO_URI="mongodb+srv://…" npm run clean:attachments');
  process.exit(1);
}
await mongoose.connect(process.env.MONGO_URI);
const db = mongoose.connection.db;
const messages = db.collection('messages');

const withPhotos = await messages.find({ 'attachment.kind': 'photo' }, { projection: { 'attachment.item': 1 } }).toArray();
const photos = await db.collection('photos').deleteMany({ _id: { $in: withPhotos.map((m) => m.attachment.item) } });
const files = await db.collection('files').deleteMany({});
// A message that was only an attachment has no text left, so it goes too.
const empty = await messages.deleteMany({ attachment: { $exists: true }, text: '' });
const cleared = await messages.updateMany({ attachment: { $exists: true } }, { $unset: { attachment: '' } });
try {
  await db.collection('files').drop();
} catch {
  // Already gone.
}

console.log(`Deleted ${photos.deletedCount} chat photos and ${files.deletedCount} documents.`);
console.log(`Removed ${empty.deletedCount} attachment-only messages; ${cleared.modifiedCount} others keep their text.`);
await mongoose.disconnect();
