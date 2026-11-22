import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';
import {
  OPTIONS, MAX_SUPERPOWERS, CARD_COVERS, CARD_ACCENTS, CARD_FIELDS, DEFAULT_CARD_FIELDS,
} from '../config/options.js';
import { emailCodesRequired } from '../utils/verification.js';

const { Schema } = mongoose;
const ref = { type: Schema.Types.ObjectId, ref: 'User' };

const userSchema = new Schema(
  {
    name: { type: String, required: true, trim: true, maxlength: 60 },
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    password: { type: String, required: true, minlength: 6, select: false },
    // Google's id for this person, once they've used "Continue with Google".
    // Left unset otherwise, so the sparse unique index skips them.
    googleId: { type: String, unique: true, sparse: true },
    // The short name in their profile link: crewmatch…/u/tara-fernandes.
    handle: { type: String, unique: true, sparse: true, lowercase: true, trim: true },
    avatar: { type: String, default: '' },
    bio: { type: String, default: '', maxlength: 280 },

    // The swipe card: a headline over a cover, and which details it shows.
    headline: { type: String, default: '', trim: true, maxlength: 80 },
    cover: { type: String, enum: CARD_COVERS, default: 'dusk' },
    coverPhoto: { type: Schema.Types.ObjectId, ref: 'Photo', default: null },
    accent: { type: String, enum: CARD_ACCENTS, default: 'crimson' },
    cardFields: { type: [{ type: String, enum: CARD_FIELDS }], default: () => [...DEFAULT_CARD_FIELDS] },

    // Profile chips. Empty until the user fills the profile form.
    role: { type: String, enum: OPTIONS.role },
    experienceLevel: { type: String, enum: OPTIONS.experienceLevel },
    schedule: { type: String, enum: OPTIONS.schedule },
    commitment: { type: String, enum: OPTIONS.commitment },
    communication: { type: String, enum: OPTIONS.communication },
    interests: [{ type: String, enum: OPTIONS.interests }],
    superpowers: {
      type: [{ type: String, enum: OPTIONS.superpowers }],
      validate: [(v) => v.length <= MAX_SUPERPOWERS, `At most ${MAX_SUPERPOWERS} superpowers`],
    },
    skills: [{ type: String, trim: true, maxlength: 30 }],
    profileComplete: { type: Boolean, default: false },

    swipedRight: [ref],
    swipedLeft: [ref],
    matches: [ref],
    crew: { type: Schema.Types.ObjectId, ref: 'Crew', default: null },

    // Email verification: a 6-digit code, stored hashed, valid for 15 minutes.
    emailVerified: { type: Boolean, default: false },
    verifyCodeHash: { type: String, default: null, select: false },
    verifyCodeExpires: { type: Date, default: null, select: false },
    verifyCodeSentAt: { type: Date, default: null, select: false },
    verifyAttempts: { type: Number, default: 0, select: false },

    isAdmin: { type: Boolean, default: false },
    // Seed users only: they like you back, so the demo always produces matches.
    autoLike: { type: Boolean, default: false },
  },
  { timestamps: true }
);

userSchema.pre('save', async function () {
  if (!this.handle && this.name) this.handle = await this.constructor.freeHandle(this.name, this._id);
  if (this.isModified('password')) {
    this.password = await bcrypt.hash(this.password, 10);
  }
});

userSchema.methods.checkPassword = function (plain) {
  return bcrypt.compare(plain, this.password);
};

// Fields anyone can see on a swipe card.
const PUBLIC_FIELDS = [
  'name', 'avatar', 'bio', 'role', 'experienceLevel', 'schedule', 'commitment',
  'communication', 'interests', 'superpowers', 'skills', 'headline', 'cover', 'accent', 'cardFields', 'handle',
];

// "Tara Fernandes" -> "tara-fernandes". Letters and digits only, dashes between words.
export const slugify = (name) =>
  name.toLowerCase().normalize('NFKD').replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 30) || 'student';

// Picks a free handle: the name, then name-2, name-3…
userSchema.statics.freeHandle = async function (name, selfId = null) {
  const base = slugify(name);
  for (let n = 1; ; n++) {
    const handle = n === 1 ? base : `${base}-${n}`;
    const taken = await this.exists({ handle, ...(selfId && { _id: { $ne: selfId } }) });
    if (!taken) return handle;
  }
};

// Gives a handle to everyone who has none (accounts from before handles existed).
userSchema.statics.backfillHandles = async function () {
  const missing = await this.find({ handle: { $in: [null, undefined] } }, 'name');
  for (const u of missing) {
    await this.updateOne({ _id: u._id }, { $set: { handle: await this.freeHandle(u.name, u._id) } });
  }
  return missing.length;
};

userSchema.methods.toPublic = function () {
  const out = { id: this._id.toString() };
  for (const f of PUBLIC_FIELDS) out[f] = this[f];
  out.coverUrl = this.coverPhoto ? `/api/photos/${this.coverPhoto}` : null;
  return out;
};

// What a signed-in user sees about themselves.
userSchema.methods.toSelf = function () {
  return {
    ...this.toPublic(),
    email: this.email,
    profileComplete: this.profileComplete,
    crewId: this.crew ? this.crew.toString() : null,
    // With email codes off, nobody is held at the verify screen.
    emailVerified: this.emailVerified || !emailCodesRequired(),
    isAdmin: this.isAdmin,
    matchCount: this.matches.length,
  };
};

userSchema.statics.PUBLIC_FIELDS = PUBLIC_FIELDS;

export default mongoose.model('User', userSchema);
