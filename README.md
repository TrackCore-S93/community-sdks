# @trackcore/community-sdk

A typed client for the Community API: topics, a feed of posts with images,
comments and replies, emoji reactions, search, blocking, reports,
notifications and live updates.

TypeScript in strict mode, zero runtime dependencies, ES modules and CommonJS,
Node 18.17 or later and modern browsers.

This is the SDK for your **backend** and for the **web**. It is the only one
that accepts a secret key, so it is the only one with the creator's calls:
topics, settings, pinning, member roles, reports and erasing a user.

## Install

The package is not on the npm registry. Each release carries the built package
as a tarball, and npm, Bun, pnpm and yarn all install it from the URL.

```sh
npm install https://github.com/TrackCore-S93/community-sdk-js/releases/download/v0.1.0/trackcore-community-sdk-0.1.0.tgz
bun add https://github.com/TrackCore-S93/community-sdk-js/releases/download/v0.1.0/trackcore-community-sdk-0.1.0.tgz
pnpm add https://github.com/TrackCore-S93/community-sdk-js/releases/download/v0.1.0/trackcore-community-sdk-0.1.0.tgz
yarn add https://github.com/TrackCore-S93/community-sdk-js/releases/download/v0.1.0/trackcore-community-sdk-0.1.0.tgz
```

## Use

```ts
import { Community } from "@trackcore/community-sdk";

// Once, at start-up.
Community.instance.configure({
  apiKey: process.env.COMMUNITY_API_KEY!,   // cm_sk_… on a server, cm_pk_… in a browser
  baseUrl: "https://community.trackcore.app",
});

// After your own sign-in, with whatever identifies the user in your system.
await Community.instance.initialize(user.id);

const feed = await Community.instance.posts.feed({ topicId });
await Community.instance.posts.create({ topicId, body: "Leg day" });

// On sign-out.
await Community.instance.signOut();
```

`new Community(options)` builds a client you hold yourself, with the same
namespaces.

With a publishable key, `initialize` mints a session for the user and renews
it when it nears its end. With a secret key it names the user and makes no
network call.

## What is in it

| Namespace | Calls |
|---|---|
| `community` | `me`, `join`, `usernameAvailable`, `updateProfile`, `member`, `summary` |
| `topics` | `list`, `get`, and for the creator `create`, `update`, `delete` |
| `posts` | `feed`, `get`, `create`, `delete`, `search`, and for the creator `pin`, `unpin` |
| `comments` | `list`, `replies`, `create`, `delete` |
| `reactions` | `addToPost`, `removeFromPost`, `addToComment`, `removeFromComment`, `setOnPost`, `setOnComment` |
| `media` | `upload`, `start`, `complete`, `get` |
| `blocks` | `list`, `block`, `unblock` |
| `reports` | `reportPost`, `reportComment`, and for the creator `list` |
| `notifications` | `list`, `unreadCount`, `markRead`, `markAllRead` |
| `push` | `register`, `unregister`, `preference`, `setEnabled` |
| `settings` | `get`, and for the creator `update` |
| `members` | for the creator: `list`, `setRole` |
| `auth` | `createSession`, `endSession` |
| `users` | for the creator: `delete` |
| `live` | `connect` |
| (client) | `initialize`, `signOut`, `setUser`, `clearUser`, `setSession`, `clearSession`, `whoAmI`, `currentUser`, `describeCredential` |

A creator's call made with a publishable key throws `ConfigurationError`
(`secret_key_required`) before anything is sent.

## Options

| Option | Default | Meaning |
|---|---|---|
| `apiKey` | `COMMUNITY_API_KEY` | `cm_sk_…` on a server, `cm_pk_…` in a browser |
| `baseUrl` | `COMMUNITY_BASE_URL`, else `https://community.trackcore.app` | Where the API answers |
| `sessionTtlSeconds` | 86400 | How long a session minted by `initialize` lives, 60 to 86400 |
| `timeoutMs` | 10 000 | One attempt |
| `deadlineMs` | 30 000 | The whole call, retries and backoff included |
| `retry` | `{ maxAttempts: 3, max502Attempts: 2, baseDelayMs: 250, maxDelayMs: 4000 }` | Partial overrides of the retry policy |
| `fetch` | the global `fetch` | For a proxy or an instrumented client |
| `headers` | none | Extra headers on every request. Cannot override `Authorization` |
| `onDiagnostic` | none | Retry, session and live events. Never carries a credential |
| `warn` | `console.warn` | Where a warning goes |
| `webSocket` | the runtime's own | Opens the live connection; see below |

