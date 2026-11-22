import { randomInt } from 'node:crypto';
import mongoose from 'mongoose';
import {
  EVENT_KINDS, EVENT_CATEGORIES, EVENT_STATUSES, ENTRY_STATUSES, CHECKIN_CODE_CHARS, MAX_ASK_POINTS,
} from '../config/options.js';

const { Schema } = mongoose;

// One crew's progress on an event or challenge. Crews take part, not single users.
const entrySchema = new Schema(
  {
    crew: { type: Schema.Types.ObjectId, ref: 'Crew', required: true },
    status: { type: String, enum: ENTRY_STATUSES, default: 'joined' },
    submissionUrl: { type: String, default: null },
    // The crew's note with a submission, or the admin's reason for rejecting it.
    note: { type: String, default: null, maxlength: 280 },
    pointsAwarded: { type: Number, default: 0, min: 0 },
    joinedAt: { type: Date, default: Date.now },
    completedAt: { type: Date, default: null },
  },
  { _id: false }
);

// Events (workshops, talks...) and challenges (build, design...) share one model.
const eventSchema = new Schema(
  {
    kind: { type: String, enum: EVENT_KINDS, required: true },
    title: { type: String, required: true, trim: true, maxlength: 80 },
    summary: { type: String, required: true, trim: true, maxlength: 140 },
    details: { type: String, default: '', trim: true, maxlength: 2000 },
    category: { type: String, enum: Object.values(EVENT_CATEGORIES).flat(), required: true },
    // A venue for events, "Anywhere" or "Online" for challenges.
    location: { type: String, default: '', trim: true, maxlength: 80 },
    // For challenges these are "opens" and "deadline".
    startsAt: { type: Date, required: true },
    endsAt: { type: Date, required: true },
    points: { type: Number, required: true, min: 0, max: 1000 },
    // Maximum crews, null for unlimited.
    capacity: { type: Number, default: null, min: 1, max: 500 },
    // Events only. Organisers show it on screen at the venue; members never get it from the API.
    checkinCode: { type: String, default: null, trim: true, uppercase: true, maxlength: 20 },
    entries: [entrySchema],
    createdBy: { type: Schema.Types.ObjectId, ref: 'User' },
    // Organisers' events are official. Students' events start as community
    // (no points) or pending (points asked for, waiting for an organiser).
    status: { type: String, enum: EVENT_STATUSES, default: 'official' },
    askedPoints: { type: Number, default: 0, min: 0, max: MAX_ASK_POINTS },
  },
  { timestamps: true }
);

// The list filters by kind, the leaderboard and admin stats by entry status,
// and dissolving a crew looks its entries up by crew.
eventSchema.index({ kind: 1, startsAt: 1 });
eventSchema.index({ 'entries.status': 1 });
eventSchema.index({ 'entries.crew': 1 });
eventSchema.index({ status: 1, createdBy: 1 });

const randomCode = () =>
  Array.from({ length: 4 }, () => CHECKIN_CODE_CHARS[randomInt(CHECKIN_CODE_CHARS.length)]).join('');

// Fills the defaults that depend on kind and checks the rules that span fields.
// Runs on create and on every admin edit.
eventSchema.pre('validate', function () {
  if (!this.location) this.location = this.kind === 'challenge' ? 'Anywhere' : 'TBA';
  if (this.kind === 'challenge') this.checkinCode = null;
  else if (!this.checkinCode) this.checkinCode = randomCode();
  // Only official events award points.
  if (this.status !== 'official') this.points = 0;

  const categories = EVENT_CATEGORIES[this.kind];
  if (categories && !categories.includes(this.category)) {
    this.invalidate('category', `A ${this.kind} is one of: ${categories.join(', ')}`);
  }
  if (this.startsAt && this.endsAt && this.endsAt <= this.startsAt) {
    this.invalidate('endsAt', 'endsAt must be after startsAt');
  }
});

// upcoming, live or ended. Worked out on every response, never stored.
eventSchema.virtual('state').get(function () {
  const now = Date.now();
  if (now < this.startsAt) return 'upcoming';
  return now > this.endsAt ? 'ended' : 'live';
});

// Entries of crews that still exist. Populate entries.crew first: a crew that has
// since dissolved populates to null and drops out here.
eventSchema.methods.crewEntries = function () {
  return this.entries.filter((e) => e.crew);
};

const PUBLIC_FIELDS = [
  'kind', 'title', 'summary', 'details', 'category', 'location', 'startsAt', 'endsAt', 'points', 'capacity',
];
const ENTRY_FIELDS = ['status', 'submissionUrl', 'note', 'pointsAwarded', 'joinedAt', 'completedAt'];
const entryFields = (entry) => Object.fromEntries(ENTRY_FIELDS.map((f) => [f, entry[f]]));

// Who made a student event, approved or not. Populate createdBy first;
// organisers' own events have no host.
eventSchema.methods.host = function () {
  const by = this.createdBy;
  if (!by?.name || by.isAdmin) return null;
  return { id: by._id.toString(), name: by.name };
};

const createdById = (event) => event.createdBy?._id ?? event.createdBy;

// What members see: only their own crew's entry, and no check-in code unless
// they host the event (they show it at their own venue).
eventSchema.methods.toMember = function (crewId, userId = null) {
  const entries = this.crewEntries();
  const mine = crewId ? entries.find((e) => e.crew._id.equals(crewId)) : null;
  const hosting = !!userId && this.status !== 'official' && !!createdById(this)?.equals(userId);
  const out = { id: this._id.toString() };
  for (const f of PUBLIC_FIELDS) out[f] = this[f];
  return {
    ...out,
    status: this.status,
    askedPoints: this.askedPoints,
    host: this.host(),
    hosting,
    ...(hosting && { checkinCode: this.kind === 'event' ? this.checkinCode : null }),
    crewCount: entries.length,
    state: this.state,
    myEntry: mine ? entryFields(mine) : null,
  };
};

// Admins also get the check-in code and every crew's entry.
eventSchema.methods.toAdmin = function () {
  return {
    ...this.toMember(null),
    checkinCode: this.kind === 'event' ? this.checkinCode : null,
    entries: this.crewEntries().map((e) => ({ crew: { id: e.crew.id, name: e.crew.name }, ...entryFields(e) })),
  };
};

export default mongoose.model('Event', eventSchema);
