import mongoose from 'mongoose';

const { Schema } = mongoose;

export const POST_TAGS = ['update', 'looking', 'win'];

const commentSchema = new Schema(
  {
    author: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    text: { type: String, required: true, trim: true, maxlength: 300 },
  },
  { timestamps: { createdAt: true, updatedAt: false } }
);

// A post on the hackathon feed. Everyone signed in can read it.
const postSchema = new Schema(
  {
    author: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    // The author's crew when they posted, so old posts keep their context.
    crewName: { type: String, default: null },
    text: { type: String, required: true, trim: true, maxlength: 500 },
    tag: { type: String, enum: [...POST_TAGS, null], default: null },
    photo: { type: Schema.Types.ObjectId, ref: 'Photo', default: null },
    likes: [{ type: Schema.Types.ObjectId, ref: 'User' }],
    comments: [commentSchema],
  },
  { timestamps: true }
);

postSchema.index({ createdAt: -1 });

export default mongoose.model('Post', postSchema);
