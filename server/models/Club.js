import mongoose from 'mongoose';

const { Schema } = mongoose;

export const CLUB_CATEGORIES = ['tech', 'design', 'business', 'culture', 'sports'];
export const CLUB_TONES = ['crimson', 'navy', 'gold', 'cream'];
// A student can be in this many clubs at once.
export const MAX_CLUBS = 5;

// A campus club. Organisers create them; students join (it shows on their card);
// club leads can post events for the club.
const clubSchema = new Schema(
  {
    name: { type: String, required: true, trim: true, maxlength: 40 },
    // Two or three letters for its logo tile, e.g. "CC".
    short: { type: String, required: true, trim: true, uppercase: true, maxlength: 3 },
    category: { type: String, enum: CLUB_CATEGORIES, default: 'tech' },
    tone: { type: String, enum: CLUB_TONES, default: 'navy' },
    description: { type: String, default: '', trim: true, maxlength: 140 },
    // Verified clubs' events count for points without an organiser's review.
    verified: { type: Boolean, default: false },
    // Emails of students who can post events for the club.
    leads: [{ type: String, lowercase: true, trim: true }],
    // Sample clubs from the seed scripts, shown with a Demo badge.
    demo: { type: Boolean, default: false },
  },
  { timestamps: true }
);

clubSchema.index({ name: 1 }, { unique: true, collation: { locale: 'en', strength: 2 } });

// The small badge shown on cards, profiles and events.
clubSchema.methods.toTag = function () {
  return { id: this.id, name: this.name, short: this.short, tone: this.tone, verified: this.verified, demo: this.demo };
};

clubSchema.methods.toPublic = function () {
  return { ...this.toTag(), category: this.category, description: this.description };
};

export default mongoose.model('Club', clubSchema);
