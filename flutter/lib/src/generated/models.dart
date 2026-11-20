// GENERATED from contract/openapi.json by tool/generate.dart. Do not edit.
// ignore_for_file: unnecessary_lambdas

/// A session token for one end user. The token appears in this reply and nowhere else.
final class Session {
  /// Builds a [Session]. Normally it comes from the API.
  const Session({
    required this.token,
    required this.tokenType,
    required this.header,
    required this.externalId,
    required this.environment,
    required this.issuedAt,
    required this.expiresAt,
    required this.ttlSeconds,
  });

  /// Reads a [Session] from the API's JSON.
  factory Session.fromJson(Map<String, Object?> json) => Session(
        token: json['token'] as String,
        tokenType: json['token_type'] as String,
        header: json['header'] as String,
        externalId: json['external_id'] as String,
        environment: json['environment'] as String,
        issuedAt: DateTime.parse(json['issued_at'] as String),
        expiresAt: DateTime.parse(json['expires_at'] as String),
        ttlSeconds: (json['ttl_seconds'] as num).toInt(),
      );

  /// The session token. Send it in the header named by `header`.
  final String token;

  /// Always `opaque`: the token carries nothing to decode.
  final String tokenType;

  /// The request header the token is sent in.
  final String header;

  /// The user the session is for.
  final String externalId;

  /// `test` or `live`, the environment of the key that minted it.
  final String environment;

  /// When the session was minted.
  final DateTime issuedAt;

  /// When it stops working.
  final DateTime expiresAt;

  /// Its lifetime in seconds.
  final int ttlSeconds;
}

/// Which customer and key the service sees.
final class WhoAmI {
  /// Builds a [WhoAmI]. Normally it comes from the API.
  const WhoAmI({
    required this.customerId,
    required this.keyId,
    required this.keyKind,
    required this.environment,
  });

  /// Reads a [WhoAmI] from the API's JSON.
  factory WhoAmI.fromJson(Map<String, Object?> json) => WhoAmI(
        customerId: json['customer_id'] as String,
        keyId: json['key_id'] as String,
        keyKind: json['key_kind'] as String,
        environment: json['environment'] as String,
      );

  /// The customer's public id.
  final String customerId;

  /// The key's public id (not the key itself).
  final String keyId;

  /// `secret` or `publishable`.
  final String keyKind;

  /// `test` or `live`.
  final String environment;
}

/// The end user a call acts for.
final class EndUser {
  /// Builds a [EndUser]. Normally it comes from the API.
  const EndUser({
    required this.externalId,
    required this.viaSession,
  });

  /// Reads a [EndUser] from the API's JSON.
  factory EndUser.fromJson(Map<String, Object?> json) => EndUser(
        externalId: json['external_id'] as String,
        viaSession: json['via_session'] as bool,
      );

  /// Your own id for the user.
  final String externalId;

  /// True when the user was named by a session token, false when by `X-External-Id`.
  final bool viaSession;
}

/// The result of erasing an end user.
final class ErasedUser {
  /// Builds a [ErasedUser]. Normally it comes from the API.
  const ErasedUser({
    required this.externalId,
    required this.deleted,
  });

  /// Reads a [ErasedUser] from the API's JSON.
  factory ErasedUser.fromJson(Map<String, Object?> json) => ErasedUser(
        externalId: json['external_id'] as String,
        deleted: json['deleted'] as bool,
      );

  /// The user that was named.
  final String externalId;

  /// False when there was nobody by that id, which is not an error.
  final bool deleted;
}

/// The result of deleting a topic, post or comment.
final class Deleted {
  /// Builds a [Deleted]. Normally it comes from the API.
  const Deleted({
    required this.id,
    required this.deleted,
  });

  /// Reads a [Deleted] from the API's JSON.
  factory Deleted.fromJson(Map<String, Object?> json) => Deleted(
        id: json['id'] as String,
        deleted: json['deleted'] as bool,
      );

  /// The id that was named.
  final String id;

  /// False when it was already gone, which is not an error.
  final bool deleted;
}

/// One member of the community.
final class Profile {
  /// Builds a [Profile]. Normally it comes from the API.
  const Profile({
    required this.externalId,
    required this.username,
    required this.avatarUrl,
    required this.coverUrl,
    required this.bio,
    required this.role,
    required this.version,
    required this.joinedAt,
    required this.updatedAt,
    required this.postsCount,
    required this.commentsCount,
  });

