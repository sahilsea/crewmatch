import { Router } from 'express';
import { protect, adminOnly, profileRequired } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';
import {
  registerSchema, loginSchema, profileSchema, swipeSchema, createCrewSchema, addMemberSchema,
  eventInputSchema, checkinSchema, submitSchema, approveSchema, rejectSchema,
} from '../utils/schemas.js';
import { register, login, me } from '../controllers/authController.js';
import { getOptions, updateProfile, getUser, deleteAccount } from '../controllers/userController.js';
import { getDeck, swipe, resetPasses } from '../controllers/deckController.js';
import { getMatches, unmatch } from '../controllers/matchController.js';
import { createCrew, getMyCrew, addMember, renameCrew, leaveCrew } from '../controllers/crewController.js';
import {
  listEvents, getEvent, joinEvent, leaveEvent, checkIn, submitEntry, getLeaderboard,
  adminListEvents, createEvent, updateEvent, deleteEvent, approveEntry, rejectEntry,
} from '../controllers/eventController.js';
import { getStats, listUsers } from '../controllers/adminController.js';

const router = Router();

// Public
router.get('/', (req, res) => res.json({ name: 'CrewMatch API', ok: true, docs: 'See server/README.md' }));
router.get('/health', (req, res) => res.json({ ok: true }));
router.get('/options', getOptions);
router.post('/auth/register', validate(registerSchema), register);
router.post('/auth/login', validate(loginSchema), login);

// Everything below needs a signed-in user
router.use(protect);

router.get('/auth/me', me);

router.put('/users/me', validate(profileSchema), updateProfile);
router.delete('/users/me', deleteAccount);
router.get('/users/:id', getUser);

router.get('/deck', profileRequired, getDeck);
router.post('/swipe', profileRequired, validate(swipeSchema), swipe);
router.post('/swipe/reset', resetPasses);

router.get('/matches', getMatches);
router.delete('/matches/:id', unmatch);

router.get('/crews/mine', getMyCrew);
router.post('/crews', validate(createCrewSchema), createCrew);
router.patch('/crews/mine', validate(createCrewSchema.pick({ name: true })), renameCrew);
router.post('/crews/mine/members', validate(addMemberSchema), addMember);
router.delete('/crews/mine', leaveCrew);

// Hackathon hub: events, challenges and the leaderboard (docs/hackathon-api.md)
router.get('/events', listEvents);
router.get('/events/:id', getEvent);
router.post('/events/:id/join', joinEvent);
router.delete('/events/:id/join', leaveEvent);
router.post('/events/:id/checkin', validate(checkinSchema), checkIn);
router.post('/events/:id/submit', validate(submitSchema), submitEntry);
router.get('/leaderboard', getLeaderboard);

router.get('/admin/stats', adminOnly, getStats);
router.get('/admin/users', adminOnly, listUsers);
router.get('/admin/events', adminOnly, adminListEvents);
router.post('/admin/events', adminOnly, validate(eventInputSchema), createEvent);
router.patch('/admin/events/:id', adminOnly, validate(eventInputSchema.partial()), updateEvent);
router.delete('/admin/events/:id', adminOnly, deleteEvent);
router.post('/admin/events/:id/entries/:crewId/approve', adminOnly, validate(approveSchema), approveEntry);
router.post('/admin/events/:id/entries/:crewId/reject', adminOnly, validate(rejectSchema), rejectEntry);

export default router;
