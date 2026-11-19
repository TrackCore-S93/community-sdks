// Try the SDK by hand against a server. Run from the SDK folder, after `npm run build`:
//
//   COMMUNITY_BASE_URL=http://localhost:8080 \
//   COMMUNITY_SECRET_KEY=cm_sk_test_… COMMUNITY_PUBLISHABLE_KEY=cm_pk_test_… \
//   node examples/try.mjs
//
// It plays a creator and one member, and prints each step.
import { Community, isErrorOfCode } from "../dist/esm/index.js";

const baseUrl = process.env.COMMUNITY_BASE_URL ?? "http://localhost:8080";
const secretKey = process.env.COMMUNITY_SECRET_KEY;
const publishableKey = process.env.COMMUNITY_PUBLISHABLE_KEY;
if (!secretKey || !publishableKey) {
  console.error("Set COMMUNITY_SECRET_KEY and COMMUNITY_PUBLISHABLE_KEY (and COMMUNITY_BASE_URL).");
  process.exit(1);
}
const step = (text, value) => console.log(`✔ ${text}`, value === undefined ? "" : value);
const stamp = Date.now().toString(36);

// The creator's backend: a secret key.
const creator = new Community({ apiKey: secretKey, baseUrl });
step("creator key works:", creator.describeCredential());
const settings = await creator.settings.get();
step("settings read: feed mode", settings.feed_mode);
const topic = await creator.topics.create({ name: `Try ${stamp}`, isTrending: true });
step("topic created:", topic.name);

// An app: a publishable key, signing its own user in.
const app = new Community({ apiKey: publishableKey, baseUrl, runtime: "react-native" });
await app.initialize(`try_user_${stamp}`);
step("signed in; session minted:", app.sessionToken ? "yes" : "no");

let me = await app.community.me();
if (!me.joined) {
  try {
    me = await app.community.join(`try.${stamp}`);
  } catch (error) {
    if (!isErrorOfCode(error, "username_taken")) throw error;
  }
}
step("joined as:", me.profile?.username);

const post = await app.posts.create({ topicId: topic.id, body: `Hello from the SDK ${stamp}` });
step("posted:", post.id);
const reacted = await app.reactions.setOnPost(post.id, "🔥", true);
step("reacted:", reacted.reactions.map((r) => `${r.emoji} ${r.count}`).join(" "));
const comment = await app.comments.create(post.id, { body: "First comment" });
step("commented:", comment.id);
const feed = await app.posts.feed({ topicId: topic.id });
step("feed has posts:", feed.posts.length);
const found = await app.posts.search({ q: "hello sdk" });
step("search found:", found.posts.length);

// The creator pins the post, then cleans up.
step("pinned:", (await creator.posts.pin(post.id)).is_pinned);
step("members in the community:", (await creator.members.list()).total);
await app.signOut();
step("signed out");
await creator.topics.delete(topic.id);
step("topic deleted (with its post)");
