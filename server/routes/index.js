import { Router } from 'express';
import { protect, adminOnly, profileRequired, verifiedRequired } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';
import {
  registerSchema, loginSchema, profileSchema, swipeSchema, createCrewSchema, addMemberSchema,
  eventInputSchema, studentEventSchema, officialSchema, checkinSchema, submitSchema, approveSchema, rejectSchema,
  createPostSchema, commentSchema, messageSchema, photoUploadSchema, verifySchema, googleSchema, teamRequestSchema,
} from '../utils/schemas.js';
import { register, login, googleSignIn, me, verifyEmail, resendCode } from '../controllers/authController.js';
import {
  getOptions, updateProfile, getUser, deleteAccount, uploadAvatar, removeAvatar, uploadCover, removeCover, getActivity,
} from '../controllers/userController.js';
import { getDeck, swipe, resetPasses } from '../controllers/deckController.js';
import { getMatches, unmatch } from '../controllers/matchController.js';
import { createCrew, getMyCrew, addMember, removeMember, renameCrew, leaveCrew } from '../controllers/crewController.js';
import {
  listEvents, getEvent, joinEvent, leaveEvent, checkIn, submitEntry, getLeaderboard,
  hostEvent, cancelHostedEvent, makeOfficial, keepCommunity,
  adminListEvents, createEvent, updateEvent, deleteEvent, approveEntry, rejectEntry,
} from '../controllers/eventController.js';
import { getStats, listUsers } from '../controllers/adminController.js';
import {
  searchUsers, getByHandle, publicProfile, sendRequest, listRequests, acceptRequest, declineRequest, withdrawRequest,
} from '../controllers/requestController.js';
import { listHackathons, getHackathonLeaderboard } from '../controllers/hackathonController.js';
import {
  listPosts, listUserPosts, createPost, deletePost, toggleLike, listComments, addComment, getPhoto,
} from '../controllers/postController.js';
import { listMessages, sendMessage, getFile } from '../controllers/chatController.js';

const router = Router();

// Public
router.get('/', (req, res) => res.json({ name: 'CrewMatch API', ok: true, docs: 'See server/README.md' }));
router.get('/health', (req, res) => res.json({ ok: true }));
router.get('/options', getOptions);
router.post('/auth/register', validate(registerSchema), register);
router.post('/auth/login', validate(loginSchema), login);
router.post('/auth/google', validate(googleSchema), googleSignIn);
router.get('/photos/:id', getPhoto);
router.get('/public/u/:handle', publicProfile);

// Everything below needs a signed-in user
router.use(protect);

router.get('/auth/me', me);
router.post('/auth/verify', validate(verifySchema), verifyEmail);
router.post('/auth/resend', resendCode);
router.delete('/users/me', deleteAccount);

// Everything below also needs a verified email
router.use(verifiedRequired);

router.put('/users/me', validate(profileSchema), updateProfile);
router.post('/users/me/avatar', validate(photoUploadSchema), uploadAvatar);
router.delete('/users/me/avatar', removeAvatar);
router.post('/users/me/cover', validate(photoUploadSchema), uploadCover);
router.delete('/users/me/cover', removeCover);
// Finding people: search, profile links and team-up requests (before /users/:id).
router.get('/users/search', searchUsers);
router.get('/users/handle/:handle', getByHandle);
router.get('/requests', listRequests);
router.post('/requests', validate(teamRequestSchema), sendRequest);
router.post('/requests/:id/accept', acceptRequest);
router.post('/requests/:id/decline', declineRequest);
router.delete('/requests/:id', withdrawRequest);
router.get('/users/:id', getUser);
router.get('/users/:id/posts', listUserPosts);
router.get('/users/:id/activity', getActivity);

router.get('/deck', profileRequired, getDeck);
router.post('/swipe', profileRequired, validate(swipeSchema), swipe);
router.post('/swipe/reset', resetPasses);

router.get('/matches', getMatches);
router.delete('/matches/:id', unmatch);

router.get('/crews/mine', getMyCrew);
router.post('/crews', validate(createCrewSchema), createCrew);
router.patch('/crews/mine', validate(createCrewSchema.pick({ name: true })), renameCrew);
router.post('/crews/mine/members', validate(addMemberSchema), addMember);
router.delete('/crews/mine/members/:userId', removeMember);
router.get('/crews/mine/messages', listMessages);
router.post('/crews/mine/messages', validate(messageSchema), sendMessage);
router.get('/crews/mine/files/:id', getFile);

// Hackathon feed
router.get('/posts', listPosts);
router.post('/posts', validate(createPostSchema), createPost);
router.delete('/posts/:id', deletePost);
router.post('/posts/:id/like', toggleLike);
router.get('/posts/:id/comments', listComments);
router.post('/posts/:id/comments', validate(commentSchema), addComment);
router.delete('/crews/mine', leaveCrew);

// Hackathon hub: events, challenges and the leaderboard (docs/hackathon-api.md)
router.get('/events', listEvents);
router.post('/events', validate(studentEventSchema), hostEvent);
router.get('/events/:id', getEvent);
router.post('/events/:id/join', joinEvent);
router.delete('/events/:id/join', leaveEvent);
router.delete('/events/:id', cancelHostedEvent);
router.post('/events/:id/checkin', validate(checkinSchema), checkIn);
router.post('/events/:id/submit', validate(submitSchema), submitEntry);
router.get('/leaderboard', getLeaderboard);
router.get('/hackathons', listHackathons);
router.get('/hackathons/:id/leaderboard', getHackathonLeaderboard);

router.get('/admin/stats', adminOnly, getStats);
router.get('/admin/users', adminOnly, listUsers);
router.get('/admin/events', adminOnly, adminListEvents);
router.post('/admin/events', adminOnly, validate(eventInputSchema), createEvent);
router.patch('/admin/events/:id', adminOnly, validate(eventInputSchema.partial()), updateEvent);
router.delete('/admin/events/:id', adminOnly, deleteEvent);
router.post('/admin/events/:id/official', adminOnly, validate(officialSchema), makeOfficial);
router.post('/admin/events/:id/community', adminOnly, keepCommunity);
router.post('/admin/events/:id/entries/:crewId/approve', adminOnly, validate(approveSchema), approveEntry);
router.post('/admin/events/:id/entries/:crewId/reject', adminOnly, validate(rejectSchema), rejectEntry);

export default router;
