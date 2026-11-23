# @trackcore/community-react-native

The Community client for React Native and Expo.

It is built on the [TypeScript SDK](../typescript)
and forks nothing from it: the request layer, the retry policy, the error
classes and the models are the same objects, imported. Three things are
specialised because a device forced them:

- **A secret key is refused**, unconditionally.
- **The creator's calls are not here.** Settings, topics, roles, pinning,
  reports and erasing a user need a secret key, so they belong on a backend,
  with the JavaScript SDK.
- **The live connection** is opened the way React Native's WebSocket needs.

It has no native modules of its own. It imports nothing from `react-native`
at runtime, works in Expo Go, and needs no rebuild to add.

## Install

Neither package is on the npm registry. Install both from their releases:

```sh
npm install https://github.com/TrackCore-S93/community-sdks/releases/download/typescript-v0.1.1/trackcore-community-sdk-0.1.1.tgz
npm install https://github.com/TrackCore-S93/community-sdks/releases/download/react-native-v0.1.1/trackcore-community-react-native-0.1.1.tgz
```

`bun add`, `pnpm add` and `yarn add` take the same two URLs.

`@trackcore/community-sdk` is a peer dependency, marked optional only so that
npm does not look for it on the registry.

## Use

```ts
import { Community } from "@trackcore/community-react-native";

// Once, when the app starts.
Community.instance.configure({ apiKey: "cm_pk_live_…" });   // publishable. A cm_sk_ key throws here.

// After your own sign-in, with whatever identifies the user in your system.
await Community.instance.initialize(user.id);

// Anywhere in the app from then on.
const feed = await Community.instance.posts.feed({ topicId });
await Community.instance.posts.create({ topicId, body: "Leg day" });

// On sign-out.
await Community.instance.signOut();
```

`createCommunityClient(options)` builds a client you hold yourself.

`initialize` mints a session for the user and renews it when it nears its
end. There is no token to fetch and no backend endpoint to build.

## What is in it

| Namespace | Calls |
|---|---|
| `community` | `me`, `join`, `usernameAvailable`, `updateProfile`, `member`, `summary` |
| `topics` | `list`, `get` |
| `posts` | `feed`, `get`, `create`, `delete`, `search` |
| `comments` | `list`, `replies`, `create`, `delete` |
| `reactions` | `setOnPost`, `setOnComment`, `addToPost`, `removeFromPost`, `addToComment`, `removeFromComment` |
| `media` | `uploadFile`, `upload`, `start`, `complete`, `get` |
| `blocks` | `list`, `block`, `unblock` |
| `reports` | `reportPost`, `reportComment` |
| `notifications` | `list`, `unreadCount`, `markRead`, `markAllRead` |
| `push` | `register`, `unregister`, `preference`, `setEnabled` |
| `settings` | `get` |
| `live` | `connect` |
| | `initialize`, `signOut`, `setSession`, `clearSession`, `whoAmI`, `currentUser`, `describeCredential` |

Deliberately absent: `members`, `users`, `auth`, and the creator's calls in
`topics`, `posts`, `reports` and `settings`. They need a secret key, which
this client refuses to be built with.

Everything the JavaScript SDK exports is exported from here too: the error
classes, `isErrorOfCode`, `applyReaction` and every type.

## The creator's client

For an app that is given to the creator and nobody else (a CMS), there is a second entry with the calls that run the community: settings, topics, members and roles, pinning, reports, the moderation archive (`creator.archive.list()` and `creator.archive.get(id)`: what reports removed, kept and not deleted), deleting any post or comment, and erasing a user.

```ts
import { createCreatorClient } from "@trackcore/community-react-native/creator";

const creator = createCreatorClient({
  apiKey: secretKeyTheCreatorEntered,   // cm_sk_…
  secretKeyIsEnteredByTheCreatorAndNotBuiltIntoTheApp: true,
});

await creator.settings.update({ searchPageSize: 20 });
```

It takes the creator's **secret key**, which controls the whole community. The key must be entered by the creator while the app runs and kept in the device's secure storage. It must never be written in the app's code or config: anything built into an app can be read by whoever holds the app file. The members' client, `Community`, still refuses a secret key.

## Images from the device

```ts
// With the uri an image picker or the camera gives you.
const image = await Community.instance.media.uploadFile({ uri: asset.uri, type: asset.type });
await Community.instance.posts.create({ topicId, body, mediaIds: [image.id] });
```

`uploadFile` reads the file, then asks for an upload link, sends the file and
finishes. The capture add-on in [`../react-native-capture`](../react-native-capture)
opens the camera or the gallery for you and calls this.

## Live updates

```ts
const connection = Community.instance.live.connect({
  onEvent: (event) => { /* event.type: "post.created", "post.reactions", … */ },
});
connection.close();
```

The connection reopens by itself. When the app returns from the background,
read the posts since your newest one to catch up:

```ts
import { AppState } from "react-native";

AppState.addEventListener("change", async (state) => {
  if (state === "active") prepend((await Community.instance.posts.feed({ after: newestCursor })).posts);
});
```

## Supported versions

React Native 0.72 or later, Hermes or JavaScriptCore. Nothing here touches the
bridge. The package has been tested under Node against a real server; it has
not yet been run on a device.

## Developing

Build the TypeScript SDK's tarball first (`npm pack` in `../typescript`):
this package's dev dependency points at it.

```sh
npm install
npm test
```

The end-to-end test runs against a real server. Never point it at a live one.

```sh
COMMUNITY_TEST_BASE_URL=http://localhost:8080 COMMUNITY_TEST_ADMIN_TOKEN=… npm run test:live
```
