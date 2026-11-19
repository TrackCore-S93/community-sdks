/// Emoji reactions on posts and comments.
library;

import '../errors/exceptions.dart';
import '../generated/models.dart';
import '../http/transport.dart';

/// What a reaction list looks like after the user gives or takes back an
/// emoji, worked out locally. Show this at once, then replace it with the
/// list the server returns. Giving an emoji already given, or taking back
/// one not given, changes nothing.
List<Reaction> applyReaction(List<Reaction> reactions, String emoji,
    {required bool on}) {
  Reaction copy(Reaction r, {int? count, bool? mine}) => Reaction(
      emoji: r.emoji,
      count: count ?? r.count,
      reactedByMe: mine ?? r.reactedByMe);
  final index = reactions.indexWhere((r) => r.emoji == emoji);
  final current = index < 0 ? null : reactions[index];
  if (on) {
    if (current != null && current.reactedByMe) {
      return [for (final r in reactions) copy(r)];
    }
    if (current != null) {
      return [
        for (final r in reactions)
          r.emoji == emoji ? copy(r, count: r.count + 1, mine: true) : copy(r)
      ];
    }
    return [
      for (final r in reactions) copy(r),
      Reaction(emoji: emoji, count: 1, reactedByMe: true)
    ];
  }
  if (current == null || !current.reactedByMe) {
    return [for (final r in reactions) copy(r)];
  }
  return [
    for (final r in reactions)
      if (r.emoji != emoji)
        copy(r)
      else if (r.count > 1)
        copy(r, count: r.count - 1, mine: false),
  ];
}

/// One emoji on one post or comment: the request in flight and what the
/// user wants last.
final class _Chip<R> {
  _Chip(this.wanted);
  bool wanted;
  Future<R>? running;
}

final class ReactionsApi {
  ReactionsApi(this._transport);
  final Transport _transport;
  final Map<String, _Chip<Object>> _chips = {};

  String _check(String field, String value) {
    if (value.isEmpty) {
      throw CommunityValidationException(field, '$field is required.');
    }
    return Uri.encodeComponent(value);
  }

  Future<Map<String, Object?>> _call(String method, String path) async =>
      ((await _transport.request(method, path, audience: Audience.member))!
              as Map)
          .cast<String, Object?>();

  /// Gives an emoji to a post. Giving it again changes nothing.
  Future<PostReactions> addToPost(String postId, String emoji) async =>
      PostReactions.fromJson(await _call('PUT',
          '/v1/posts/${_check('postId', postId)}/reactions/${_check('emoji', emoji)}'));

  /// Takes an emoji back from a post.
  Future<PostReactions> removeFromPost(String postId, String emoji) async =>
      PostReactions.fromJson(await _call('DELETE',
          '/v1/posts/${_check('postId', postId)}/reactions/${_check('emoji', emoji)}'));

  /// Gives an emoji to a comment.
  Future<CommentReactions> addToComment(String commentId, String emoji) async =>
      CommentReactions.fromJson(await _call('PUT',
          '/v1/comments/${_check('commentId', commentId)}/reactions/${_check('emoji', emoji)}'));

  /// Takes an emoji back from a comment.
  Future<CommentReactions> removeFromComment(
          String commentId, String emoji) async =>
      CommentReactions.fromJson(await _call('DELETE',
          '/v1/comments/${_check('commentId', commentId)}/reactions/${_check('emoji', emoji)}'));

  /// Sets whether the user has given this emoji to a post, built for a chip
  /// that is tapped fast. Only one request per chip is in flight at a time,
  /// and when taps arrive while one is running, only the last wanted state
  /// is sent afterwards. Every call completes with the post's reactions
  /// once the chip has settled, so rapid taps cannot leave a wrong count.
  Future<PostReactions> setOnPost(String postId, String emoji,
      {required bool on}) {
    _check('postId', postId);
    _check('emoji', emoji);
    return _settle(
        'post:$postId:$emoji',
        on,
        (want) =>
            want ? addToPost(postId, emoji) : removeFromPost(postId, emoji));
  }

  /// The same as [setOnPost], for a comment.
  Future<CommentReactions> setOnComment(String commentId, String emoji,
      {required bool on}) {
    _check('commentId', commentId);
    _check('emoji', emoji);
    return _settle(
        'comment:$commentId:$emoji',
        on,
        (want) => want
            ? addToComment(commentId, emoji)
            : removeFromComment(commentId, emoji));
  }

  Future<R> _settle<R extends Object>(
      String key, bool on, Future<R> Function(bool want) send) {
    final chip = _chips.putIfAbsent(key, () => _Chip<Object>(on));
    chip.wanted = on;
    final running = chip.running ??= () async {
      try {
        bool sent;
        R result;
        do {
          sent = chip.wanted;
          result = await send(sent);
        } while (chip.wanted != sent);
        return result;
      } finally {
        _chips.remove(key);
      }
    }();
    return running.then((value) => value as R);
  }
}
