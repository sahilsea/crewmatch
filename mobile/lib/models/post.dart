import 'json.dart';

/// Who wrote a post, comment or chat line: just enough to show a face.
class Author {
  const Author({required this.id, required this.name, this.avatar = '', this.role});

  factory Author.fromJson(Map<String, dynamic> json) => Author(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Someone',
        avatar: json['avatar'] as String? ?? '',
        role: json['role'] as String?,
      );

  /// A deleted account.
  static const gone = Author(id: '', name: 'Deleted account');

  final String id;
  final String name;
  final String avatar;
  final String? role;
}

/// What a post is about. Shown as a small chip; [update] has none.
enum PostTag {
  update('Update'),
  looking('Looking for teammates'),
  win('Win');

  const PostTag(this.label);

  final String label;

  static PostTag? parse(Object? value) =>
      values.where((t) => t.name == value).firstOrNull;
}

/// One post on the hackathon feed (`GET /posts`).
class Post {
  const Post({
    required this.id,
    required this.author,
    required this.text,
    required this.createdAt,
    this.crewName,
    this.tag,
    this.photoUrl,
    this.likeCount = 0,
    this.likedByMe = false,
    this.commentCount = 0,
    this.comments = const [],
  });

  factory Post.fromJson(Map<String, dynamic> json) => Post(
        id: json['id'] as String,
        author: json['author'] is Map<String, dynamic> ? Author.fromJson(json['author'] as Map<String, dynamic>) : Author.gone,
        crewName: json['crewName'] as String?,
        text: json['text'] as String? ?? '',
        tag: PostTag.parse(json['tag']),
        photoUrl: json['photoUrl'] as String?,
        likeCount: intOr(json['likeCount']),
        likedByMe: json['likedByMe'] == true,
        commentCount: intOr(json['commentCount']),
        comments: [for (final c in objectList(json['comments'])) PostComment.fromJson(c)],
        createdAt: dateOrNull(json['createdAt']) ?? DateTime.now(),
      );

  final String id;
  final Author author;
  final String? crewName;
  final String text;
  final PostTag? tag;

  /// A server path (`/api/photos/…`); resolve it against the API host.
  final String? photoUrl;
  final int likeCount;
  final bool likedByMe;
  final int commentCount;

  /// The newest two, for the preview under the post.
  final List<PostComment> comments;
  final DateTime createdAt;

  /// Flips the like straight away, before the server answers.
  Post toggledLike() => Post(
        id: id,
        author: author,
        crewName: crewName,
        text: text,
        tag: tag,
        photoUrl: photoUrl,
        likeCount: likeCount + (likedByMe ? -1 : 1),
        likedByMe: !likedByMe,
        commentCount: commentCount,
        comments: comments,
        createdAt: createdAt,
      );
}

class PostComment {
  const PostComment({required this.id, required this.author, required this.text, required this.createdAt});

  factory PostComment.fromJson(Map<String, dynamic> json) => PostComment(
        id: json['id'] as String? ?? '',
        author: json['author'] is Map<String, dynamic> ? Author.fromJson(json['author'] as Map<String, dynamic>) : Author.gone,
        text: json['text'] as String? ?? '',
        createdAt: dateOrNull(json['createdAt']) ?? DateTime.now(),
      );

  final String id;
  final Author author;
  final String text;
  final DateTime createdAt;
}

/// A page of the feed.
class PostPage {
  const PostPage({required this.posts, this.hasMore = false});

  factory PostPage.fromJson(Map<String, dynamic> json) => PostPage(
        posts: [for (final p in objectList(json['posts'])) Post.fromJson(p)],
        hasMore: json['hasMore'] == true,
      );

  final List<Post> posts;
  final bool hasMore;
}

/// One line in the crew chat. System lines have no author.
class ChatMessage {
  const ChatMessage({required this.id, required this.text, required this.createdAt, this.author, this.system = false, this.attachment});

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        text: json['text'] as String? ?? '',
        system: json['kind'] == 'system',
        author: json['author'] is Map<String, dynamic> ? Author.fromJson(json['author'] as Map<String, dynamic>) : null,
        attachment: json['attachment'] is Map<String, dynamic> ? Attachment.fromJson(json['attachment'] as Map<String, dynamic>) : null,
        createdAt: dateOrNull(json['createdAt']) ?? DateTime.now(),
      );

  final String id;
  final String text;
  final bool system;
  final Author? author;
  final Attachment? attachment;
  final DateTime createdAt;
}

/// A photo or document sent in the crew chat.
class Attachment {
  const Attachment({required this.photo, required this.url, required this.name, this.type = '', this.size = 0});

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
        photo: json['kind'] == 'photo',
        url: json['url'] as String? ?? '',
        name: json['name'] as String? ?? 'File',
        type: json['type'] as String? ?? '',
        size: intOr(json['size']),
      );

  final bool photo;

  /// A server path: photos load like any image, files need your sign-in.
  final String url;
  final String name;
  final String type;
  final int size;

  /// "PDF · 2.4 MB"
  String get summary {
    final ext = name.contains('.') ? name.split('.').last.toUpperCase() : 'File';
    final kb = size / 1024;
    return '$ext · ${kb >= 1024 ? '${(kb / 1024).toStringAsFixed(1)} MB' : '${kb.ceil()} KB'}';
  }
}

/// One thing someone did at the hackathon (`GET /users/:id/activity`).
class ActivityItem {
  const ActivityItem({required this.kind, required this.text, this.at});

  factory ActivityItem.fromJson(Map<String, dynamic> json) => ActivityItem(
        kind: json['kind'] as String? ?? '',
        text: json['text'] as String? ?? '',
        at: dateOrNull(json['at']),
      );

  /// `post`, `crew`, `points` or `match`.
  final String kind;
  final String text;

  /// When; matches have no date.
  final DateTime? at;
}
