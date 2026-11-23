import { test } from "node:test";
import assert from "node:assert/strict";
import * as rn from "../dist/esm/index.js";
import * as core from "@trackcore/community-sdk";

const { Community, createCommunityClient, ConfigurationError, ValidationError, isErrorOfCode } = rn;
const PUBLISHABLE = "cm_pk_test_" + "b".repeat(43);
const SECRET = "cm_sk_test_" + "a".repeat(43);
const TOKEN = "cm_st_" + "c".repeat(43);
const base = "http://api.test";

const json = (status, body) => new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
const session = () => json(201, {
  token: TOKEN, token_type: "opaque", header: "X-Community-Session", external_id: "ali", environment: "test",
  issued_at: new Date().toISOString(), expires_at: new Date(Date.now() + 3600_000).toISOString(), ttl_seconds: 3600,
});
function fakeFetch(replies) {
  const calls = [];
  const queue = [...replies];
  return {
    calls,
    fetch: async (url, init = {}) => {
      calls.push({ url, method: init.method ?? "GET", headers: init.headers ?? {}, body: init.body });
      const next = queue.shift();
      if (!next) throw new Error("no reply queued for " + url);
      return typeof next === "function" ? next() : next;
    },
  };
}

test("a secret key is refused, whatever the runtime looks like", () => {
  for (const build of [() => new Community({ apiKey: SECRET }), () => createCommunityClient({ apiKey: SECRET }), () => Community.instance.configure({ apiKey: SECRET })]) {
    assert.throws(build, (e) => e instanceof ConfigurationError && e.reason === "secret_key_in_browser" && !e.message.includes(SECRET));
  }
  assert.throws(() => new Community({ apiKey: "nope" }), (e) => e.reason === "api_key_malformed");
  assert.throws(() => Community.instance.posts, (e) => e.reason === "not_configured");
});

test("it is the JavaScript SDK underneath: the same classes and helpers", () => {
  for (const name of ["ResourceError", "AuthenticationError", "ConnectionError", "TimeoutError", "isErrorOfCode", "applyReaction", "ALL_ERROR_CODES", "OPERATIONS"]) {
    assert.equal(rn[name], core[name], `${name} is not the core's own`);
  }
  assert.notEqual(rn.Community, core.Community, "the device client is this package's own");
  assert.equal(rn.REACT_NATIVE_SDK_VERSION, "0.1.1");
});

test("signing in mints a session, and calls carry it", async () => {
  const f = fakeFetch([session(), json(200, { joined: false, profile: null }), json(200, { pinned: [], posts: [], next_cursor: null, prev_cursor: null, newest_cursor: null, has_more: false, mode: "infinite_scroll", page_size: 20 })]);
  const client = new Community({ apiKey: PUBLISHABLE, baseUrl: base, fetch: f.fetch });
  assert.equal(client.keyKind, "publishable");
  assert.equal(client.environment, "test");
  await client.initialize("ali");
  assert.equal(f.calls[0].url, base + "/v1/auth/session");
  assert.equal(client.sessionToken, TOKEN);
  assert.equal((await client.community.me()).joined, false);
  assert.equal(f.calls[1].headers["X-Community-Session"], TOKEN);
  assert.equal((await client.posts.feed({ topicId: "cm_top_1" })).mode, "infinite_scroll");
  assert.ok(!JSON.stringify(client).includes(PUBLISHABLE), "the key leaked");
});

test("the creator's calls are not on a device", async () => {
  const f = fakeFetch([session()]);
  const client = new Community({ apiKey: PUBLISHABLE, baseUrl: base, fetch: f.fetch });
  await client.initialize("ali");
  for (const namespace of ["members", "users", "auth", "setUser", "clearUser"]) {
    assert.equal(client[namespace], undefined, `${namespace} is exposed on a device`);
  }
  // Calls that share a namespace with a member's call are refused before anything is sent.
  for (const call of [() => client.posts.pin("cm_post_1"), () => client.topics.create({ name: "X" }), () => client.settings.update({}), () => client.reports.list()]) {
    await assert.rejects(call(), (e) => e instanceof ConfigurationError && e.reason === "secret_key_required");
  }
  assert.equal(f.calls.length, 1);
});

test("a member uses the coaching chat; answering as the coach is not for a device", async () => {
  const sent = { id: "cm_msg_1", author: null, from_coach: false, body: "Hi Coach!", images: [], files: [], is_mine: true, is_read: false, edited_at: null, created_at: "2026-11-20T10:00:00Z" };
  const f = fakeFetch([session(), json(201, sent), json(200, { messages: [sent], older_cursor: "o", newer_cursor: "n", has_older: false, has_newer: false })]);
  const client = new Community({ apiKey: PUBLISHABLE, baseUrl: base, fetch: f.fetch });
  await client.initialize("ali");
  assert.equal((await client.coachChat.send({ body: "Hi Coach!" })).id, "cm_msg_1");
  assert.equal(f.calls[1].url, `${base}/v1/coach-chat/messages`);
  assert.equal((await client.coachChat.messages()).messages.length, 1);
  await assert.rejects(async () => client.coachChat.sendAsCoach({ memberId: "ali", body: "x" }), (e) => e instanceof ConfigurationError && e.reason === "secret_key_required");
  assert.equal(f.calls.length, 3);
});

