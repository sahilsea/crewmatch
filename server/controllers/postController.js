import mongoose from 'mongoose';
import Post from '../models/Post.js';
import Photo from '../models/Photo.js';
import Crew from '../models/Crew.js';
import { HttpError } from '../middleware/error.js';
import { decodeDataUrl } from '../utils/uploads.js';

const PAGE = 20;
const AUTHOR_FIELDS = 'name avatar role';

const person = (u) => (u ? { id: u.id, name: u.name, avatar: u.avatar, role: u.role ?? null } : null);

// What the app shows for a post. The two newest comments ride along so the
// feed can preview them; GET /posts/:id/comments has the rest.
function postView(post, me) {
  return {
    id: post.id,
    author: person(post.author),
    crewName: post.crewName,
    text: post.text,
    tag: post.tag,
    photoUrl: post.photo ? `/api/photos/${post.photo}` : null,
    likeCount: post.likes.length,
    likedByMe: post.likes.some((id) => id.equals(me._id)),
    commentCount: post.comments.length,
    comments: post.comments.slice(-2).map(commentView),
    createdAt: post.createdAt,
  };
}

const commentView = (c) => ({ id: c.id, author: person(c.author), text: c.text, createdAt: c.createdAt });

async function findPost(id) {
  const post = mongoose.isValidObjectId(id)
    ? await Post.findById(id).populate('author', AUTHOR_FIELDS).populate('comments.author', AUTHOR_FIELDS)
    : null;
  if (!post) throw new HttpError(404, 'Post not found');
  return post;
}


// GET /api/posts?before=<ISO date> — newest first, 20 at a time.
export async function listPosts(req, res) {
  const before = req.query.before ? new Date(req.query.before) : null;
  const filter = before && !Number.isNaN(before.getTime()) ? { createdAt: { $lt: before } } : {};
  const posts = await Post.find(filter)
    .sort({ createdAt: -1 })
    .limit(PAGE)
    .populate('author', AUTHOR_FIELDS)
    .populate('comments.author', AUTHOR_FIELDS);
  res.json({ posts: posts.map((p) => postView(p, req.user)), hasMore: posts.length === PAGE });
}

// GET /api/users/:id/posts — one person's posts, newest first.
export async function listUserPosts(req, res) {
  if (!mongoose.isValidObjectId(req.params.id)) throw new HttpError(404, 'User not found');
  const posts = await Post.find({ author: req.params.id })
    .sort({ createdAt: -1 })
    .limit(PAGE)
    .populate('author', AUTHOR_FIELDS)
    .populate('comments.author', AUTHOR_FIELDS);
  res.json({ posts: posts.map((p) => postView(p, req.user)) });
}

// POST /api/posts  { text, tag?, photo? (data URL) }
export async function createPost(req, res) {
  const crew = req.user.crew ? await Crew.findById(req.user.crew, 'name') : null;
  let photo = null;
  if (req.body.photo) {
    const { type, data } = decodeDataUrl(req.body.photo);
    photo = (await Photo.create({ owner: req.user._id, type, data }))._id;
  }
  const post = await Post.create({
    author: req.user._id,
    crewName: crew?.name ?? null,
    text: req.body.text,
    tag: req.body.tag ?? null,
    photo,
  });
  res.status(201).json({ post: postView(await findPost(post.id), req.user) });
}

// DELETE /api/posts/:id — your own post, or any post for an admin.
export async function deletePost(req, res) {
  const post = await findPost(req.params.id);
  if (!post.author._id.equals(req.user._id) && !req.user.isAdmin) throw new HttpError(403, 'Not your post');
  await Promise.all([post.deleteOne(), post.photo ? Photo.deleteOne({ _id: post.photo }) : null]);
  res.status(204).end();
}

// POST /api/posts/:id/like — toggles your like.
export async function toggleLike(req, res) {
  const post = await findPost(req.params.id);
  const liked = post.likes.some((id) => id.equals(req.user._id));
  await Post.updateOne({ _id: post._id }, liked ? { $pull: { likes: req.user._id } } : { $addToSet: { likes: req.user._id } });
  res.json({ post: postView(await findPost(post.id), req.user) });
}

// GET /api/posts/:id/comments — oldest first.
export async function listComments(req, res) {
  const post = await findPost(req.params.id);
  res.json({ comments: post.comments.map(commentView) });
}

// POST /api/posts/:id/comments  { text }
export async function addComment(req, res) {
  const post = await findPost(req.params.id);
  post.comments.push({ author: req.user._id, text: req.body.text });
  await post.save();
  const fresh = await findPost(post.id);
  res.status(201).json({ post: postView(fresh, req.user), comment: commentView(fresh.comments.at(-1)) });
}

// GET /api/photos/:id — public, so <img> and Image.network can load it
// without a token. Ids are unguessable ObjectIds of photos on public posts.
export async function getPhoto(req, res) {
  const photo = mongoose.isValidObjectId(req.params.id) ? await Photo.findById(req.params.id) : null;
  if (!photo) throw new HttpError(404, 'Photo not found');
  res.set({
    'Content-Type': photo.type,
    'Cache-Control': 'public, max-age=31536000, immutable',
    'Cross-Origin-Resource-Policy': 'cross-origin',
  });
  res.send(photo.data);
}
