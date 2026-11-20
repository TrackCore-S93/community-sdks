## 0.1.3

- A message from the user's coach is now a notification too:
  `NotificationKind.coachMessage`, with `messageId` and `messageExcerpt` on
  `CommunityNotification`. Its `postId` is empty. Reading the chat marks it
  read.

## 0.1.2

- Fixed: coaching-chat events never reached `live.connect().events`. The
  connection dropped every event that named no post, and a chat event names
  none. A chat screen now updates as messages arrive.

## 0.1.1

- `coachChat`: the coaching chat, a member's one-to-one chat with their
  coach. For the member: `get`, `messages`, `send`, `edit`, `delete`,
  `markRead`, `search`. For the coach's side, with a secret key on a Dart
  server: `chats`, `memberMessages`, `markMemberRead`, `uploadFile`
  (`startFile`, `completeFile`) and `sendAsCoach`.
- Live events for the chat: `coach_message.created`, `.updated`, `.deleted`
  and `coach_chat.read`.

## 0.1.0

The first version: every route of the Community API, sign-in with a
publishable key, typed models and error codes generated from the API
contract, retries, image upload, rapid-tap-safe reactions and live updates.

### Added since the first build

- `push`: `register`, `unregister`, `preference`, `setEnabled`. Registers the
  phone's Firebase or Expo push token so notifications reach the phone while
  the app is closed. `signOut` unregisters it.
- `settings.update(pushEnabled: …)`: the creator's switch for push.
