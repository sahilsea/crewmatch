import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';
import { OPTIONS, MAX_SUPERPOWERS } from '../config/options.js';

const { Schema } = mongoose;
const ref = { type: Schema.Types.ObjectId, ref: 'User' };

const userSchema = new Schema(
  {
    name: { type: String, required: true, trim: true, maxlength: 60 },
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    password: { type: String, required: true, minlength: 6, select: false },
    avatar: { type: String, default: '' },
    bio: { type: String, default: '', maxlength: 280 },

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

    isAdmin: { type: Boolean, default: false },
    // Seed users only: they like you back, so the demo always produces matches.
    autoLike: { type: Boolean, default: false },
  },
  { timestamps: true }
);

userSchema.pre('save', async function () {
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
  'communication', 'interests', 'superpowers', 'skills',
];

userSchema.methods.toPublic = function () {
  const out = { id: this._id.toString() };
  for (const f of PUBLIC_FIELDS) out[f] = this[f];
  return out;
};

// What a signed-in user sees about themselves.
userSchema.methods.toSelf = function () {
  return {
    ...this.toPublic(),
    email: this.email,
    profileComplete: this.profileComplete,
    crewId: this.crew ? this.crew.toString() : null,
    isAdmin: this.isAdmin,
    matchCount: this.matches.length,
  };
};

userSchema.statics.PUBLIC_FIELDS = PUBLIC_FIELDS;

export default mongoose.model('User', userSchema);
