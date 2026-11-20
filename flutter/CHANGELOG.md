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
