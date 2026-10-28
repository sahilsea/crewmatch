import { z } from 'zod';
import mongoose from 'mongoose';
import { OPTIONS, MAX_SUPERPOWERS, MAX_CREW_SIZE } from '../config/options.js';

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
