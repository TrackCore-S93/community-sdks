## 0.1.3

- `posts.update` and `comments.update`: a member edits their own post (text,
  topic, or both) or comment (text). `Post` and `Comment` carry `editedAt`.
- `posts.byMember` and `comments.byMember`: one member's posts and comments,
  newest first, for the tabs of a profile. Each comment comes with its post.
- Live: `post.updated` and `comment.updated`; `previousTopicId` on a post
  that moved to another topic.
- `topics.uploadImage`: upload a topic's image and cover (creator).

## 0.1.1

- `coachChat`: the coaching chat, a member's one-to-one chat with their
  coach. For the member: `get`, `messages`, `send`, `edit`, `delete`,
  `deleteImage`, `markRead`, `search`. For the coach's side, with a secret
  key on a Dart server: `chats`, `memberMessages`, `markMemberRead`,
  `uploadFile` (`startFile`, `completeFile`) and `sendAsCoach`.
- Live events for the chat: `coach_message.created`, `.updated`, `.deleted`
  and `coach_chat.read`. A chat event names no post, so `LiveEvent.postId`
  is now nullable.
- A message from the user's coach is a notification too:
  `NotificationKind.coachMessage`, with `messageId` and `messageExcerpt` on
  `CommunityNotification`. Its `postId` is empty. Reading the chat marks it
  read. A `switch` over every kind needs a case for it.

## 0.1.0

The first version: every route of the Community API, sign-in with a
publishable key, typed models and error codes generated from the API
contract, retries, image upload, rapid-tap-safe reactions and live updates.

### Added since the first build

- `push`: `register`, `unregister`, `preference`, `setEnabled`. Registers the
  phone's Firebase or Expo push token so notifications reach the phone while
  the app is closed. `signOut` unregisters it.
- `settings.update(pushEnabled: …)`: the creator's switch for push.