test("uploadFile reads a file on the device and uploads it", async () => {
  const bytes = new Uint8Array([1, 2, 3, 4]);
  const f = fakeFetch([
    session(),
    () => new Response(new Blob([bytes], { type: "image/jpeg" })),                              // reading file://…
    json(201, { id: "cm_med_1", status: "pending", upload: { method: "PUT", url: "https://storage.test/put?sig=1", expires_at: "" }, max_bytes: 100 }),
    () => new Response(null, { status: 200 }),                                                  // the bucket
    json(200, { id: "cm_med_1", status: "ready", url: "https://storage.test/get", width: 1, height: 1, bytes: 4, attached: false }),
  ]);
  const client = new Community({ apiKey: PUBLISHABLE, baseUrl: base, fetch: f.fetch });
  await client.initialize("ali");
  const image = await client.media.uploadFile({ uri: "file:///photos/1.jpg" });
  assert.equal(image.id, "cm_med_1");
  const [, read, start, put, complete] = f.calls;
  assert.equal(read.url, "file:///photos/1.jpg");
  assert.equal(read.headers.Authorization, undefined, "the key was sent when reading a local file");
  assert.equal(start.url, base + "/v1/media");
  assert.equal(put.url, "https://storage.test/put?sig=1");
  assert.equal(put.headers["Content-Type"], "image/jpeg");
  assert.equal(put.headers.Authorization, undefined, "the key was sent to storage");
  assert.equal(put.body.size, 4);
  assert.equal(complete.url, base + "/v1/media/cm_med_1/complete");
  // The plain upload and the other media calls are still there.
  assert.equal(typeof client.media.upload, "function");
  assert.equal(typeof client.media.get, "function");
  await assert.rejects(client.media.uploadFile({ uri: "" }), ValidationError);
  // A given type wins over the file's own.
  const g = fakeFetch([session(), () => new Response(new Blob([bytes])), json(201, { id: "cm_med_2", status: "pending", upload: { method: "PUT", url: "https://storage.test/put", expires_at: "" }, max_bytes: 100 }), () => new Response(null, { status: 200 }), json(200, { id: "cm_med_2", status: "ready" })]);
  const c2 = new Community({ apiKey: PUBLISHABLE, baseUrl: base, fetch: g.fetch });
  await c2.initialize("ali");
  await c2.media.uploadFile({ uri: "content://media/2", type: "image/heic" });
  assert.equal(g.calls[3].headers["Content-Type"], "image/heic");
});

test("the live connection is opened the way React Native's WebSocket needs", async () => {
  const opened = [];
  class FakeSocket {
    constructor(url, protocols, options) {
      opened.push({ url, protocols, options });
      setTimeout(() => this.onmessage?.({ data: '{"type":"ready"}' }), 1);
      setTimeout(() => this.onmessage?.({ data: '{"type":"post.created","topic_id":"cm_top_1","post_id":"cm_post_9","author_external_id":"sara"}' }), 3);
    }
    send() {}
    close() {}
  }
  const original = globalThis.WebSocket;
  globalThis.WebSocket = FakeSocket;
  try {
    const f = fakeFetch([session()]);
    const client = new Community({ apiKey: PUBLISHABLE, baseUrl: "https://api.test", fetch: f.fetch });
    await client.initialize("ali");
    const events = [];
    const statuses = [];
    const connection = client.live.connect({ topicId: "cm_top_1", onEvent: (e) => events.push(e), onStatus: (s) => statuses.push(s) });
    await new Promise((r) => setTimeout(r, 20));
    assert.equal(opened[0].url, "wss://api.test/v1/live?topic_id=cm_top_1");
    assert.equal(opened[0].protocols, undefined);
    assert.equal(opened[0].options.headers.Authorization, "Bearer " + PUBLISHABLE);
    assert.equal(opened[0].options.headers["X-Community-Session"], TOKEN);
    assert.deepEqual(events.map((e) => e.type + " " + e.post_id), ["post.created cm_post_9"]);
    assert.equal(connection.status, "open");
    connection.close();
    assert.deepEqual(statuses, ["connecting", "open", "closed"]);
  } finally {
    globalThis.WebSocket = original;
  }
});

test("errors are the JavaScript SDK's, with the code to branch on", async () => {
  const f = fakeFetch([session(), json(409, { error: { code: "username_taken", message: "This username is already taken.", request_id: "req_1", retry_after_seconds: null } })]);
  const client = new Community({ apiKey: PUBLISHABLE, baseUrl: base, fetch: f.fetch });
  await client.initialize("ali");
  const error = await client.community.join("Annie").then(() => null, (e) => e);
  assert.ok(isErrorOfCode(error, "username_taken") && error instanceof core.ResourceError);
  assert.equal(error.message, "This username is already taken.");
});

