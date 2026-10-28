import { z } from 'zod';
import mongoose from 'mongoose';
import {
  OPTIONS, MAX_SUPERPOWERS, MAX_CREW_SIZE, EVENT_KINDS, EVENT_CATEGORIES,
} from '../config/options.js';

const objectId = z.string().refine((v) => mongoose.isValidObjectId(v), 'Invalid id');

export const registerSchema = z.object({
  name: z.string().trim().min(2).max(60),
  email: z.email().toLowerCase(),
  password: z.string().min(6).max(100),
});

export const loginSchema = z.object({
  email: z.email().toLowerCase(),
  password: z.string().min(1),
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

export const checkinSchema = z.object({ code: z.string().trim().max(50) });

export const submitSchema = z.object({
  url: z.string().trim().max(500).pipe(z.url({ protocol: /^https?$/, error: 'Must be an http:// or https:// link' })),
  note: z.string().trim().max(280).nullish(),
});

// Admins can override the points, e.g. for a podium bonus.
export const approveSchema = z.object({ points: z.number().int().min(0).max(1000).optional() });

export const rejectSchema = z.object({ note: z.string().trim().max(280).nullish() });