  /// Reads a [Profile] from the API's JSON.
  factory Profile.fromJson(Map<String, Object?> json) => Profile(
        externalId: json['external_id'] as String,
        username: json['username'] as String,
        avatarUrl: json['avatar_url'] as String,
        coverUrl: json['cover_url'] as String,
        bio: json['bio'] as String,
        role: Role.fromWire(json['role'] as String?),
        version: (json['version'] as num).toInt(),
        joinedAt: DateTime.parse(json['joined_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        postsCount: (json['posts_count'] as num).toInt(),
        commentsCount: (json['comments_count'] as num).toInt(),
      );

  /// Your own id for the user.
  final String externalId;

  /// The member's name, unique in the community ignoring case.
  final String username;

  /// A short-lived link to the profile photo, or an empty string.
  final String avatarUrl;

  /// A short-lived link to the profile background, or an empty string.
  final String coverUrl;

  /// The member's bio, or an empty string.
  final String bio;

  /// The label shown beside the member's name.
  final Role role;

  /// Goes up by one each time the profile changes.
  final int version;

  /// When the user joined the community.
  final DateTime joinedAt;

  /// When the profile last changed.
  final DateTime updatedAt;

  /// How many posts the member has in the community now. Deleted and removed posts are not counted.
  final int postsCount;

  /// How many comments and replies the member has in the community now. Deleted and removed ones are not counted.
  final int commentsCount;
}

/// The community at a glance.
final class CommunitySummary {
  /// Builds a [CommunitySummary]. Normally it comes from the API.
  const CommunitySummary({
    required this.membersCount,
    required this.avatarUrls,
  });

  /// Reads a [CommunitySummary] from the API's JSON.
  factory CommunitySummary.fromJson(Map<String, Object?> json) =>
      CommunitySummary(
        membersCount: (json['members_count'] as num).toInt(),
        avatarUrls: (json['avatar_urls'] as List)
            .map((e) => e as String)
            .toList(growable: false),
      );

  /// How many users have joined the community.
  final int membersCount;

  /// Links to the profile photos of up to four members who have one, picked at random on every call. Empty when nobody has a photo. The links expire, like every image link.
  final List<String> avatarUrls;
}

/// A member's profile as another reader sees it.
final class Member {
  /// Builds a [Member]. Normally it comes from the API.
  const Member({
    required this.externalId,
    required this.username,
    required this.avatarUrl,
    required this.coverUrl,
    required this.bio,
    required this.role,
    required this.version,
    required this.joinedAt,
    required this.updatedAt,
    required this.postsCount,
    required this.commentsCount,
    required this.isMe,
  });

  /// Reads a [Member] from the API's JSON.
  factory Member.fromJson(Map<String, Object?> json) => Member(
        externalId: json['external_id'] as String,
        username: json['username'] as String,
        avatarUrl: json['avatar_url'] as String,
        coverUrl: json['cover_url'] as String,
        bio: json['bio'] as String,
        role: Role.fromWire(json['role'] as String?),
        version: (json['version'] as num).toInt(),
        joinedAt: DateTime.parse(json['joined_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        postsCount: (json['posts_count'] as num).toInt(),
        commentsCount: (json['comments_count'] as num).toInt(),
        isMe: json['is_me'] as bool,
      );

  /// Your own id for the user.
  final String externalId;

  /// The member's name, unique in the community ignoring case.
  final String username;

  /// A short-lived link to the profile photo, or an empty string.
  final String avatarUrl;

  /// A short-lived link to the profile background, or an empty string.
  final String coverUrl;

  /// The member's bio, or an empty string.
  final String bio;

  /// The label shown beside the member's name.
  final Role role;

  /// Goes up by one each time the profile changes.
  final int version;

  /// When the user joined the community.
  final DateTime joinedAt;

  /// When the profile last changed.
  final DateTime updatedAt;

  /// How many posts the member has in the community now. Deleted and removed posts are not counted.
  final int postsCount;

  /// How many comments and replies the member has in the community now. Deleted and removed ones are not counted.
  final int commentsCount;

  /// True when the profile is the reader's own, the only one they can edit.
  final bool isMe;
}

/// Whether the user has joined, and their profile if so.
final class Membership {
  /// Builds a [Membership]. Normally it comes from the API.
  const Membership({
    required this.joined,
    this.profile,
  });

  /// Reads a [Membership] from the API's JSON.
  factory Membership.fromJson(Map<String, Object?> json) => Membership(
        joined: json['joined'] as bool,
        profile: json['profile'] == null
            ? null
            : Profile.fromJson(
                (json['profile'] as Map).cast<String, Object?>()),
      );

  /// False until the user has chosen a username.
  final bool joined;

  /// Null until the user has joined.
  final Profile? profile;
}

/// Whether a username is free. A hint for the form; joining decides.
final class UsernameAvailability {
  /// Builds a [UsernameAvailability]. Normally it comes from the API.
  const UsernameAvailability({
    required this.username,
    required this.available,
    this.reason,
    this.message,
  });

  /// Reads a [UsernameAvailability] from the API's JSON.
  factory UsernameAvailability.fromJson(Map<String, Object?> json) =>
      UsernameAvailability(
        username: json['username'] as String,
        available: json['available'] as bool,
        reason: json['reason'] as String?,
        message: json['message'] as String?,
      );

  /// The name that was asked about.
  final String username;

  /// True when the user could take this name now.
  final bool available;

  /// Present when not available: `taken` or `invalid`.
  final String? reason;

  /// Present when not available: a sentence to show under the field.
  final String? message;
}

/// One page of the member list, in username order.
final class MemberList {
  /// Builds a [MemberList]. Normally it comes from the API.
  const MemberList({
    required this.members,
    this.nextCursor,
    required this.hasMore,
    required this.total,
  });

  /// Reads a [MemberList] from the API's JSON.
  factory MemberList.fromJson(Map<String, Object?> json) => MemberList(
        members: (json['members'] as List)
            .map((e) => Profile.fromJson((e as Map).cast<String, Object?>()))
            .toList(growable: false),
        nextCursor: json['next_cursor'] as String?,
        hasMore: json['has_more'] as bool,
        total: (json['total'] as num).toInt(),
      );

  /// The members on this page.
  final List<Profile> members;

  /// Send as `after` for the next page. Null at the end.
  final String? nextCursor;

  /// True when there is another page.
  final bool hasMore;

  /// How many members match the search and role, across all pages.
  final int total;
}

/// One section of the community that posts are written in.
final class Topic {
  /// Builds a [Topic]. Normally it comes from the API.
  const Topic({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.coverUrl,
    required this.postsCount,
    required this.sortOrder,
    required this.isLive,
    required this.isTrending,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Reads a [Topic] from the API's JSON.
  factory Topic.fromJson(Map<String, Object?> json) => Topic(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        imageUrl: json['image_url'] as String,
        coverUrl: json['cover_url'] as String,
        postsCount: (json['posts_count'] as num).toInt(),
        sortOrder: (json['sort_order'] as num).toInt(),
        isLive: json['is_live'] as bool,
        isTrending: json['is_trending'] as bool,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  /// The topic's id.
  final String id;

  /// Unique in the community ignoring case.
  final String name;

  /// Shown on the topic's sheet.
  final String description;

  /// The image on the topic's card.
  final String imageUrl;

  /// The image on the topic's sheet.
  final String coverUrl;

  /// How many posts the topic has.
  final int postsCount;

  /// Position in the list, lowest first.
  final int sortOrder;

  /// False hides the topic and its posts from members.
  final bool isLive;

  /// True puts the topic in the trending list.
  final bool isTrending;

  /// When the topic was created.
  final DateTime createdAt;

  /// When it last changed.
  final DateTime updatedAt;
}

/// The community's topics.
final class TopicList {
  /// Builds a [TopicList]. Normally it comes from the API.
  const TopicList({
    required this.topics,
  });

  /// Reads a [TopicList] from the API's JSON.
  factory TopicList.fromJson(Map<String, Object?> json) => TopicList(
        topics: (json['topics'] as List)
            .map((e) => Topic.fromJson((e as Map).cast<String, Object?>()))
            .toList(growable: false),
      );

  /// In `sort_order`, then by name.
  final List<Topic> topics;
}

/// Who wrote a post or comment.
final class Author {
  /// Builds a [Author]. Normally it comes from the API.
  const Author({
    required this.externalId,
    required this.username,
    required this.avatarUrl,
    required this.role,
  });

  /// Reads a [Author] from the API's JSON.
  factory Author.fromJson(Map<String, Object?> json) => Author(
        externalId: json['external_id'] as String,
        username: json['username'] as String,
        avatarUrl: json['avatar_url'] as String,
        role: Role.fromWire(json['role'] as String?),
      );

  /// Your own id for the user.
  final String externalId;

  /// The name the member chose in the community.
  final String username;

  /// A short-lived link to their photo, or an empty string.
  final String avatarUrl;

  /// The label shown beside their name.
  final Role role;
}

/// One picture on a post or comment. Every image is stored in two sizes: a large one for a post opened on its own screen, and a small one for the feed.
final class CommunityImage {
  /// Builds a [CommunityImage]. Normally it comes from the API.
  const CommunityImage({
    required this.id,
    required this.url,
    required this.width,
    required this.height,
    required this.smallUrl,
    required this.smallWidth,
    required this.smallHeight,
  });

  /// Reads a [CommunityImage] from the API's JSON.
  factory CommunityImage.fromJson(Map<String, Object?> json) => CommunityImage(
        id: json['id'] as String,
        url: json['url'] as String,
        width: (json['width'] as num).toInt(),
        height: (json['height'] as num).toInt(),
        smallUrl: json['small_url'] as String,
        smallWidth: (json['small_width'] as num).toInt(),
        smallHeight: (json['small_height'] as num).toInt(),
      );

  /// The image's id.
  final String id;

  /// A short-lived link to the large size: longest side at most 1024 pixels.
  final String url;

  /// Width of the large size, in pixels.
  final int width;

  /// Height of the large size, in pixels.
  final int height;

  /// A short-lived link to the small size: longest side at most 512 pixels. For an image uploaded before two sizes were stored, or one already 512 pixels or less, this is the same picture as `url`.
  final String smallUrl;

  /// Width of the small size, in pixels.
  final int smallWidth;

  /// Height of the small size, in pixels.
  final int smallHeight;
}

/// One emoji on a post or comment.
final class Reaction {
  /// Builds a [Reaction]. Normally it comes from the API.
  const Reaction({
    required this.emoji,
    required this.count,
    required this.reactedByMe,
  });

  /// Reads a [Reaction] from the API's JSON.
  factory Reaction.fromJson(Map<String, Object?> json) => Reaction(
        emoji: json['emoji'] as String,
        count: (json['count'] as num).toInt(),
        reactedByMe: json['reacted_by_me'] as bool,
      );

  /// The emoji.
  final String emoji;

  /// How many members gave it.
  final int count;

  /// True when the user the call acts for gave it.
  final bool reactedByMe;
}

/// One post in the feed.
final class Post {
  /// Builds a [Post]. Normally it comes from the API.
  const Post({
    required this.id,
    required this.topicId,
    required this.author,
    required this.body,
    required this.images,
    required this.reactions,
    required this.commentsCount,
    required this.isMine,
    required this.isPinned,
    this.pinnedAt,
    required this.createdAt,
  });

  /// Reads a [Post] from the API's JSON.
  factory Post.fromJson(Map<String, Object?> json) => Post(
        id: json['id'] as String,
        topicId: json['topic_id'] as String,
        author:
            Author.fromJson((json['author'] as Map).cast<String, Object?>()),
        body: json['body'] as String,
        images: (json['images'] as List)
            .map((e) =>
                CommunityImage.fromJson((e as Map).cast<String, Object?>()))
            .toList(growable: false),
        reactions: (json['reactions'] as List)
            .map((e) => Reaction.fromJson((e as Map).cast<String, Object?>()))
            .toList(growable: false),
        commentsCount: (json['comments_count'] as num).toInt(),
        isMine: json['is_mine'] as bool,
        isPinned: json['is_pinned'] as bool,
        pinnedAt: json['pinned_at'] == null
            ? null
            : DateTime.parse(json['pinned_at'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  /// The post's id.
  final String id;

  /// The topic it was written in.
  final String topicId;

  /// Who wrote it.
  final Author author;

  /// The text. May be empty when the post has images.
  final String body;

  /// The post's pictures, in the author's order.
  final List<CommunityImage> images;

  /// The emoji on the post, in the creator's chosen order.
  final List<Reaction> reactions;

  /// How many comments and replies the post has.
  final int commentsCount;

  /// True when the side the call acts for wrote it: the member's own messages for the member, the coach's side's for a coach.
  final bool isMine;

  /// True when the creator has pinned it.
  final bool isPinned;

  /// When it was pinned, or null.
  final DateTime? pinnedAt;

  /// When it was posted.
  final DateTime createdAt;
}

/// One page of the feed, newest first.
final class Feed {
  /// Builds a [Feed]. Normally it comes from the API.
  const Feed({
    required this.pinned,
    required this.posts,
    this.nextCursor,
    this.prevCursor,
    this.newestCursor,
    required this.hasMore,
    required this.mode,
    required this.pageSize,
  });

  /// Reads a [Feed] from the API's JSON.
  factory Feed.fromJson(Map<String, Object?> json) => Feed(
        pinned: (json['pinned'] as List)
            .map((e) => Post.fromJson((e as Map).cast<String, Object?>()))
            .toList(growable: false),
        posts: (json['posts'] as List)
            .map((e) => Post.fromJson((e as Map).cast<String, Object?>()))
            .toList(growable: false),
        nextCursor: json['next_cursor'] as String?,
        prevCursor: json['prev_cursor'] as String?,
        newestCursor: json['newest_cursor'] as String?,
        hasMore: json['has_more'] as bool,
        mode: FeedMode.fromWire(json['mode'] as String?),
        pageSize: (json['page_size'] as num).toInt(),
      );

  /// Pinned posts, most recently pinned first. First page only; never repeated in `posts`.
  final List<Post> pinned;

  /// The posts on this page.
  final List<Post> posts;

  /// Send as `before` for the older posts. Null at the end.
  final String? nextCursor;

  /// Send as `after` for the page before. Pages mode only; null otherwise.
  final String? prevCursor;

  /// Send as `after` later for posts created since this read.
  final String? newestCursor;

  /// True when there are more posts in the direction that was read.
  final bool hasMore;

  /// The creator's feed mode.
  final FeedMode mode;

  /// How many posts this read was limited to: the `limit` sent, or 20.
  final int pageSize;
}

/// One page of search results, newest first.
final class SearchResults {
  /// Builds a [SearchResults]. Normally it comes from the API.
  const SearchResults({
    required this.posts,
    this.nextCursor,
    required this.hasMore,
    required this.pageSize,
  });

  /// Reads a [SearchResults] from the API's JSON.
  factory SearchResults.fromJson(Map<String, Object?> json) => SearchResults(
        posts: (json['posts'] as List)
            .map((e) => Post.fromJson((e as Map).cast<String, Object?>()))
            .toList(growable: false),
        nextCursor: json['next_cursor'] as String?,
        hasMore: json['has_more'] as bool,
        pageSize: (json['page_size'] as num).toInt(),
      );

  /// The matching posts.
  final List<Post> posts;

  /// Send as `before` for the next page. Null at the end.
  final String? nextCursor;

  /// True when there is another page.
  final bool hasMore;

  /// The creator's search page size.
  final int pageSize;
}

/// A post's reactions after a change.
final class PostReactions {
  /// Builds a [PostReactions]. Normally it comes from the API.
  const PostReactions({
    required this.postId,
    required this.reactions,
  });

  /// Reads a [PostReactions] from the API's JSON.
  factory PostReactions.fromJson(Map<String, Object?> json) => PostReactions(
        postId: json['post_id'] as String,
        reactions: (json['reactions'] as List)
            .map((e) => Reaction.fromJson((e as Map).cast<String, Object?>()))
            .toList(growable: false),
      );

  /// The post.
  final String postId;

  /// The full list, in the creator's chosen order.
  final List<Reaction> reactions;
}

/// One comment or reply.
final class Comment {
  /// Builds a [Comment]. Normally it comes from the API.
  const Comment({
    required this.id,
    required this.postId,
    this.parentId,
    required this.author,
    required this.body,
    required this.images,
    required this.reactions,
    required this.repliesCount,
    required this.isMine,
    required this.createdAt,
  });

  /// Reads a [Comment] from the API's JSON.
  factory Comment.fromJson(Map<String, Object?> json) => Comment(
        id: json['id'] as String,
        postId: json['post_id'] as String,
        parentId: json['parent_id'] as String?,
        author:
            Author.fromJson((json['author'] as Map).cast<String, Object?>()),
        body: json['body'] as String,
        images: (json['images'] as List)
            .map((e) =>
                CommunityImage.fromJson((e as Map).cast<String, Object?>()))
            .toList(growable: false),
        reactions: (json['reactions'] as List)
            .map((e) => Reaction.fromJson((e as Map).cast<String, Object?>()))
            .toList(growable: false),
        repliesCount: (json['replies_count'] as num).toInt(),
        isMine: json['is_mine'] as bool,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  /// The comment's id.
  final String id;

  /// The post it is on.
  final String postId;

  /// The comment this replies to, or null for a comment on the post.
  final String? parentId;

  /// Who wrote it.
  final Author author;

  /// The text. May be empty when the comment has images.
  final String body;

  /// The comment's pictures.
  final List<CommunityImage> images;

  /// The emoji on the comment.
  final List<Reaction> reactions;

  /// How many replies it has.
  final int repliesCount;

  /// True when the side the call acts for wrote it: the member's own messages for the member, the coach's side's for a coach.
  final bool isMine;

  /// When it was written.
  final DateTime createdAt;
}

/// One page of comments or replies, oldest first.
final class CommentPage {
  /// Builds a [CommentPage]. Normally it comes from the API.
  const CommentPage({
    required this.comments,
    this.nextCursor,
    required this.hasMore,
  });

  /// Reads a [CommentPage] from the API's JSON.
  factory CommentPage.fromJson(Map<String, Object?> json) => CommentPage(
        comments: (json['comments'] as List)
            .map((e) => Comment.fromJson((e as Map).cast<String, Object?>()))
            .toList(growable: false),
        nextCursor: json['next_cursor'] as String?,
        hasMore: json['has_more'] as bool,
      );

  /// The comments on this page.
  final List<Comment> comments;

  /// Send as `after` for the next page. Null at the end.
  final String? nextCursor;

  /// True when there is another page.
  final bool hasMore;
}

/// A comment's reactions after a change.
final class CommentReactions {
  /// Builds a [CommentReactions]. Normally it comes from the API.
  const CommentReactions({
    required this.commentId,
    required this.reactions,
  });

  /// Reads a [CommentReactions] from the API's JSON.
  factory CommentReactions.fromJson(Map<String, Object?> json) =>
      CommentReactions(
        commentId: json['comment_id'] as String,
        reactions: (json['reactions'] as List)
            .map((e) => Reaction.fromJson((e as Map).cast<String, Object?>()))
            .toList(growable: false),
      );

  /// The comment.
  final String commentId;

  /// The full list.
  final List<Reaction> reactions;
}

/// A started upload: where to send the file.
final class Upload {
  /// Builds a [Upload]. Normally it comes from the API.
  const Upload({
    required this.id,
    required this.status,
    required this.upload,
    required this.maxBytes,
  });

  /// Reads a [Upload] from the API's JSON.
  factory Upload.fromJson(Map<String, Object?> json) => Upload(
        id: json['id'] as String,
        status: MediaStatus.fromWire(json['status'] as String?),
        upload: UploadTarget.fromJson(
            (json['upload'] as Map).cast<String, Object?>()),
        maxBytes: (json['max_bytes'] as num).toInt(),
      );

  /// The image's id, used to finish the upload and to attach the image.
  final String id;

  /// `pending` until the upload is finished.
  final MediaStatus status;

  /// Where and how to send the file.
  final UploadTarget upload;

  /// The largest file accepted, in bytes.
  final int maxBytes;
}

/// Where and how to send the file.
final class UploadTarget {
  /// Builds a [UploadTarget]. Normally it comes from the API.
  const UploadTarget({
    required this.method,
    required this.url,
    required this.expiresAt,
  });

  /// Reads a [UploadTarget] from the API's JSON.
  factory UploadTarget.fromJson(Map<String, Object?> json) => UploadTarget(
        method: json['method'] as String,
        url: json['url'] as String,
        expiresAt: DateTime.parse(json['expires_at'] as String),
      );

  /// The HTTP method to send the file with.
  final String method;

  /// The link to send the file to. Send the file's bytes as the body.
  final String url;

  /// When the link stops working.
  final DateTime expiresAt;
}

/// One uploaded image.
final class Media {
  /// Builds a [Media]. Normally it comes from the API.
  const Media({
    required this.id,
    required this.status,
    this.url,
    this.width,
    this.height,
    this.bytes,
    this.smallUrl,
    this.smallWidth,
    this.smallHeight,
    required this.attached,
  });

  /// Reads a [Media] from the API's JSON.
  factory Media.fromJson(Map<String, Object?> json) => Media(
        id: json['id'] as String,
        status: MediaStatus.fromWire(json['status'] as String?),
        url: json['url'] as String?,
        width: (json['width'] as num?)?.toInt(),
        height: (json['height'] as num?)?.toInt(),
        bytes: (json['bytes'] as num?)?.toInt(),
        smallUrl: json['small_url'] as String?,
        smallWidth: (json['small_width'] as num?)?.toInt(),
        smallHeight: (json['small_height'] as num?)?.toInt(),
        attached: json['attached'] as bool,
      );

  /// The image's id.
  final String id;

  /// `pending`, `ready` or `failed`.
  final MediaStatus status;

  /// A short-lived link to the large size (longest side at most 1024 pixels), once ready.
  final String? url;

  /// Width of the large size in pixels, once ready.
  final int? width;

  /// Height of the large size in pixels, once ready.
  final int? height;

  /// Size of the stored large file, once ready.
  final int? bytes;

  /// A short-lived link to the small size (longest side at most 512 pixels), once ready.
  final String? smallUrl;

  /// Width of the small size in pixels, once ready.
  final int? smallWidth;

  /// Height of the small size in pixels, once ready.
  final int? smallHeight;

  /// True once the image is on a post, a comment or a profile.
  final bool attached;
}

/// A member the user has blocked.
final class BlockedMember {
  /// Builds a [BlockedMember]. Normally it comes from the API.
  const BlockedMember({
    required this.externalId,
    required this.username,
    required this.avatarUrl,
    required this.blockedAt,
  });

  /// Reads a [BlockedMember] from the API's JSON.
  factory BlockedMember.fromJson(Map<String, Object?> json) => BlockedMember(
        externalId: json['external_id'] as String,
        username: json['username'] as String,
        avatarUrl: json['avatar_url'] as String,
        blockedAt: DateTime.parse(json['blocked_at'] as String),
      );

  /// Your own id for the user.
  final String externalId;

  /// The name the member chose in the community.
  final String username;

  /// A short-lived link to their photo, or an empty string.
  final String avatarUrl;

  /// When the block was made.
  final DateTime blockedAt;
}

/// The members the user has blocked.
final class BlockList {
  /// Builds a [BlockList]. Normally it comes from the API.
  const BlockList({
    required this.blocked,
  });

  /// Reads a [BlockList] from the API's JSON.
  factory BlockList.fromJson(Map<String, Object?> json) => BlockList(
        blocked: (json['blocked'] as List)
            .map((e) =>
                BlockedMember.fromJson((e as Map).cast<String, Object?>()))
            .toList(growable: false),
      );

  /// Most recently blocked first.
  final List<BlockedMember> blocked;
}

/// The result of unblocking a member.
final class Unblocked {
  /// Builds a [Unblocked]. Normally it comes from the API.
  const Unblocked({
    required this.externalId,
    required this.unblocked,
  });

  /// Reads a [Unblocked] from the API's JSON.
  factory Unblocked.fromJson(Map<String, Object?> json) => Unblocked(
        externalId: json['external_id'] as String,
        unblocked: json['unblocked'] as bool,
      );

  /// The member that was named.
  final String externalId;

  /// False when there was no block, which is not an error.
  final bool unblocked;
}

/// The result of a report.
final class Reported {
  /// Builds a [Reported]. Normally it comes from the API.
  const Reported({
    required this.reported,
    required this.alreadyReported,
    required this.removed,
  });

  /// Reads a [Reported] from the API's JSON.
  factory Reported.fromJson(Map<String, Object?> json) => Reported(
        reported: json['reported'] as bool,
        alreadyReported: json['already_reported'] as bool,
        removed: json['removed'] as bool,
      );

  /// True: the report is on record.
  final bool reported;

  /// True when this member had reported it before.
  final bool alreadyReported;

  /// True when this report reached the creator's threshold and the item was removed from the community.
  final bool removed;
}

/// One report on a post or comment.
final class Report {
  /// Builds a [Report]. Normally it comes from the API.
  const Report({
    required this.id,
    required this.kind,
    required this.targetId,
    required this.excerpt,
    required this.author,
    required this.reporter,
    required this.reason,
    required this.reports,
    required this.createdAt,
  });

  /// Reads a [Report] from the API's JSON.
  factory Report.fromJson(Map<String, Object?> json) => Report(
        id: json['id'] as String,
        kind: json['kind'] as String,
        targetId: json['target_id'] as String,
        excerpt: json['excerpt'] as String,
        author: ReportParty.fromJson(
            (json['author'] as Map).cast<String, Object?>()),
        reporter: ReportParty.fromJson(
            (json['reporter'] as Map).cast<String, Object?>()),
        reason: json['reason'] as String,
        reports: (json['reports'] as num).toInt(),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  /// The report's id.
  final String id;

  /// `post` or `comment`.
  final String kind;

  /// The post or comment that was reported.
  final String targetId;

  /// The start of its text.
  final String excerpt;

  /// Who wrote it.
  final ReportParty author;

  /// Who reported it.
  final ReportParty reporter;

  /// The reason given.
  final String reason;

  /// How many different members have reported the item.
  final int reports;

  /// When the report was made.
  final DateTime createdAt;
}

/// A member named in a report.
final class ReportParty {
  /// Builds a [ReportParty]. Normally it comes from the API.
  const ReportParty({
    required this.externalId,
    required this.username,
  });

  /// Reads a [ReportParty] from the API's JSON.
  factory ReportParty.fromJson(Map<String, Object?> json) => ReportParty(
        externalId: json['external_id'] as String,
        username: json['username'] as String,
      );

  /// Your own id for the user.
  final String externalId;

  /// The name the member chose in the community.
  final String username;
}

/// The reports on the community's content.
final class ReportList {
  /// Builds a [ReportList]. Normally it comes from the API.
  const ReportList({
    required this.reports,
    required this.reportThreshold,
  });

  /// Reads a [ReportList] from the API's JSON.
  factory ReportList.fromJson(Map<String, Object?> json) => ReportList(
        reports: (json['reports'] as List)
            .map((e) => Report.fromJson((e as Map).cast<String, Object?>()))
            .toList(growable: false),
        reportThreshold: (json['report_threshold'] as num).toInt(),
      );

  /// Newest first.
  final List<Report> reports;

  /// The number of reports at which an item is removed from the community.
  final int reportThreshold;
}

/// A post or comment that was removed from the community by reports and kept.
final class Archived {
  /// Builds a [Archived]. Normally it comes from the API.
  const Archived({
    required this.id,
    required this.kind,
    required this.targetId,
    required this.postId,
    this.parentCommentId,
    required this.topicId,
    required this.body,
    required this.images,
    required this.author,
    required this.reason,
    required this.reports,
    required this.threshold,
    required this.reportedBy,
    required this.createdAt,
    required this.archivedAt,
  });

  /// Reads a [Archived] from the API's JSON.
  factory Archived.fromJson(Map<String, Object?> json) => Archived(
        id: json['id'] as String,
        kind: json['kind'] as String,
        targetId: json['target_id'] as String,
        postId: json['post_id'] as String,
        parentCommentId: json['parent_comment_id'] as String?,
        topicId: json['topic_id'] as String,
        body: json['body'] as String,
        images: (json['images'] as List)
            .map((e) =>
                CommunityImage.fromJson((e as Map).cast<String, Object?>()))
            .toList(growable: false),
        author: ReportParty.fromJson(
            (json['author'] as Map).cast<String, Object?>()),
        reason: json['reason'] as String,
        reports: (json['reports'] as num).toInt(),
        threshold: (json['threshold'] as num).toInt(),
        reportedBy: (json['reported_by'] as List)
            .map((e) =>
                ArchivedReporter.fromJson((e as Map).cast<String, Object?>()))
            .toList(growable: false),
        createdAt: DateTime.parse(json['created_at'] as String),
        archivedAt: DateTime.parse(json['archived_at'] as String),
      );

  /// The archived item's id.
  final String id;

  /// `post` or `comment`.
  final String kind;

  /// The post or comment that was archived.
  final String targetId;

  /// The post itself, or the post the comment is under.
  final String postId;

  /// Set when the comment is a reply: the comment it sits under.
  final String? parentCommentId;

  /// The topic it was written in.
  final String topicId;

  /// Its whole text.
  final String body;

  /// Its pictures.
  final List<CommunityImage> images;

  /// Who wrote it.
  final ReportParty author;

  /// Why it was archived. `reports`: it reached the report threshold.
  final String reason;

  /// How many different members had reported it when it was archived.
  final int reports;

  /// The report threshold at that moment.
  final int threshold;

  /// The members who reported it, oldest first. A reporter who has since been erased is not listed.
  final List<ArchivedReporter> reportedBy;

  /// When it was written.
  final DateTime createdAt;

  /// When it was archived.
  final DateTime archivedAt;
}

/// A member who reported an archived item.
final class ArchivedReporter {
  /// Builds a [ArchivedReporter]. Normally it comes from the API.
  const ArchivedReporter({
    required this.externalId,
    required this.username,
    required this.reason,
    required this.createdAt,
  });

  /// Reads a [ArchivedReporter] from the API's JSON.
  factory ArchivedReporter.fromJson(Map<String, Object?> json) =>
      ArchivedReporter(
        externalId: json['external_id'] as String,
        username: json['username'] as String,
        reason: json['reason'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  /// Your own id for the user.
  final String externalId;

  /// The name the member chose in the community.
  final String username;

  /// The reason they gave.
  final String reason;

  /// When they reported it.
  final DateTime createdAt;
}

/// One page of the moderation archive.
final class ArchiveList {
  /// Builds a [ArchiveList]. Normally it comes from the API.
  const ArchiveList({
    required this.archived,
    this.nextCursor,
  });

  /// Reads a [ArchiveList] from the API's JSON.
  factory ArchiveList.fromJson(Map<String, Object?> json) => ArchiveList(
        archived: (json['archived'] as List)
            .map((e) => Archived.fromJson((e as Map).cast<String, Object?>()))
            .toList(growable: false),
        nextCursor: json['next_cursor'] as String?,
      );

  /// Newest first.
  final List<Archived> archived;

  /// Pass as `before` for the next page. Null at the end.
  final String? nextCursor;
}

/// One member being told what another did to what they wrote.
final class CommunityNotification {
  /// Builds a [CommunityNotification]. Normally it comes from the API.
  const CommunityNotification({
    required this.id,
    required this.kind,
    required this.actor,
    required this.postId,
    this.commentId,
    this.parentCommentId,
    this.emoji,
    required this.postExcerpt,
    this.commentExcerpt,
    required this.unread,
    required this.createdAt,
  });

  /// Reads a [CommunityNotification] from the API's JSON.
  factory CommunityNotification.fromJson(Map<String, Object?> json) =>
      CommunityNotification(
        id: json['id'] as String,
        kind: NotificationKind.fromWire(json['kind'] as String?),
        actor: NotificationActor.fromJson(
            (json['actor'] as Map).cast<String, Object?>()),
        postId: json['post_id'] as String,
        commentId: json['comment_id'] as String?,
        parentCommentId: json['parent_comment_id'] as String?,
        emoji: json['emoji'] as String?,
        postExcerpt: json['post_excerpt'] as String,
        commentExcerpt: json['comment_excerpt'] as String?,
        unread: json['unread'] as bool,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  /// The notification's id.
  final String id;

  /// What happened.
  final NotificationKind kind;

  /// Who did it.
  final NotificationActor actor;

  /// The post concerned: open this.
  final String postId;

  /// The comment reacted to, or the new comment. Null for a reaction on a post.
  final String? commentId;

  /// Set when `comment_id` is a reply: the comment it sits under.
  final String? parentCommentId;

  /// The emoji, for a reaction. Null otherwise.
  final String? emoji;

  /// The start of the post's text.
  final String postExcerpt;

  /// The start of the comment's text, when there is a comment.
  final String? commentExcerpt;

  /// True until the member opens it or marks all read.
  final bool unread;

  /// When it happened.
  final DateTime createdAt;
}

/// The member who acted.
final class NotificationActor {
  /// Builds a [NotificationActor]. Normally it comes from the API.
  const NotificationActor({
    required this.externalId,
    required this.username,
    required this.avatarUrl,
  });

  /// Reads a [NotificationActor] from the API's JSON.
  factory NotificationActor.fromJson(Map<String, Object?> json) =>
      NotificationActor(
        externalId: json['external_id'] as String,
        username: json['username'] as String,
        avatarUrl: json['avatar_url'] as String,
      );

  /// Your own id for the user.
  final String externalId;

  /// The name the member chose in the community.
  final String username;

  /// A short-lived link to their photo, or an empty string.
  final String avatarUrl;
}

/// One page of notifications, newest first.
final class NotificationList {
  /// Builds a [NotificationList]. Normally it comes from the API.
  const NotificationList({
    required this.notifications,
    this.nextCursor,
    required this.unreadCount,
  });

  /// Reads a [NotificationList] from the API's JSON.
  factory NotificationList.fromJson(Map<String, Object?> json) =>
      NotificationList(
        notifications: (json['notifications'] as List)
            .map((e) => CommunityNotification.fromJson(
                (e as Map).cast<String, Object?>()))
            .toList(growable: false),
        nextCursor: json['next_cursor'] as String?,
        unreadCount: (json['unread_count'] as num).toInt(),
      );

  /// The notifications on this page.
  final List<CommunityNotification> notifications;

  /// Send as `before` for the next page. Null at the end.
  final String? nextCursor;

  /// How many of all the member's notifications are unread.
  final int unreadCount;
}

/// The number for the bell.
final class UnreadCount {
  /// Builds a [UnreadCount]. Normally it comes from the API.
  const UnreadCount({
    required this.unreadCount,
  });

  /// Reads a [UnreadCount] from the API's JSON.
  factory UnreadCount.fromJson(Map<String, Object?> json) => UnreadCount(
        unreadCount: (json['unread_count'] as num).toInt(),
      );

  /// How many notifications are unread.
  final int unreadCount;
}

/// The result of opening one notification.
final class NotificationRead {
  /// Builds a [NotificationRead]. Normally it comes from the API.
  const NotificationRead({
    required this.id,
    required this.unread,
    required this.unreadCount,
  });

  /// Reads a [NotificationRead] from the API's JSON.
  factory NotificationRead.fromJson(Map<String, Object?> json) =>
      NotificationRead(
        id: json['id'] as String,
        unread: json['unread'] as bool,
        unreadCount: (json['unread_count'] as num).toInt(),
      );

  /// The notification.
  final String id;

  /// Always false.
  final bool unread;

  /// How many are still unread.
  final int unreadCount;
}

/// What the creator has chosen for the community.
final class Settings {
  /// Builds a [Settings]. Normally it comes from the API.
  const Settings({
    required this.maxImagesPerPost,
    required this.reactionOrder,
    required this.commentRepliesEnabled,
    required this.feedMode,
    required this.reportThreshold,
    required this.searchPageSize,
    required this.bioMaxLength,
    required this.profileViewingEnabled,
    required this.pushEnabled,
    required this.maxImageUploadBytes,
    required this.imageUploadsEnabled,
    this.removedByThreshold,
  });

  /// Reads a [Settings] from the API's JSON.
  factory Settings.fromJson(Map<String, Object?> json) => Settings(
        maxImagesPerPost: (json['max_images_per_post'] as num).toInt(),
        reactionOrder:
            ReactionOrder.fromWire(json['reaction_order'] as String?),
        commentRepliesEnabled: json['comment_replies_enabled'] as bool,
        feedMode: FeedMode.fromWire(json['feed_mode'] as String?),
        reportThreshold: (json['report_threshold'] as num).toInt(),
        searchPageSize: (json['search_page_size'] as num).toInt(),
        bioMaxLength: (json['bio_max_length'] as num).toInt(),
        profileViewingEnabled: json['profile_viewing_enabled'] as bool,
        pushEnabled: json['push_enabled'] as bool,
        maxImageUploadBytes: (json['max_image_upload_bytes'] as num).toInt(),
        imageUploadsEnabled: json['image_uploads_enabled'] as bool,
        removedByThreshold: json['removed_by_threshold'] == null
            ? null
            : RemovedByThreshold.fromJson(
                (json['removed_by_threshold'] as Map).cast<String, Object?>()),
      );

  /// Images one post may carry, 0 to 10. 0 turns images off.
  final int maxImagesPerPost;

  /// The order reaction chips are shown in.
  final ReactionOrder reactionOrder;

  /// Members may reply to comments.
  final bool commentRepliesEnabled;

  /// How the app presents the feed.
  final FeedMode feedMode;

  /// Reports that remove a post or comment from the community, 1 or more.
  final int reportThreshold;

  /// Search results per page, 1 to 40.
  final int searchPageSize;

  /// The most characters a bio may have, 1 to 5000.
  final int bioMaxLength;

  /// Members may open each other's profiles.
  final bool profileViewingEnabled;

  /// Notifications are also sent to members' phones.
  final bool pushEnabled;

  /// The largest image upload, in bytes. Fixed, not a creator setting.
  final int maxImageUploadBytes;

  /// False when this deployment has no image storage.
  final bool imageUploadsEnabled;

  /// Present only in the reply to a change of `report_threshold`.
  final RemovedByThreshold? removedByThreshold;
}

/// What a new report threshold removed at once.
final class RemovedByThreshold {
  /// Builds a [RemovedByThreshold]. Normally it comes from the API.
  const RemovedByThreshold({
    required this.posts,
    required this.comments,
  });

  /// Reads a [RemovedByThreshold] from the API's JSON.
  factory RemovedByThreshold.fromJson(Map<String, Object?> json) =>
      RemovedByThreshold(
        posts: (json['posts'] as num).toInt(),
        comments: (json['comments'] as num).toInt(),
      );

  /// Posts deleted.
  final int posts;

  /// Comments deleted.
  final int comments;
}

/// A member's coaching chat at a glance.
final class CoachChat {
  /// Builds a [CoachChat]. Normally it comes from the API.
  const CoachChat({
    required this.unreadCount,
    this.lastMessageAt,
  });

  /// Reads a [CoachChat] from the API's JSON.
  factory CoachChat.fromJson(Map<String, Object?> json) => CoachChat(
        unreadCount: (json['unread_count'] as num).toInt(),
        lastMessageAt: json['last_message_at'] == null
            ? null
            : DateTime.parse(json['last_message_at'] as String),
      );

  /// How many messages from the other side have not been seen: the coach's, for the member; the member's, when the coach's side asks.
  final int unreadCount;

  /// When the last message was sent, or null while the chat is empty.
  final DateTime? lastMessageAt;
}

/// One page of the coach's list of chats, newest activity first.
final class CoachChatList {
  /// Builds a [CoachChatList]. Normally it comes from the API.
  const CoachChatList({
    required this.chats,
    this.nextCursor,
    required this.hasMore,
  });

  /// Reads a [CoachChatList] from the API's JSON.
  factory CoachChatList.fromJson(Map<String, Object?> json) => CoachChatList(
        chats: (json['chats'] as List)
            .map((e) =>
                CoachChatRow.fromJson((e as Map).cast<String, Object?>()))
            .toList(growable: false),
        nextCursor: json['next_cursor'] as String?,
        hasMore: json['has_more'] as bool,
      );

  /// The chats on this page.
  final List<CoachChatRow> chats;

  /// Send as `before` for the next page. Null at the end.
  final String? nextCursor;

  /// True when there are more chats after this page.
  final bool hasMore;
}

/// One member's chat in the coach's list.
final class CoachChatRow {
  /// Builds a [CoachChatRow]. Normally it comes from the API.
  const CoachChatRow({
    required this.member,
    required this.unreadCount,
    required this.lastMessageAt,
    required this.lastMessage,
  });

  /// Reads a [CoachChatRow] from the API's JSON.
  factory CoachChatRow.fromJson(Map<String, Object?> json) => CoachChatRow(
        member:
            Author.fromJson((json['member'] as Map).cast<String, Object?>()),
        unreadCount: (json['unread_count'] as num).toInt(),
        lastMessageAt: DateTime.parse(json['last_message_at'] as String),
        lastMessage: CoachLastMessage.fromJson(
            (json['last_message'] as Map).cast<String, Object?>()),
      );

  /// Whose chat it is. The username is empty for someone who has not joined the community.
  final Author member;

  /// How many of the member's messages the coach's side has not seen.
  final int unreadCount;

  /// When the newest message was sent, by either side.
  final DateTime lastMessageAt;

  /// The newest message, for the preview line.
  final CoachLastMessage lastMessage;
}

/// The preview of a chat's newest message.
final class CoachLastMessage {
  /// Builds a [CoachLastMessage]. Normally it comes from the API.
  const CoachLastMessage({
    required this.id,
    required this.body,
    required this.fromCoach,
    required this.imagesCount,
    required this.filesCount,
  });

  /// Reads a [CoachLastMessage] from the API's JSON.
  factory CoachLastMessage.fromJson(Map<String, Object?> json) =>
      CoachLastMessage(
        id: json['id'] as String,
        body: json['body'] as String,
        fromCoach: json['from_coach'] as bool,
        imagesCount: (json['images_count'] as num).toInt(),
        filesCount: (json['files_count'] as num).toInt(),
      );

  /// The message's id.
  final String id;

  /// Its text. May be empty when it has images or files.
  final String body;

  /// True when the coach's side wrote it.
  final bool fromCoach;

  /// How many pictures it has.
  final int imagesCount;

  /// How many voice notes and documents it has.
  final int filesCount;
}

/// One message in a coaching chat.
final class CoachMessage {
  /// Builds a [CoachMessage]. Normally it comes from the API.
  const CoachMessage({
    required this.id,
    this.author,
    required this.fromCoach,
    required this.body,
    required this.images,
    required this.files,
    required this.isMine,
    required this.isRead,
    this.editedAt,
    required this.createdAt,
  });

  /// Reads a [CoachMessage] from the API's JSON.
  factory CoachMessage.fromJson(Map<String, Object?> json) => CoachMessage(
        id: json['id'] as String,
        author: json['author'] == null
            ? null
            : Author.fromJson((json['author'] as Map).cast<String, Object?>()),
        fromCoach: json['from_coach'] as bool,
        body: json['body'] as String,
        images: (json['images'] as List)
            .map((e) =>
                CommunityImage.fromJson((e as Map).cast<String, Object?>()))
            .toList(growable: false),
        files: (json['files'] as List)
            .map((e) => CoachFile.fromJson((e as Map).cast<String, Object?>()))
            .toList(growable: false),
        isMine: json['is_mine'] as bool,
        isRead: json['is_read'] as bool,
        editedAt: json['edited_at'] == null
            ? null
            : DateTime.parse(json['edited_at'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  /// The message's id.
  final String id;

  /// Who wrote it. Null once that person's account has been erased; the message stays. The username is empty for someone who has not joined the community.
  final Author? author;

  /// Which side wrote it: true for the coach's side, false for the member.
  final bool fromCoach;

  /// The text. May be empty when the message has images or files.
  final String body;

  /// The message's pictures.
  final List<CommunityImage> images;

  /// The voice notes and documents on it. Only the coach's side sends them; a member's message has none.
  final List<CoachFile> files;

  /// True when the side the call acts for wrote it: the member's own messages for the member, the coach's side's for a coach.
  final bool isMine;

  /// True when the other side of the chat has seen it. On the member's own message, the coach has read it; on the coach's, the member has.
  final bool isRead;

  /// When the text was last changed, or null if it never was.
  final DateTime? editedAt;

  /// When it was sent.
  final DateTime createdAt;
}

/// One page of a coaching chat, oldest first.
final class CoachMessagePage {
  /// Builds a [CoachMessagePage]. Normally it comes from the API.
  const CoachMessagePage({
    required this.messages,
    this.olderCursor,
    this.newerCursor,
    required this.hasOlder,
    required this.hasNewer,
  });

  /// Reads a [CoachMessagePage] from the API's JSON.
  factory CoachMessagePage.fromJson(Map<String, Object?> json) =>
      CoachMessagePage(
        messages: (json['messages'] as List)
            .map((e) =>
                CoachMessage.fromJson((e as Map).cast<String, Object?>()))
            .toList(growable: false),
        olderCursor: json['older_cursor'] as String?,
        newerCursor: json['newer_cursor'] as String?,
        hasOlder: json['has_older'] as bool,
        hasNewer: json['has_newer'] as bool,
      );

  /// The messages on this page.
  final List<CoachMessage> messages;

  /// Send as `before` for the messages above these. Null when the page is empty.
  final String? olderCursor;

  /// Send as `after` for the messages below these, including ones that arrive later. Null when the page is empty.
  final String? newerCursor;

  /// True when there are messages before this page.
  final bool hasOlder;

  /// True when there are messages after this page.
  final bool hasNewer;
}

/// A voice note or a document on a coaching-chat message.
final class CoachFile {
  /// Builds a [CoachFile]. Normally it comes from the API.
  const CoachFile({
    required this.id,
    required this.kind,
    required this.name,
    required this.contentType,
    this.bytes,
    this.durationMs,
    this.url,
  });

  /// Reads a [CoachFile] from the API's JSON.
  factory CoachFile.fromJson(Map<String, Object?> json) => CoachFile(
        id: json['id'] as String,
        kind: json['kind'] as String,
        name: json['name'] as String,
        contentType: json['content_type'] as String,
        bytes: (json['bytes'] as num?)?.toInt(),
        durationMs: (json['duration_ms'] as num?)?.toInt(),
        url: json['url'] as String?,
      );

  /// The file's id.
  final String id;

  /// `voice` is a voice note, to play. `file` is a document, to open or save.
  final String kind;

  /// What the sender called the file.
  final String name;

  /// The file's type.
  final String contentType;

  /// The file's size in bytes. Null until the upload is finished.
  final int? bytes;

  /// A voice note's length in milliseconds, when the sender gave it. Null otherwise.
  final int? durationMs;

  /// A short-lived link to the file. Null until the upload is finished.
  final String? url;
}

/// A started file upload: where to send the bytes.
final class CoachFileUpload {
  /// Builds a [CoachFileUpload]. Normally it comes from the API.
  const CoachFileUpload({
    required this.id,
    required this.kind,
    required this.name,
    required this.upload,
    required this.maxBytes,
  });

  /// Reads a [CoachFileUpload] from the API's JSON.
  factory CoachFileUpload.fromJson(Map<String, Object?> json) =>
      CoachFileUpload(
        id: json['id'] as String,
        kind: json['kind'] as String,
        name: json['name'] as String,
        upload: UploadTarget.fromJson(
            (json['upload'] as Map).cast<String, Object?>()),
        maxBytes: (json['max_bytes'] as num).toInt(),
      );

  /// The file's id, used to finish the upload and to put the file on a message.
  final String id;

  /// What was asked for.
  final String kind;

  /// The file's name.
  final String name;

  /// Where and how to send the file.
  final UploadTarget upload;

  /// The largest file accepted, in bytes.
  final int maxBytes;
}

/// One page of chat search results, newest first.
final class CoachSearchResults {
  /// Builds a [CoachSearchResults]. Normally it comes from the API.
  const CoachSearchResults({
    required this.messages,
    this.nextCursor,
    required this.hasMore,
  });

  /// Reads a [CoachSearchResults] from the API's JSON.
  factory CoachSearchResults.fromJson(Map<String, Object?> json) =>
      CoachSearchResults(
        messages: (json['messages'] as List)
            .map((e) =>
                CoachMessage.fromJson((e as Map).cast<String, Object?>()))
            .toList(growable: false),
        nextCursor: json['next_cursor'] as String?,
        hasMore: json['has_more'] as bool,
      );

  /// The matching messages.
  final List<CoachMessage> messages;

  /// Send as `before` for the next page. Null at the end.
  final String? nextCursor;

  /// True when there is another page.
  final bool hasMore;
}

/// A registered phone.
final class PushDevice {
  /// Builds a [PushDevice]. Normally it comes from the API.
  const PushDevice({
    required this.provider,
    this.platform,
    required this.registered,
  });

  /// Reads a [PushDevice] from the API's JSON.
  factory PushDevice.fromJson(Map<String, Object?> json) => PushDevice(
        provider: PushProvider.fromWire(json['provider'] as String?),
        platform: json['platform'] == null
            ? null
            : PushPlatform.fromWire(json['platform'] as String?),
        registered: json['registered'] as bool,
      );

  /// The service the token belongs to.
  final PushProvider provider;

  /// What the app said it runs on; null when it did not say.
  final PushPlatform? platform;

  /// Always true.
  final bool registered;
}

/// The result of forgetting a phone.
final class PushUnregistered {
  /// Builds a [PushUnregistered]. Normally it comes from the API.
  const PushUnregistered({
    required this.removed,
  });

  /// Reads a [PushUnregistered] from the API's JSON.
  factory PushUnregistered.fromJson(Map<String, Object?> json) =>
      PushUnregistered(
        removed: json['removed'] as bool,
      );

  /// False when the token was not registered for this user.
  final bool removed;
}

/// The user's push switch.
final class PushPreference {
  /// Builds a [PushPreference]. Normally it comes from the API.
  const PushPreference({
    required this.enabled,
    required this.communityEnabled,
    required this.devices,
  });

  /// Reads a [PushPreference] from the API's JSON.
  factory PushPreference.fromJson(Map<String, Object?> json) => PushPreference(
        enabled: json['enabled'] as bool,
        communityEnabled: json['community_enabled'] as bool,
        devices: (json['devices'] as num).toInt(),
      );

  /// The user's own choice.
  final bool enabled;

  /// The creator's switch. Push arrives only when both are on.
  final bool communityEnabled;

  /// How many phones the user has registered.
  final int devices;
}

/// The push service a token belongs to.
enum PushProvider {
  expo('expo'),
  fcm('fcm'),

  /// A value this version of the SDK does not know. The API may add values.
  unknown('');

  const PushProvider(this.wire);

  /// The value as the API sends and accepts it.
  final String wire;

  /// The member for a value from the API, or [unknown].
  static PushProvider fromWire(String? value) => values
      .firstWhere((e) => e.wire == value, orElse: () => PushProvider.unknown);
}

/// What the app runs on.
enum PushPlatform {
  ios('ios'),
  android('android'),
  web('web'),

  /// A value this version of the SDK does not know. The API may add values.
  unknown('');

  const PushPlatform(this.wire);

  /// The value as the API sends and accepts it.
  final String wire;

  /// The member for a value from the API, or [unknown].
  static PushPlatform fromWire(String? value) => values
      .firstWhere((e) => e.wire == value, orElse: () => PushPlatform.unknown);
}

/// One message on the live connection.
final class LiveEvent {
  /// Builds a [LiveEvent]. Normally it comes from the API.
  const LiveEvent({
    required this.type,
    this.topicId,
    this.postId,
    this.commentId,
    this.messageId,
    this.memberExternalId,
    this.parentId,
    this.kind,
    this.authorExternalId,
    this.reactions,
    this.commentsCount,
  });

  /// Reads a [LiveEvent] from the API's JSON.
  factory LiveEvent.fromJson(Map<String, Object?> json) => LiveEvent(
        type: LiveEventType.fromWire(json['type'] as String?),
        topicId: json['topic_id'] as String?,
        postId: json['post_id'] as String?,
        commentId: json['comment_id'] as String?,
        messageId: json['message_id'] as String?,
        memberExternalId: json['member_external_id'] as String?,
        parentId: json['parent_id'] as String?,
        kind: json['kind'] == null
            ? null
            : NotificationKind.fromWire(json['kind'] as String?),
        authorExternalId: json['author_external_id'] as String?,
        reactions: json['reactions'] == null
            ? null
            : (json['reactions'] as List)
                .map((e) =>
                    LiveReaction.fromJson((e as Map).cast<String, Object?>()))
                .toList(growable: false),
        commentsCount: (json['comments_count'] as num?)?.toInt(),
      );

  /// What happened.
  final LiveEventType type;

  /// The topic concerned. Absent on `notification.created`.
  final String? topicId;

  /// The post concerned. Absent on coaching-chat events.
  final String? postId;

  /// The comment concerned, for comment events.
  final String? commentId;

  /// The chat message concerned, on `coach_message` events.
  final String? messageId;

  /// Whose chat a coaching-chat event is about. Sent only to the coach's side: a connection made with a secret key, for the backend or naming a coach or the creator.
  final String? memberExternalId;

  /// The comment it replies to, when it is a reply.
  final String? parentId;

  /// What the notification is about, on `notification.created`.
  final NotificationKind? kind;

  /// Who wrote the post, comment or chat message, for created, updated and deleted events. Never sent for reactions.
  final String? authorExternalId;

  /// The full new list, for a reactions event. Empty when the last one was removed.
  final List<LiveReaction>? reactions;

  /// The post's new comment count, for a comment event.
  final int? commentsCount;
}

/// One emoji and its count. Who gave it is not sent.
final class LiveReaction {
  /// Builds a [LiveReaction]. Normally it comes from the API.
  const LiveReaction({
    required this.emoji,
    required this.count,
  });

  /// Reads a [LiveReaction] from the API's JSON.
  factory LiveReaction.fromJson(Map<String, Object?> json) => LiveReaction(
        emoji: json['emoji'] as String,
        count: (json['count'] as num).toInt(),
      );

  /// The emoji.
  final String emoji;

  /// How many members gave it.
  final int count;
}

/// The label shown beside a member's name. It gives no extra permissions.
enum Role {
  user('user'),
  coach('coach'),
  creator('creator'),

  /// A value this version of the SDK does not know. The API may add values.
  unknown('');

  const Role(this.wire);

  /// The value as the API sends and accepts it.
  final String wire;

  /// The member for a value from the API, or [unknown].
  static Role fromWire(String? value) =>
      values.firstWhere((e) => e.wire == value, orElse: () => Role.unknown);
}

/// How the app presents the feed.
enum FeedMode {
  infiniteScroll('infinite_scroll'),
  pages('pages'),

  /// A value this version of the SDK does not know. The API may add values.
  unknown('');

  const FeedMode(this.wire);

  /// The value as the API sends and accepts it.
  final String wire;

  /// The member for a value from the API, or [unknown].
  static FeedMode fromWire(String? value) =>
      values.firstWhere((e) => e.wire == value, orElse: () => FeedMode.unknown);
}

/// The order reaction chips are shown in.
enum ReactionOrder {
  mostUsed('most_used'),
  firstAdded('first_added'),

  /// A value this version of the SDK does not know. The API may add values.
  unknown('');

  const ReactionOrder(this.wire);

  /// The value as the API sends and accepts it.
  final String wire;

  /// The member for a value from the API, or [unknown].
  static ReactionOrder fromWire(String? value) => values
      .firstWhere((e) => e.wire == value, orElse: () => ReactionOrder.unknown);
}

/// Where an upload is in its life.
enum MediaStatus {
  pending('pending'),
  ready('ready'),
  failed('failed'),

  /// A value this version of the SDK does not know. The API may add values.
  unknown('');

  const MediaStatus(this.wire);

  /// The value as the API sends and accepts it.
  final String wire;

  /// The member for a value from the API, or [unknown].
  static MediaStatus fromWire(String? value) => values
      .firstWhere((e) => e.wire == value, orElse: () => MediaStatus.unknown);
}

/// What a notification is about.
enum NotificationKind {
  postReaction('post_reaction'),
  commentReaction('comment_reaction'),
  postComment('post_comment'),
  commentReply('comment_reply'),

  /// A value this version of the SDK does not know. The API may add values.
  unknown('');

  const NotificationKind(this.wire);

  /// The value as the API sends and accepts it.
  final String wire;

  /// The member for a value from the API, or [unknown].
  static NotificationKind fromWire(String? value) =>
      values.firstWhere((e) => e.wire == value,
          orElse: () => NotificationKind.unknown);
}

/// The kinds of live message.
enum LiveEventType {
  postCreated('post.created'),
  postDeleted('post.deleted'),
  postPinned('post.pinned'),
  postUnpinned('post.unpinned'),
  postReactions('post.reactions'),
  commentCreated('comment.created'),
  commentDeleted('comment.deleted'),
  commentReactions('comment.reactions'),
  notificationCreated('notification.created'),
  coachMessageCreated('coach_message.created'),
  coachMessageUpdated('coach_message.updated'),
  coachMessageDeleted('coach_message.deleted'),
  coachChatRead('coach_chat.read'),
  coachChatMemberRead('coach_chat.member_read'),

  /// A value this version of the SDK does not know. The API may add values.
  unknown('');

  const LiveEventType(this.wire);

  /// The value as the API sends and accepts it.
  final String wire;

  /// The member for a value from the API, or [unknown].
  static LiveEventType fromWire(String? value) => values
      .firstWhere((e) => e.wire == value, orElse: () => LiveEventType.unknown);
}
