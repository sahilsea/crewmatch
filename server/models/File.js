import mongoose from 'mongoose';

const { Schema } = mongoose;

// A document shared in a crew chat. Only that crew can download it
// (GET /api/crews/mine/files/:id).
const fileSchema = new Schema(
  {
    owner: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    crew: { type: Schema.Types.ObjectId, ref: 'Crew', required: true, index: true },
    name: { type: String, required: true, trim: true, maxlength: 120 },
    type: { type: String, required: true },
    size: { type: Number, required: true },
    data: { type: Buffer, required: true },
  },
  { timestamps: { createdAt: true, updatedAt: false } }
);

export default mongoose.model('File', fileSchema);
