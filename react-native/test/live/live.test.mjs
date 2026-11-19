// The device client against a real Community server. Skipped unless these are set:
//
//   COMMUNITY_TEST_BASE_URL     where a test server answers
//   COMMUNITY_TEST_ADMIN_TOKEN  that server's operator token, used to create a throwaway customer
//
// Never point this at a live server: it creates a customer and writes data.
import { test } from "node:test";
import assert from "node:assert/strict";
import { Community, isErrorOfCode, applyReaction } from "../../dist/esm/index.js";

const baseUrl = process.env.COMMUNITY_TEST_BASE_URL;
const adminToken = process.env.COMMUNITY_TEST_ADMIN_TOKEN;
const skip = !baseUrl || !adminToken ? "set COMMUNITY_TEST_BASE_URL and COMMUNITY_TEST_ADMIN_TOKEN to run" : false;

async function admin(path, body) {
  const response = await fetch(baseUrl + path, {
    method: "POST", headers: { Authorization: `Bearer ${adminToken}`, "Content-Type": "application/json" }, body: JSON.stringify(body),
  });
  const reply = await response.json();
  if (!response.ok) throw new Error(`${path}: ${response.status}`);
  return reply;
}
async function withSecret(secretKey, method, path, body) {
  const response = await fetch(baseUrl + path, {
    method, headers: { Authorization: `Bearer ${secretKey}`, "Content-Type": "application/json" }, body: body ? JSON.stringify(body) : undefined,
  });
  return response.json();
}
const until = async (what, check) => {
  const end = Date.now() + 5000;
  while (Date.now() < end) {
    if (check()) return;
    await new Promise((r) => setTimeout(r, 25));
  }
  assert.fail(`timed out waiting for ${what}`);
};

test("two apps in one community, through the device client", { skip }, async () => {
  const slug = "rn" + Date.now().toString(36);
  await admin("/admin/v1/customers", { name: "RN test", slug });
  const secretKey = (await admin(`/admin/v1/customers/${slug}/keys`, { kind: "secret", environment: "test", name: "rn" })).key;
  const publishableKey = (await admin(`/admin/v1/customers/${slug}/keys`, { kind: "publishable", environment: "test", name: "rn" })).key;
  // The creator's backend sets the community up; a device cannot.
  const topic = await withSecret(secretKey, "POST", "/v1/topics", { name: "Workout" });
  await withSecret(secretKey, "PATCH", "/v1/settings", { comment_replies_enabled: true });

  // In this test the socket is Node's, which takes headers as its second argument.
  const webSocket = (url, headers) => new WebSocket(url, { headers });
  const ali = new Community({ apiKey: publishableKey, baseUrl, webSocket });
  const sara = new Community({ apiKey: publishableKey, baseUrl, webSocket });
  await ali.initialize("ali");
  await sara.initialize("sara");

  assert.equal((await ali.community.me()).joined, false);
  await ali.community.join("Annie");
  await assert.rejects(sara.community.join("annie"), (e) => isErrorOfCode(e, "username_taken"));
  await sara.community.join("Mary");
  assert.equal((await sara.settings.get()).comment_replies_enabled, true);
  assert.deepEqual((await sara.topics.list()).topics.map((t) => t.name), ["Workout"]);

  const events = [];
  const connection = sara.live.connect({ onEvent: (e) => events.push(e) });
  await until("the live connection", () => connection.status === "open");

  const post = await ali.posts.create({ topicId: topic.id, body: "Leg day" });
  await until("the new post, live", () => events.some((e) => e.type === "post.created" && e.post_id === post.id));

  // A chip tapped fast: shown at once, settled by the server.
  const shown = applyReaction(post.reactions, "🔥", true);
  assert.deepEqual(shown, [{ emoji: "🔥", count: 1, reacted_by_me: true }]);
  const taps = await Promise.all([true, false, true].map((on) => sara.reactions.setOnPost(post.id, "🔥", on)));
  assert.deepEqual(taps.at(-1).reactions, shown);

  const comment = await sara.comments.create(post.id, { body: "Nice" });
  await ali.comments.create(post.id, { body: "Thanks", parentId: comment.id });
  assert.equal((await sara.posts.get(post.id)).comments_count, 2);
  assert.equal(await ali.notifications.unreadCount(), 2);
  await until("a live notification", () => events.some((e) => e.type === "notification.created"));
  assert.deepEqual((await sara.posts.search({ q: "leg" })).posts.map((p) => p.id), [post.id]);
  assert.equal((await sara.community.member("ali")).username, "Annie");
  await sara.blocks.block("ali");
  assert.deepEqual((await sara.posts.feed()).posts, []);

  // What a device may not do.
  await assert.rejects(sara.posts.delete(post.id), (e) => isErrorOfCode(e, "not_found") || isErrorOfCode(e, "forbidden"));
  connection.close();
  await ali.signOut();
  assert.equal(ali.sessionToken, null);
});
