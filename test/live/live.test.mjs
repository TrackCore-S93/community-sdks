// The SDK against a real Community server. Skipped unless these are set:
//
//   COMMUNITY_TEST_BASE_URL     where a test server answers, e.g. http://localhost:8099
//   COMMUNITY_TEST_ADMIN_TOKEN  that server's operator token, used to create a
//                               throwaway customer and its keys
//
// Never point this at a live server: it creates a customer and writes data.
import { test } from "node:test";
import assert from "node:assert/strict";
import { Community, isErrorOfCode, AuthorizationError, ResourceError } from "../../dist/esm/index.js";

const baseUrl = process.env.COMMUNITY_TEST_BASE_URL;
const adminToken = process.env.COMMUNITY_TEST_ADMIN_TOKEN;
const skip = !baseUrl || !adminToken ? "set COMMUNITY_TEST_BASE_URL and COMMUNITY_TEST_ADMIN_TOKEN to run" : false;

async function admin(path, body) {
  const response = await fetch(baseUrl + path, {
    method: "POST",
    headers: { Authorization: `Bearer ${adminToken}`, "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const reply = await response.json();
  if (!response.ok) throw new Error(`${path}: ${response.status} ${JSON.stringify(reply)}`);
  return reply;
}

async function onboard() {
  const slug = "sdk" + Date.now().toString(36) + Math.floor(Math.random() * 1e6).toString(36);
  await admin("/admin/v1/customers", { name: "SDK test", slug });
  const secret = await admin(`/admin/v1/customers/${slug}/keys`, { kind: "secret", environment: "test", name: "sdk" });
  const publishable = await admin(`/admin/v1/customers/${slug}/keys`, { kind: "publishable", environment: "test", name: "sdk" });
  return { secretKey: secret.key, publishableKey: publishable.key };
}

const until = async (what, check, ms = 5000) => {
  const end = Date.now() + ms;
  while (Date.now() < end) {
    if (check()) return;
    await new Promise((r) => setTimeout(r, 25));
  }
  assert.fail(`timed out waiting for ${what}`);
};

test("a whole community, through the SDK", { skip }, async () => {
  const { secretKey, publishableKey } = await onboard();

  // The creator's backend: a secret key.
  const creator = new Community({ apiKey: secretKey, baseUrl, runtime: "server" });
  assert.equal((await creator.whoAmI()).key_kind, "secret");
  const settings = await creator.settings.update({ commentRepliesEnabled: true, searchPageSize: 5 });
  assert.equal(settings.comment_replies_enabled, true);
  assert.equal(settings.feed_page_size, undefined, "the page size is the app's, not a setting");
  const workout = await creator.topics.create({ name: "Workout", isTrending: true });
  const food = await creator.topics.create({ name: "Food" });
  await assert.rejects(creator.topics.create({ name: "workout" }), (e) => isErrorOfCode(e, "topic_name_taken") && e instanceof ResourceError);
  assert.equal((await creator.topics.update(food.id, { description: "Meals" })).description, "Meals");

  // Two apps: publishable key, each signing in its own user.
  const ali = new Community({ apiKey: publishableKey, baseUrl, runtime: "react-native" });
  const sara = new Community({ apiKey: publishableKey, baseUrl, runtime: "react-native" });
  await ali.initialize("ali");
  await sara.initialize("sara");
  assert.equal((await ali.currentUser()).external_id, "ali");
  assert.equal((await ali.currentUser()).via_session, true);

  // Joining.
  assert.equal((await ali.community.me()).joined, false);
  await assert.rejects(ali.posts.create({ topicId: workout.id, body: "too early" }), (e) => isErrorOfCode(e, "community_join_required") && e instanceof AuthorizationError);
  assert.equal((await ali.community.usernameAvailable("Annie")).available, true);
  assert.equal((await ali.community.join("Annie")).profile.username, "Annie");
  assert.equal((await sara.community.usernameAvailable("annie")).available, false);
  await assert.rejects(sara.community.join("ANNIE"), (e) => isErrorOfCode(e, "username_taken"));
  await sara.community.join("Mary");
  const bad = await sara.community.updateProfile({ username: "x" }).then(() => null, (e) => e);
  assert.ok(isErrorOfCode(bad, "validation_failed") && bad.fields.username, "a bad username names the field");
  assert.equal((await sara.community.updateProfile({ bio: "Runner", username: "Mary.K" })).profile.bio, "Runner");
  assert.equal((await ali.community.member("sara")).username, "Mary.K");
  assert.equal((await ali.community.member("ali")).is_me, true);

  // Topics as a member sees them.
  assert.deepEqual((await ali.topics.list()).topics.map((t) => t.name).sort(), ["Food", "Workout"]);
  assert.deepEqual((await ali.topics.list({ trending: true })).topics.map((t) => t.name), ["Workout"]);

  // Live: sara's app listens while ali acts. Skipped where the runtime has no WebSocket that sends headers.
  const events = [];
  const WS = globalThis.WebSocket;
  const live = WS
    ? new Community({ apiKey: publishableKey, baseUrl, runtime: "server", webSocket: (url, headers) => new WS(url, { headers }) })
    : null;
  let connection = null;
  if (live) {
    await live.initialize("sara");
    connection = live.live.connect({ onEvent: (e) => events.push(e) });
    await until("the live connection", () => connection.status === "open");
  }

  // Posts, with a retry-proof key.
  const first = await ali.posts.create({ topicId: workout.id, body: "Leg day protein", idempotencyKey: "post-1" });
  const again = await ali.posts.create({ topicId: workout.id, body: "Leg day protein", idempotencyKey: "post-1" });
  assert.equal(again.id, first.id, "the same key posted twice");
  await ali.posts.create({ topicId: food.id, body: "protein pancakes" });
  await sara.posts.create({ topicId: workout.id, body: "rest day" });
  if (connection) {
    await until("post events", () => events.filter((e) => e.type === "post.created").length >= 3);
    assert.equal(events.find((e) => e.post_id === first.id).author_external_id, "ali");
  }

  // The feed, a page at a time: the app asks for 2 per page.
  let page = await sara.posts.feed({ limit: 2 });
  assert.equal(page.posts.length, 2);
  assert.equal(page.page_size, 2);
  assert.equal(page.posts[0].body, "rest day");
  assert.equal(page.posts[0].is_mine, true);
  const older = await sara.posts.feed({ limit: 2, before: page.next_cursor });
  assert.deepEqual(older.posts.map((p) => p.body), ["Leg day protein"]);
  assert.equal(older.next_cursor, null);
  assert.deepEqual((await sara.posts.feed({ topicId: food.id })).posts.map((p) => p.body), ["protein pancakes"]);

  // Search.
  assert.deepEqual((await sara.posts.search({ q: "prot" })).posts.map((p) => p.body), ["protein pancakes", "Leg day protein"]);
  assert.deepEqual((await sara.posts.search({ q: "protein", topicId: workout.id })).posts.map((p) => p.body), ["Leg day protein"]);
  assert.deepEqual((await sara.posts.search({ q: "nothing here" })).posts, []);

  // Reactions, including a chip tapped fast.
  assert.deepEqual((await sara.reactions.addToPost(first.id, "❤️")).reactions, [{ emoji: "❤️", count: 1, reacted_by_me: true }]);
  await ali.reactions.addToPost(first.id, "❤️");
  const taps = await Promise.all([true, false, true, false, true, false, true].map((on) => sara.reactions.setOnPost(first.id, "🔥", on)));
  assert.equal(taps.at(-1).reactions.find((r) => r.emoji === "🔥").count, 1);
  const settled = (await ali.posts.get(first.id)).reactions;
  assert.deepEqual(settled.map((r) => [r.emoji, r.count]).sort(), [["❤️", 2], ["🔥", 1]]);
  assert.equal((await sara.reactions.removeFromPost(first.id, "🔥")).reactions.length, 1);

  // Comments and replies.
  const comment = await sara.comments.create(first.id, { body: "Nice work" });
  const reply = await ali.comments.create(first.id, { body: "Thanks", parentId: comment.id });
  assert.equal(reply.parent_id, comment.id);
  assert.equal((await ali.comments.list(first.id)).comments[0].replies_count, 1);
  assert.equal((await ali.comments.replies(comment.id)).comments[0].body, "Thanks");
  await ali.reactions.setOnComment(comment.id, "👍", true);
  assert.equal((await ali.posts.get(first.id)).comments_count, 2);

  // Notifications: ali is told what sara did, and sara that ali replied.
  const inbox = await ali.notifications.list();
  assert.deepEqual(inbox.notifications.map((n) => n.kind).sort(), ["post_comment", "post_reaction"]);
  assert.equal(await ali.notifications.unreadCount(), 2);
  assert.equal((await ali.notifications.markRead(inbox.notifications[0].id)).unread_count, 1);
  await ali.notifications.markAllRead();
  assert.equal(await ali.notifications.unreadCount(), 0);
  assert.deepEqual((await sara.notifications.list()).notifications.map((n) => n.kind).sort(), ["comment_reaction", "comment_reply"]);
  if (connection) await until("a live notification", () => events.some((e) => e.type === "notification.created"));

  // The creator's dashboard: members, roles, pinning, reports.
  const members = await creator.members.list();
  assert.deepEqual(members.members.map((m) => m.username), ["Annie", "Mary.K"]);
  assert.equal(members.total, 2);
  assert.deepEqual((await creator.members.list({ q: "mary" })).members.map((m) => m.external_id), ["sara"]);
  assert.equal((await creator.members.setRole("ali", "coach")).role, "coach");
  assert.equal((await sara.posts.get(first.id)).author.role, "coach");
  assert.equal((await creator.posts.pin(first.id)).is_pinned, true);
  page = await sara.posts.feed();
  assert.deepEqual(page.pinned.map((p) => p.id), [first.id]);
  assert.ok(!page.posts.some((p) => p.id === first.id), "a pinned post was repeated in the list");
  assert.equal((await creator.posts.unpin(first.id)).is_pinned, false);
  assert.equal((await sara.reports.reportPost(first.id, "Spam content")).reported, true);
  assert.equal((await sara.reports.reportPost(first.id, "Spam content")).already_reported, true);
  const reports = await creator.reports.list();
  assert.equal(reports.reports[0].reason, "Spam content");
  assert.equal(reports.report_threshold, 5);

  // Blocking hides each from the other.
  assert.equal((await sara.blocks.block("ali")).username, "Annie");
  assert.deepEqual((await sara.blocks.list()).blocked.map((b) => b.external_id), ["ali"]);
  assert.deepEqual((await sara.posts.feed()).posts.map((p) => p.body), ["rest day"]);
  await assert.rejects(sara.community.member("ali"), (e) => isErrorOfCode(e, "not_found"));
  assert.equal((await sara.blocks.unblock("ali")).unblocked, true);

  // Deleting, signing out, erasing.
  await assert.rejects(sara.posts.delete(first.id), (e) => isErrorOfCode(e, "forbidden"));
  assert.equal((await ali.posts.delete(first.id)).deleted, true);
  assert.equal((await creator.comments.delete("cm_cmt_00000000000000000000000000")).deleted, false);
  connection?.close();
  if (connection) assert.equal(connection.status, "closed");
  const token = ali.sessionToken;
  await ali.signOut();
  assert.equal(ali.sessionToken, null);
  const stale = new Community({ apiKey: publishableKey, baseUrl, runtime: "react-native" });
  stale.setSession(token);
  await assert.rejects(stale.community.me(), (e) => isErrorOfCode(e, "session_invalid"));
  assert.equal((await creator.users.delete("sara")).deleted, true);
  assert.equal((await creator.members.list()).total, 1);
  assert.equal((await creator.topics.delete(workout.id)).deleted, true);
});