test("push: the phone's token is registered, and signing out unregisters it", async () => {
  const f = fakeFetch([
    session(), json(200, { provider: "expo", platform: "ios", registered: true }),
    json(200, { removed: true }), json(200, {}),
  ]);
  const client = new Community({ apiKey: PUBLISHABLE, baseUrl: base, fetch: f.fetch });
  await client.initialize("ali");
  const device = await client.push.register({ token: "ExponentPushToken[abc]", platform: "ios" });
  assert.equal(device.provider, "expo");
  assert.equal(f.calls[1].method + " " + f.calls[1].url, `PUT ${base}/v1/push/devices`);
  await client.signOut();
  assert.equal(f.calls[2].url, base + "/v1/push/devices/unregister");
  assert.equal(JSON.parse(f.calls[2].body).token, "ExponentPushToken[abc]");
  assert.equal(f.calls[3].method, "DELETE");
});

test("community.summary is there for the card that leads into the community", async () => {
  const f = fakeFetch([session(), json(200, { members_count: 124, avatar_urls: ["https://img/a.webp"] })]);
  const client = new Community({ apiKey: PUBLISHABLE, baseUrl: base, fetch: f.fetch });
  await client.initialize("ali");
  const summary = await client.community.summary();
  assert.equal(summary.members_count, 124);
  assert.equal(f.calls[1].url, base + "/v1/community/summary");
});

// ---- the creator's client ----
const creator = await import("../dist/esm/creator.js");
const stated = { secretKeyIsEnteredByTheCreatorAndNotBuiltIntoTheApp: true };

test("creator: the client needs a secret key and the statement about where it comes from", () => {
  assert.throws(() => creator.createCreatorClient({ apiKey: SECRET, baseUrl: base }), (e) => e instanceof ConfigurationError && /never be built into an app/.test(e.message));
  assert.throws(() => creator.createCreatorClient({ apiKey: PUBLISHABLE, baseUrl: base, ...stated }), (e) => e instanceof ConfigurationError && e.reason === "secret_key_required");
  assert.throws(() => creator.createCreatorClient({ baseUrl: base, ...stated }), ConfigurationError);
  // The members' client still refuses a secret key.
  assert.throws(() => new Community({ apiKey: SECRET, baseUrl: base }), ConfigurationError);
});

test("creator: settings, topics, roles, pins, reports and erasing a user are sent with the secret key and no user", async () => {
  const f = fakeFetch([
    json(200, { search_page_size: 20 }), json(201, { id: "cm_top_1", name: "Workout" }), json(200, { external_id: "u1", role: "coach" }),
    json(200, { id: "cm_post_1", is_pinned: true }), json(200, { reports: [], report_threshold: 5 }), json(200, { external_id: "u1", deleted: true }),
    json(200, { members: [], total: 0, next_cursor: null }), json(200, { id: "cm_post_1", deleted: true }),
    json(200, { archived: [{ id: "cm_arc_1" }], next_cursor: null }), json(200, { id: "cm_arc_1", body: "spam" }),
  ]);
  const c = creator.createCreatorClient({ apiKey: SECRET, baseUrl: base, fetch: f.fetch, ...stated });
  assert.equal((await c.settings.update({ searchPageSize: 20 })).search_page_size, 20);
  await c.topics.create({ name: "Workout" });
  await c.members.setRole("u1", "coach");
  await c.posts.pin("cm_post_1");
  await c.reports.list();
  await c.users.delete("u1");
  await c.members.list({ q: "an" });
  await c.posts.delete("cm_post_1");
  assert.equal((await c.archive.list({ limit: 10 })).archived[0].id, "cm_arc_1");
  assert.equal((await c.archive.get("cm_arc_1")).body, "spam");
  assert.deepEqual(f.calls.map((x) => `${x.method} ${x.url.replace(base, "")}`), [
    "PATCH /v1/settings", "POST /v1/topics", "PATCH /v1/community/members/u1", "PUT /v1/posts/cm_post_1/pin",
    "GET /v1/reports", "DELETE /v1/users/u1", "GET /v1/community/members?q=an", "DELETE /v1/posts/cm_post_1",
    "GET /v1/moderation/archive?limit=10", "GET /v1/moderation/archive/cm_arc_1",
  ]);
  for (const call of f.calls) {
    assert.equal(call.headers.Authorization, "Bearer " + SECRET);
    assert.equal(call.headers["X-External-Id"], undefined);
    assert.equal(call.headers["X-Community-Session"], undefined);
  }
  assert.ok(!JSON.stringify(c).includes(SECRET), "the key leaked");
  assert.ok(!c.describeCredential().includes(SECRET));
  assert.equal(c.environment, "test");
});
