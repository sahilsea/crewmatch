import mongoose from 'mongoose';

const { Schema } = mongoose;

export const REQUEST_SOURCES = ['discover', 'search', 'profile', 'link', 'qr'];
export const REQUEST_STATUSES = ['pending', 'accepted', 'declined', 'withdrawn'];

// "Request to team up": one person asking another to match. Accepting makes a
// match, the same as two right swipes. A right swipe in Discover is a request too.
const teamRequestSchema = new Schema(
  {
    from: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    to: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    note: { type: String, default: '', trim: true, maxlength: 140 },
    // How the sender found them, shown on the request.
    source: { type: String, enum: REQUEST_SOURCES, default: 'profile' },
    status: { type: String, enum: REQUEST_STATUSES, default: 'pending' },
  },
  { timestamps: true }
);

teamRequestSchema.index({ to: 1, status: 1, createdAt: -1 });
teamRequestSchema.index({ from: 1, to: 1 });

export default mongoose.model('TeamRequest', teamRequestSchema);
