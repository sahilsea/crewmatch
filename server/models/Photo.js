import mongoose from 'mongoose';

const { Schema } = mongoose;

// An uploaded image, kept in the database so it works the same with the
// in-memory dev database and with Atlas. Served by GET /api/photos/:id.
const photoSchema = new Schema(
  {
    owner: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    type: { type: String, required: true },
    data: { type: Buffer, required: true },
  },
  { timestamps: { createdAt: true, updatedAt: false } }
);

export default mongoose.model('Photo', photoSchema);
