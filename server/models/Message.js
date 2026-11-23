import mongoose from 'mongoose';

const { Schema } = mongoose;

// One line in a crew's private chat. System lines ("Tara checked the crew in
// at Stall Hop · +40") have no author.
const messageSchema = new Schema(
  {
    crew: { type: Schema.Types.ObjectId, ref: 'Crew', required: true, index: true },
    author: { type: Schema.Types.ObjectId, ref: 'User', default: null },
    kind: { type: String, enum: ['text', 'system'], default: 'text' },
    text: { type: String, default: '', trim: true, maxlength: 1000 },
  },
  { timestamps: { createdAt: true, updatedAt: false } }
);

messageSchema.index({ crew: 1, createdAt: 1 });

export default mongoose.model('Message', messageSchema);