Every call also takes `signal`, an `AbortSignal`.

## Rules it enforces

- **A secret key in a browser throws** from the constructor, before anything
  is sent, with no override flag.
- **The key is not reachable from the client object**, so it cannot leak
  through `JSON.stringify(client)` or an error reporter.
- **A write is retried only when repeating it is safe.** Posting and
  commenting carry an idempotency key (the SDK's own unless you pass one), so
  a retry cannot post twice.

## Errors

Every non-2xx reply is a typed error carrying `code` from a closed list, plus
`status`, `requestId`, `fields` and `docsUrl`. Branch on `code`.

```ts
import { isErrorOfCode, ConnectionError, TimeoutError } from "@trackcore/community-sdk";

try {
  await community.community.join(username);
} catch (error) {
  if (isErrorOfCode(error, "username_taken")) {
    // Show "This username is already taken".
  } else if (isErrorOfCode(error, "validation_failed")) {
    // error.fields.username says why.
  } else if (error instanceof ConnectionError || error instanceof TimeoutError) {
    // Nothing came back. Already retried under the policy.
  } else {
    throw error;
  }
}
```

| Class | When |
|---|---|
| `RequestError` | 400, 405, 413 |
| `AuthenticationError` | 401 |
| `AuthorizationError` | 403 |
| `ResourceError` | 404, 409, 422 |
| `RateLimitError` | 429 |
| `ServerError` | 500 |
| `DependencyError` | 502, 504 |
| `MaintenanceError` | 503 |
| `ConfigurationError` | a bad key, a bad `baseUrl`, a bad user id, a call the key cannot make |
| `ValidationError` | an argument that cannot be right, caught locally |
| `ConnectionError`, `TimeoutError`, `AbortError`, `ProtocolError` | nothing usable came back |

## Retries

| Outcome | Retried |
|---|---|
| connection failure, attempt timeout, 408, 429, 503, 504 | yes, up to `maxAttempts`, exponential backoff with full jitter |
| 502 | once, capped by `max502Attempts` |
| 500, and every other 4xx | no |

`Retry-After` wins over the schedule where the server sent one.

## Reactions that feel instant

```ts
import { applyReaction } from "@trackcore/community-sdk";

// Show the change at once…
setReactions(applyReaction(post.reactions, "❤️", true));
// …send it; taps while a request is out collapse into the last wanted state…
const settled = await community.reactions.setOnPost(post.id, "❤️", true);
// …and take the server's list as the truth.
setReactions(settled.reactions);
```

## Images

```ts
const image = await community.media.upload(file);          // a Blob, ArrayBuffer or Uint8Array
await community.posts.create({ topicId, body, mediaIds: [image.id] });
await community.community.updateProfile({ avatarMediaId: image.id });
```

## Live updates

```ts
const connection = community.live.connect({
  topicId,                                    // optional: one topic only
  onEvent: (event) => { /* event.type: "post.created", "post.reactions", … */ },
  onStatus: (status) => { /* "connecting" | "open" | "reconnecting" | "closed" */ },
});
connection.close();
```

The connection reopens by itself with backoff. It needs a WebSocket that can
send request headers: Node 22 and later, Bun and Deno have one. On older Node,
pass the `ws` package: `webSocket: (url, headers) => new WebSocket(url, { headers })`.
A browser's WebSocket cannot send headers, so live updates are not available
in a browser yet.

## Developing

```sh
npm install
npm run generate     # src/generated/* from contract/openapi.yaml
npm test             # build, then the unit tests
```

`contract/openapi.yaml` is a copy of `contracts/openapi.yaml` from the
community repository. After the API changes, copy it again and run
`npm run generate`.

The end-to-end test runs the SDK against a real server. Never point it at a
live one: it creates a customer and writes data.

```sh
COMMUNITY_TEST_BASE_URL=http://localhost:8080 COMMUNITY_TEST_ADMIN_TOKEN=… npm run test:live
```
