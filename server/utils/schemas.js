import { z } from 'zod';
import mongoose from 'mongoose';
import {
  OPTIONS, MAX_SUPERPOWERS, MAX_CREW_SIZE, EVENT_KINDS, EVENT_CATEGORIES,
  CARD_COVERS, CARD_ACCENTS, CARD_FIELDS, MAX_ASK_POINTS,
} from '../config/options.js';

const objectId = z.string().refine((v) => mongoose.isValidObjectId(v), 'Invalid id');

// Letters, spaces and the usual name punctuation; at least two letters.
const personName = z
  .string()
  .trim()
  .min(2, 'Enter your full name')
  .max(60, 'Names can be up to 60 characters')
  .regex(/^[\p{L}][\p{L}\p{M} .'-]*$/u, 'Use letters only in your name');

// At least 8 characters with a letter and a number.
export const passwordRule = z
  .string()
  .min(8, 'Use at least 8 characters')
  .max(100, 'Passwords can be up to 100 characters')
  .regex(/[A-Za-z]/, 'Add at least one letter')
  .regex(/\d/, 'Add at least one number');

export const registerSchema = z.object({
  name: personName,
  email: z.email('Enter a valid email address').trim().toLowerCase().max(120),
  password: passwordRule,
});

export const verifySchema = z.object({ code: z.string().trim().regex(/^\d{6}$/, 'Enter the 6-digit code') });

export const loginSchema = z.object({
  email: z.email('Enter a valid email address').trim().toLowerCase(),
  password: z.string().min(1, 'Enter your password'),
});

// Every field is optional so web and mobile can save partial edits.
export const profileSchema = z
  .object({
    name: z.string().trim().min(2).max(60),
    avatar: z.url().or(z.literal('')),
    bio: z.string().trim().max(280),
    role: z.enum(OPTIONS.role),
    experienceLevel: z.enum(OPTIONS.experienceLevel),
    schedule: z.enum(OPTIONS.schedule),
    commitment: z.enum(OPTIONS.commitment),
    communication: z.enum(OPTIONS.communication),
    interests: z.array(z.enum(OPTIONS.interests)).min(1).max(OPTIONS.interests.length),
    superpowers: z.array(z.enum(OPTIONS.superpowers)).max(MAX_SUPERPOWERS),
    skills: z.array(z.string().trim().min(1).max(30)).max(15),
    headline: z.string().trim().max(80),
    cover: z.enum(CARD_COVERS),
    accent: z.enum(CARD_ACCENTS),
    cardFields: z.array(z.enum(CARD_FIELDS)).max(CARD_FIELDS.length),
  })
  .partial()
  .strict();

export const swipeSchema = z.object({
  targetId: objectId,
  direction: z.enum(['left', 'right']),
});

export const createCrewSchema = z.object({
  name: z.string().trim().min(2).max(50),
  memberIds: z.array(objectId).max(MAX_CREW_SIZE - 1).default([]),
});

export const addMemberSchema = z.object({ userId: objectId });

export const createPostSchema = z.object({
  text: z.string().trim().min(1).max(500),
  tag: z.enum(['update', 'looking', 'win']).nullable().optional(),
  // A data URL; the controller checks the type and size.
  photo: z.string().max(4_500_000).nullable().optional(),
});

export const commentSchema = z.object({ text: z.string().trim().min(1).max(300) });

// A chat line: text, a photo, a document, or text with one of them.
export const messageSchema = z
  .object({
    text: z.string().trim().max(1000).optional().default(''),
    photo: z.string().max(4_500_000).optional(),
    file: z.object({ name: z.string().trim().min(1).max(120), data: z.string().max(14_000_000) }).optional(),
  })
  .refine((m) => m.text.length > 0 || m.photo || m.file, 'Write a message or attach something')
  .refine((m) => !(m.photo && m.file), 'Attach a photo or a file, not both');

export const photoUploadSchema = z.object({ photo: z.string().min(1).max(4_500_000) });

// ISO date strings (or epoch milliseconds) from the admin form.
const date = z.union([z.string(), z.number()]).pipe(z.coerce.date({ error: 'Invalid date' }));

// EventInput: the admin form for events and challenges. PATCH takes any subset.
// The rules that span fields (category fits kind, endsAt after startsAt) live in
// the Event model, so they hold for edits too.
export const eventInputSchema = z
  .object({
    kind: z.enum(EVENT_KINDS),
    title: z.string().trim().min(2).max(80),
    summary: z.string().trim().min(1).max(140),
    details: z.string().trim().max(2000),
    category: z.enum(Object.values(EVENT_CATEGORIES).flat()),
    location: z.string().trim().max(80),
    startsAt: date,
    endsAt: date,
    points: z.number().int().min(0).max(1000),
    capacity: z.number().int().min(1).max(500).nullable(),
    // Empty or null on an event means "generate one".
    checkinCode: z.string().trim().max(20).nullable(),
  })
  .partial({ details: true, location: true, capacity: true, checkinCode: true });

// A student's own event. It goes live as a community event straight away;
// asking for points sends it to the organisers for review.
export const studentEventSchema = z
  .object({
    kind: z.enum(EVENT_KINDS),
    title: z.string().trim().min(2).max(80),
    summary: z.string().trim().min(1).max(140),
    category: z.enum(Object.values(EVENT_CATEGORIES).flat()),
    location: z.string().trim().max(80),
    startsAt: date,
    endsAt: date,
    capacity: z.number().int().min(1).max(500).nullable(),
    askPoints: z.number().int().min(0).max(MAX_ASK_POINTS),
  })
  .partial({ location: true, capacity: true, askPoints: true });

export const officialSchema = z.object({ points: z.number().int().min(0).max(1000).optional() });

export const checkinSchema = z.object({ code: z.string().trim().max(50) });

export const submitSchema = z.object({
  url: z.string().trim().max(500).pipe(z.url({ protocol: /^https?$/, error: 'Must be an http:// or https:// link' })),
  note: z.string().trim().max(280).nullish(),
});

// Admins can override the points, e.g. for a podium bonus.
export const approveSchema = z.object({ points: z.number().int().min(0).max(1000).optional() });

export const rejectSchema = z.object({ note: z.string().trim().max(280).nullish() });
