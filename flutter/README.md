# trackcore_community

The Community client for Flutter and Dart. Typed, null-safe, zero
dependencies, and pure Dart: a Flutter app inherits no plugin, no platform
channel and no permission from it, and the same package runs on a Dart
server. Error codes are an enum.

```dart
import 'package:trackcore_community/trackcore_community.dart';

await Community.instance.configure(apiKey: 'cm_pk_live_…');

await Community.instance.initialize(user.uid);   // after your sign-in; the session is the SDK's problem

try {
  final membership = await Community.instance.community.me();
  if (!membership.joined) await Community.instance.community.join('Annie');

  final feed = await Community.instance.posts.feed();
  await Community.instance.posts.create(topicId: feed.posts.first.topicId, body: 'Leg day');
} on CommunityApiException catch (error) {
  switch (error.code) {
    case CommunityErrorCode.usernameTaken:          // show it under the field
    case CommunityErrorCode.communityJoinRequired:  // show the Welcome screen
    default:                                        // error.message, error.requestId
  }
}
```

`CommunityClient.publishable(...)` builds a client you hold yourself, with
the same APIs.

## Install

The package is not on pub.dev. Add it from git:

```yaml
dependencies:
  trackcore_community:
    git:
      url: https://github.com/TrackCore-S93/community-sdks.git
      ref: flutter-v0.1.2
      path: flutter
```

Dart 3.4 or later.

## What is in it

| API | Calls |
|---|---|
| `community` | `me`, `join`, `usernameAvailable`, `updateProfile`, `member`, `summary` |
| `topics` | `list`, `get`, `create`, `update`, `delete` |
| `posts` | `feed`, `get`, `create`, `delete`, `search`, `pin`, `unpin` |
| `comments` | `list`, `replies`, `create`, `delete` |
| `reactions` | `setOnPost`, `setOnComment`, `addToPost`, `removeFromPost`, `addToComment`, `removeFromComment` |
| `media` | `upload`, `start`, `complete`, `get` |
| `blocks` | `list`, `block`, `unblock` |
| `reports` | `reportPost`, `reportComment`, `list` |
| `archive` | `list`, `get`: posts and comments removed by reports, kept and not deleted |
| `notifications` | `list`, `unreadCount`, `markRead`, `markAllRead` |
| `push` | `register`, `unregister`, `preference`, `setEnabled` |
| `settings` | `get`, `update` |
| `members` | `list`, `setRole` |
| `auth` | `createSession`, `endSession` |
| `users` | `delete` |
| `live` | `connect` |
| | `initialize`, `signOut`, `setSession`, `clearSession`, `whoAmI`, `currentUser`, `describeCredential` |

The creator's calls (`topics.create`, `settings.update`, `posts.pin`,
`members.*`, `reports.list`, `archive.*`, `users.delete`) need a secret key. With a
publishable key they throw `CommunityConfigurationException`
(`secretKeyRequired`) before anything is sent.

## Three rules it enforces

1. **A secret key is refused in an app.** `CommunityClient.publishable` and
   `Community.instance.configure` throw on one. A Dart server uses
   `CommunityClient.serverSideSecret`, or passes
   `iUnderstandThisKeyMustNeverShipInAnAppBinary: true` to `configure`.
2. **HTTPS only.** A `baseUrl` that is not `https://` is refused, except
   `localhost`, `127.0.0.1` and the Android emulator's `10.0.2.2`.
3. **A write is retried only when repeating it is safe.** Posting and
   commenting carry an idempotency key, so a retry cannot post twice.

## Options

| Option | Default | Meaning |
|---|---|---|
| `apiKey` | required | `cm_pk_…` in an app |
| `baseUrl` | `https://api.community.trackcore.app` | Where the API answers. The same for every customer: leave it out |
| `sessionTtlSeconds` | 86400 | How long a session minted by `initialize` lives, 60 to 86400 |
| `timeout` | 10 s | One attempt |
| `retryPolicy` | `CommunityRetryPolicy()` | Attempts, backoff and the deadline for the whole call |
| `httpAdapter` | `dart:io` | Sends the requests; implement `CommunityHttpAdapter` for another client |
| `headers` | none | Extra headers on every request. Cannot override `Authorization` |
| `onDiagnostic` | none | Retry, session and live events. Never carries a credential |
| `liveSocket` | `dart:io` WebSocket | Opens the live connection |

## Reactions that feel instant

```dart
final on = !post.reactions.any((r) => r.emoji == '❤️' && r.reactedByMe);
show(applyReaction(post.reactions, '❤️', on: on));                               // at once
final settled = await community.reactions.setOnPost(post.id, '❤️', on: on);      // one request per chip
show(settled.reactions);                                                          // the server's list
```

## Images

```dart
final image = await community.media.upload(bytes, contentType: 'image/jpeg');
await community.posts.create(topicId: topicId, body: body, mediaIds: [image.id]);
```

## Live updates

```dart
final connection = community.live.connect(topicId: topicId);
connection.events.listen((event) {
  if (event.type == LiveEventType.postCreated) showNewPostsMarker();
});
await connection.close();
```

## Platforms

Android, iOS, macOS, Windows, Linux and Dart servers. The web is not
supported yet: there is no built-in HTTP adapter for it (pass your own as
`httpAdapter`), and a browser's WebSocket cannot send the headers live
updates need.

The package has been tested on the Dart VM and under `flutter test` against a
real server. It has not yet been run inside an app on a phone.

## Names

Two models carry a prefix so they do not clash with Flutter's own classes:
`CommunityImage` and `CommunityNotification`.

## Developing

```sh
dart pub get
dart run tool/generate.dart     # lib/src/generated/* from contract/openapi.json
dart analyze
dart test
```

`contract/openapi.json` is the API contract from the community repository
(`contracts/openapi.yaml`), as JSON. After the API changes, convert it again
and run the generator.

The end-to-end test runs against a real server. Never point it at a live one:
it creates a customer and writes data.

```sh
COMMUNITY_TEST_BASE_URL=http://localhost:8080 COMMUNITY_TEST_ADMIN_TOKEN=… dart test test/live_integration_test.dart
```
