import { test } from "node:test";
import assert from "node:assert/strict";
import {
  Community, ConfigurationError, AuthenticationError, AuthorizationError, ResourceError, RequestError, ServerError,
  MaintenanceError, DependencyError, RateLimitError, ConnectionError, TimeoutError, AbortError, ProtocolError,
  ValidationError, isErrorOfCode, isAPIError, isCommunityError, errorCodeSpec, ALL_ERROR_CODES, OPERATIONS, applyReaction,
} from "../dist/esm/index.js";
import { SECRET, PUBLISHABLE, TOKEN, json, failure, session, fakeFetch, quick } from "./helpers.mjs";

const base = "http://api.test";
const reason = (fn) => { try { fn(); } catch (e) { return e instanceof ConfigurationError ? e.reason : `other: ${e}`; } return "no error"; };

test("a client says what it was built with and never shows its key", () => {
  const { fetch } = fakeFetch([]);
  const c = new Community({ apiKey: SECRET, baseUrl: base + "/", fetch, runtime: "server" });
  assert.equal(c.keyKind, "secret");
  assert.equal(c.environment, "test");
  assert.equal(c.baseUrl, base);
  assert.equal(c.describeCredential(), "cm_sk_test_…aaa");
  const shown = JSON.stringify(c) + JSON.stringify(Object.entries(c)) + String(c);
  assert.ok(!shown.includes(SECRET), "the key leaked");
});

test("bad configuration fails before anything is sent", () => {
  const { fetch, calls } = fakeFetch([]);
  assert.equal(reason(() => new Community({ apiKey: "nope", fetch })), "api_key_malformed");
  assert.equal(reason(() => new Community({ apiKey: SECRET, baseUrl: "ftp://x", fetch, runtime: "server" })), "base_url_invalid");
  assert.equal(reason(() => new Community({ apiKey: SECRET, baseUrl: "not a url", fetch, runtime: "server" })), "base_url_invalid");
  assert.equal(reason(() => new Community({ apiKey: SECRET, fetch, runtime: "browser" })), "secret_key_in_browser");
  assert.equal(reason(() => new Community({ apiKey: SECRET, fetch, runtime: "react-native" })), "secret_key_in_browser");
  assert.equal(reason(() => new Community({ apiKey: PUBLISHABLE, fetch, timeoutMs: 0 })), "option_invalid");
  assert.equal(reason(() => new Community({ apiKey: PUBLISHABLE, fetch, sessionTtlSeconds: 90000 })), "option_invalid");
  assert.equal(reason(() => new Community({ apiKey: PUBLISHABLE, fetch, retry: { maxAttempts: 0 } })), "option_invalid");
  assert.equal(reason(() => Community.instance.posts), "not_configured");
  // A publishable key is fine in a browser.
  assert.equal(new Community({ apiKey: PUBLISHABLE, baseUrl: base, fetch, runtime: "browser" }).keyKind, "publishable");
  // A secret key in an unknown runtime warns and continues.
  const warnings = [];
  new Community({ apiKey: SECRET, baseUrl: base, fetch, runtime: "unknown", warn: (m) => warnings.push(m) });
  assert.equal(warnings.length, 1);
  assert.ok(!warnings[0].includes(SECRET));
  assert.equal(calls.length, 0);
});

test("the shared instance is configured once and used anywhere", async () => {
  const { fetch, calls } = fakeFetch([json(200, { customer_id: "cm_cus_1", key_id: "cm_key_1", key_kind: "secret", environment: "test" })]);
  Community.instance.configure({ apiKey: SECRET, baseUrl: base, fetch, runtime: "server" });
  const who = await Community.instance.whoAmI();
  assert.equal(who.key_kind, "secret");
  assert.equal(calls[0].url, base + "/v1/me");
  assert.equal(calls[0].headers.Authorization, "Bearer " + SECRET);
});

test("with a secret key, initialize names the user and mints nothing", async () => {
  const { fetch, calls } = fakeFetch([json(200, { joined: false, profile: null })]);
  const c = new Community({ apiKey: SECRET, baseUrl: base, fetch, runtime: "server" });
  assert.equal(reason(() => c.setUser(" ali ")), "external_id_untrimmed");
  assert.equal(reason(() => c.setUser("")), "external_id_empty");
  assert.equal(reason(() => c.setUser("x".repeat(256))), "external_id_too_long");
  await assert.rejects(c.community.me(), (e) => e instanceof ConfigurationError && e.reason === "no_user");
  await c.initialize("ali");
  assert.equal(calls.length, 0);
  await c.community.me();
  assert.equal(calls[0].headers["X-External-Id"], "ali");
  assert.equal(calls[0].headers["X-Community-Session"], undefined);
  await c.signOut();
  assert.equal(c.externalId, null);
  assert.equal(calls.length, 1, "signing out with a secret key makes no call");
});

test("with a publishable key, initialize mints a session and uses it", async () => {
  const { fetch, calls } = fakeFetch([session("ali", 3600), json(200, { joined: false, profile: null }), json(204)]);
  const events = [];
  const c = new Community({ apiKey: PUBLISHABLE, baseUrl: base, fetch, sessionTtlSeconds: 3600, onDiagnostic: (d) => events.push(d) });
  await assert.rejects(c.community.me(), (e) => e instanceof ConfigurationError && e.reason === "no_user");
  await c.initialize("ali");
  assert.equal(calls[0].method + " " + calls[0].url, `POST ${base}/v1/auth/session`);
  assert.deepEqual(calls[0].body, { external_id: "ali", ttl_seconds: 3600 });
  assert.equal(c.sessionToken, TOKEN);
  await c.community.me();
  assert.equal(calls[1].headers["X-Community-Session"], TOKEN);
  assert.equal(calls[1].headers["X-External-Id"], undefined);
  await c.signOut();
  assert.equal(calls[2].method + " " + calls[2].url, `DELETE ${base}/v1/auth/session`);
  assert.equal(c.sessionToken, null);
  assert.deepEqual(events.map((e) => e.type), ["session_minted", "session_ended"]);
  assert.ok(!JSON.stringify(events).includes(TOKEN), "a diagnostic carried the token");
});

test("an expired session is renewed once, and a session near its end before use", async () => {
  // The server says the session ended early: mint again and repeat the call.
  let f = fakeFetch([session(), failure(401, "session_invalid"), session(), json(200, { unread_count: 4 })]);
  let c = new Community({ apiKey: PUBLISHABLE, baseUrl: base, fetch: f.fetch });
  await c.initialize("ali");
  assert.equal(await c.notifications.unreadCount(), 4);
  assert.deepEqual(f.calls.map((x) => x.url.replace(base, "")), ["/v1/auth/session", "/v1/notifications/unread-count", "/v1/auth/session", "/v1/notifications/unread-count"]);
  // Renewal that fails again is not repeated for ever.
  f = fakeFetch([session(), failure(401, "session_invalid"), session(), failure(401, "session_invalid")]);
  c = new Community({ apiKey: PUBLISHABLE, baseUrl: base, fetch: f.fetch });
  await c.initialize("ali");
  await assert.rejects(c.notifications.unreadCount(), (e) => isErrorOfCode(e, "session_invalid"));
  assert.equal(f.calls.length, 4);
  // A session in its last minute is renewed before the call is made.
  f = fakeFetch([session("ali", 30), session("ali", 3600), json(200, { blocked: [] })]);
  c = new Community({ apiKey: PUBLISHABLE, baseUrl: base, fetch: f.fetch });
  await c.initialize("ali");
  await c.blocks.list();
  assert.deepEqual(f.calls.map((x) => x.url.replace(base, "")), ["/v1/auth/session", "/v1/auth/session", "/v1/blocks"]);
  // A token from your own backend is used as given and never re-minted.
  f = fakeFetch([failure(401, "session_invalid")]);
  c = new Community({ apiKey: PUBLISHABLE, baseUrl: base, fetch: f.fetch });
  c.setSession(TOKEN);
  await assert.rejects(c.blocks.list(), AuthenticationError);
  assert.equal(f.calls.length, 1);
  assert.equal(reason(() => c.setSession("not-a-token")), "session_token_malformed");
});

test("creator calls need a secret key, checked before sending", async () => {
  const { fetch, calls } = fakeFetch([session()]);
  const c = new Community({ apiKey: PUBLISHABLE, baseUrl: base, fetch });
  await c.initialize("ali");
  for (const call of [() => c.topics.create({ name: "X" }), () => c.settings.update({ searchPageSize: 10 }), () => c.posts.pin("cm_post_1"),
    () => c.members.list(), () => c.members.setRole("ali", "coach"), () => c.reports.list(), () => c.archive.list(), () => c.archive.get("cm_arc_1"), () => c.users.delete("ali")]) {
    await assert.rejects(call(), (e) => e instanceof ConfigurationError && e.reason === "secret_key_required");
  }
  assert.equal(calls.length, 1);
});

test("each failure becomes a typed error", async () => {
  const cases = [
    [400, "invalid_request", RequestError], [401, "credential_revoked", AuthenticationError], [403, "community_join_required", AuthorizationError],
    [404, "not_found", ResourceError], [409, "username_taken", ResourceError], [422, "validation_failed", ResourceError],
    [413, "media_too_large", RequestError], [429, "rate_limited", RateLimitError], [500, "internal_error", ServerError],
    [503, "service_unavailable", MaintenanceError], [504, "timeout", DependencyError],
  ];
  for (const [status, code, cls] of cases) {
    const { fetch } = fakeFetch([failure(status, code, code === "validation_failed" ? { fields: { username: "is too short" } } : {})]);
    const c = new Community({ apiKey: SECRET, baseUrl: base, fetch, runtime: "server", retry: { maxAttempts: 1 } });
    c.setUser("ali");
    const error = await c.community.join("Annie").then(() => null, (e) => e);
    assert.ok(error instanceof cls, `${status} ${code} was ${error?.constructor?.name}`);
    assert.ok(isAPIError(error) && isCommunityError(error) && isErrorOfCode(error, code));
    assert.equal(error.status, status);
    assert.equal(error.requestId, "req_1");
    assert.ok(error.docsUrl.endsWith("#" + code));
    if (code === "validation_failed") assert.deepEqual(error.fields, { username: "is too short" });
  }
  assert.equal(errorCodeSpec("username_taken").status, 409);
  assert.equal(ALL_ERROR_CODES.length, 28);
});

test("a reply that is not from the API is a ProtocolError that hides its body", async () => {
  const page = "<html>captive portal " + "x".repeat(5000) + "</html>";
  for (const reply of [new Response(page, { status: 502 }), new Response(page, { status: 200 }), json(400, { message: "no envelope" })]) {
    const { fetch } = fakeFetch([reply]);
    const c = new Community({ apiKey: SECRET, baseUrl: base, fetch, runtime: "server", retry: { maxAttempts: 1 } });
    const error = await c.settings.get().then(() => null, (e) => e);
    assert.ok(error instanceof ProtocolError, String(error));
    assert.ok(!error.message.includes("captive"));
    assert.ok(!JSON.stringify(error).includes("captive"));
    assert.ok(error.bodySample.length <= 2048);
  }
});

test("retries: what is tried again and what is not", async () => {
  const settings = json.bind(null, 200, { search_page_size: 10 });
  const client = (replies, retry = {}) => {
    const f = fakeFetch(replies);
    const events = [];
    const c = new Community({ apiKey: SECRET, baseUrl: base, fetch: f.fetch, runtime: "server", retry: { ...quick, ...retry }, onDiagnostic: (d) => events.push(d) });
    c.setUser("ali");
    return { c, f, events };
  };
  // 503, a dropped connection and 504 are retried up to maxAttempts.
  let t = client([failure(503, "service_unavailable"), new TypeError("fetch failed"), settings()]);
  await t.c.settings.get();
  assert.equal(t.f.calls.length, 3);
  assert.deepEqual(t.events.map((e) => e.reason), ["http_503", "connection"]);
  t = client([failure(504, "timeout"), failure(504, "timeout"), failure(504, "timeout")]);
  await assert.rejects(t.c.settings.get(), DependencyError);
  assert.equal(t.f.calls.length, 3);
  t = client([new TypeError("fetch failed"), new TypeError("fetch failed"), new TypeError("fetch failed")]);
  await assert.rejects(t.c.settings.get(), ConnectionError);
  // 500 and 4xx are never retried.
  for (const reply of [failure(500, "internal_error"), failure(404, "not_found"), failure(422, "validation_failed"), failure(401, "credential_unknown")]) {
    t = client([reply, settings()]);
    await assert.rejects(t.c.settings.get());
    assert.equal(t.f.calls.length, 1);
  }
  // 502 is retried once.
  t = client([json(502, { error: { code: "service_unavailable", message: "bad gateway", retry_after_seconds: null } }), settings()], { maxAttempts: 5 });
  await t.c.settings.get();
  t = client([1, 2, 3].map(() => json(502, { error: { code: "service_unavailable", message: "bad gateway", retry_after_seconds: null } })), { maxAttempts: 5 });
  await assert.rejects(t.c.settings.get());
  assert.equal(t.f.calls.length, 2);
  // A write is repeated only when repeating it is safe: a post carries a key, so it is.
  t = client([failure(503, "service_unavailable"), json(201, { id: "cm_post_1" })]);
  await t.c.posts.create({ topicId: "cm_top_1", body: "hi" });
  assert.equal(t.f.calls.length, 2);
  assert.ok(t.f.calls[0].headers["Idempotency-Key"]);
  assert.equal(t.f.calls[0].headers["Idempotency-Key"], t.f.calls[1].headers["Idempotency-Key"]);
  t = client([failure(503, "service_unavailable"), json(201, { id: "cm_post_1" })]);
  await t.c.posts.create({ topicId: "cm_top_1", body: "hi", idempotencyKey: "mine" });
  assert.equal(t.f.calls[1].headers["Idempotency-Key"], "mine");
  // Creating a topic and editing a profile are not, so they are sent once.
  t = client([failure(503, "service_unavailable"), json(201, {})]);
  await assert.rejects(t.c.topics.create({ name: "Workout" }), MaintenanceError);
  assert.equal(t.f.calls.length, 1);
  t = client([new TypeError("fetch failed"), json(200, {})]);
  await assert.rejects(t.c.community.updateProfile({ bio: "x" }), ConnectionError);
  assert.equal(t.f.calls.length, 1);
  // Retry-After from the server sets the wait.
  t = client([json(503, { error: { code: "service_unavailable", message: "wait", retry_after_seconds: null } }, { "Retry-After": "0.05" }), settings()]);
  await t.c.settings.get();
  assert.equal(t.events[0].delayMs, 50);
  // maxAttempts 1 never retries.
  t = client([failure(503, "service_unavailable"), settings()], { maxAttempts: 1 });
  await assert.rejects(t.c.settings.get(), MaintenanceError);
});

test("timeouts, the deadline and the caller's own signal", async () => {
  let f = fakeFetch(["hang", "hang"]);
  let c = new Community({ apiKey: SECRET, baseUrl: base, fetch: f.fetch, runtime: "server", timeoutMs: 20, retry: { ...quick, maxAttempts: 2 } });
  await assert.rejects(c.settings.get(), (e) => e instanceof TimeoutError && e.kind === "attempt");
  assert.equal(f.calls.length, 2);
  f = fakeFetch(["hang", "hang", "hang", "hang", "hang", "hang"]);
  c = new Community({ apiKey: SECRET, baseUrl: base, fetch: f.fetch, runtime: "server", timeoutMs: 30, deadlineMs: 70, retry: { baseDelayMs: 1, maxDelayMs: 1, maxAttempts: 50 } });
  const started = Date.now();
  await assert.rejects(c.settings.get(), TimeoutError);
  assert.ok(Date.now() - started < 400, "the deadline did not bound the call");
  f = fakeFetch(["hang"]);
  c = new Community({ apiKey: SECRET, baseUrl: base, fetch: f.fetch, runtime: "server" });
  const controller = new AbortController();
  const pending = c.settings.get({ signal: controller.signal });
  await new Promise((r) => setTimeout(r, 5));
  controller.abort();
  await assert.rejects(pending, AbortError);
  assert.equal(f.calls.length, 1, "an aborted call was retried");
  // A signal that has already fired sends nothing at all.
  f = fakeFetch([]);
  c = new Community({ apiKey: SECRET, baseUrl: base, fetch: f.fetch, runtime: "server" });
  await assert.rejects(c.settings.get({ signal: controller.signal }), AbortError);
  assert.equal(f.calls.length, 0);
});

test("requests are shaped as the API expects", async () => {
  const ok = () => json(200, {});
  const { fetch, calls } = fakeFetch(Array.from({ length: 12 }, ok));
  const c = new Community({ apiKey: SECRET, baseUrl: base, fetch, runtime: "server", headers: { "X-App-Version": "1.2.0", Authorization: "Bearer stolen" } });
  c.setUser("user 42");
  await c.posts.feed({ topicId: "cm_top_1", limit: 10, before: "abc" });
  await c.posts.search({ q: "protein shake" });
  await c.reactions.addToPost("cm_post_1", "❤️");
  await c.community.updateProfile({ bio: "", avatarMediaId: "cm_med_1" });
  await c.topics.list({ trending: true });
  await c.comments.create("cm_post_1", { body: "hi", parentId: "cm_cmt_1" });
  await c.settings.get();
  await c.community.member("a/b");
  const [feed, search, react, edit, topics, comment, settings, member] = calls;
  assert.equal(feed.url, `${base}/v1/posts?topic_id=cm_top_1&limit=10&before=abc`);
  assert.equal(search.url, `${base}/v1/search/posts?q=protein+shake`);
  assert.equal(react.method + " " + react.url, `PUT ${base}/v1/posts/cm_post_1/reactions/${encodeURIComponent("❤️")}`);
  assert.deepEqual(edit.body, { bio: "", avatar_media_id: "cm_med_1" });
  assert.equal(topics.url, `${base}/v1/topics?trending=true`);
  assert.deepEqual(comment.body, { body: "hi", parent_id: "cm_cmt_1" });
  assert.equal(member.url, `${base}/v1/community/members/a%2Fb`);
  assert.equal(feed.headers["X-External-Id"], "user 42");
  assert.equal(feed.headers["X-App-Version"], "1.2.0");
  assert.equal(feed.headers.Authorization, "Bearer " + SECRET, "an extra header overrode Authorization");
  assert.equal(settings.headers["X-External-Id"], undefined, "settings are not read for a user");
  // Arguments that cannot be right fail locally.
  await assert.rejects(async () => c.posts.search({ q: "a" }), ValidationError);
  await assert.rejects(async () => c.posts.feed({ before: "a", after: "b" }), ValidationError);
  await assert.rejects(async () => c.posts.get(""), ValidationError);
  assert.equal(calls.length, 8);
});

test("the SDK has a call for every route in the contract", () => {
  const { fetch } = fakeFetch([]);
  const c = new Community({ apiKey: SECRET, baseUrl: base, fetch, runtime: "server" });
  assert.equal(OPERATIONS.length, 55);
  for (const op of OPERATIONS) {
    const [namespace, method] = op.sdk.split(".");
    const owner = namespace === "client" ? c : c[namespace];
    assert.equal(typeof owner?.[method], "function", `${op.method} ${op.path} names ${op.sdk}, which the SDK does not have`);
  }
});

test("a reaction chip tapped fast sends one request at a time and ends where the user left it", async () => {
  const gate = [];
  const sent = [];
  const fetch = (url, init) => new Promise((resolve) => {
    sent.push(init.method);
    gate.push(() => resolve(json(200, { post_id: "cm_post_1", reactions: init.method === "PUT" ? [{ emoji: "🔥", count: 1, reacted_by_me: true }] : [] })));
  });
  const c = new Community({ apiKey: SECRET, baseUrl: base, fetch, runtime: "server" });
  c.setUser("ali");
  // on, off, on, off, on: five taps while the first request is still out.
  const taps = [true, false, true, false, true].map((on) => c.reactions.setOnPost("cm_post_1", "🔥", on));
  await new Promise((r) => setTimeout(r, 5));
  assert.deepEqual(sent, ["PUT"], "more than one request was in flight");
  gate.shift()();
  const results = await Promise.all(taps);
  assert.deepEqual(sent, ["PUT"], "the final state matched what was sent, so nothing more was needed");
  for (const r of results) assert.equal(r.reactions[0]?.count, 1);
  // on then off: the off is sent after the on finishes, and never overlaps it.
  sent.length = 0;
  const two = [c.reactions.setOnPost("cm_post_1", "🔥", true), c.reactions.setOnPost("cm_post_1", "🔥", false)];
  await new Promise((r) => setTimeout(r, 5));
  assert.deepEqual(sent, ["PUT"]);
  gate.shift()();
  await new Promise((r) => setTimeout(r, 5));
  assert.deepEqual(sent, ["PUT", "DELETE"]);
  gate.shift()();
  for (const r of await Promise.all(two)) assert.deepEqual(r.reactions, []);
});

test("applyReaction works out the list to show at once", () => {
  const before = [{ emoji: "❤️", count: 2, reacted_by_me: false }, { emoji: "🔥", count: 1, reacted_by_me: true }];
  assert.deepEqual(applyReaction(before, "❤️", true)[0], { emoji: "❤️", count: 3, reacted_by_me: true });
  assert.deepEqual(applyReaction(before, "🚀", true)[2], { emoji: "🚀", count: 1, reacted_by_me: true });
  assert.deepEqual(applyReaction(before, "🔥", false), [{ emoji: "❤️", count: 2, reacted_by_me: false }]);
  assert.deepEqual(applyReaction(before, "🔥", true), before, "giving it twice changes nothing");
  assert.deepEqual(applyReaction(before, "❤️", false), before, "taking back what was not given changes nothing");
  assert.equal(before[0].count, 2, "the input was changed");
});

test("upload asks for a link, sends the file, and finishes", async () => {
  const { fetch, calls } = fakeFetch([
    json(201, { id: "cm_med_1", status: "pending", upload: { method: "PUT", url: "https://storage.test/put?sig=1", expires_at: "2030-01-01T00:00:00Z" }, max_bytes: 100 }),
    new Response(null, { status: 200 }),
    json(200, { id: "cm_med_1", status: "ready", url: "https://storage.test/get", width: 10, height: 10, bytes: 5, attached: false }),
  ]);
  const c = new Community({ apiKey: SECRET, baseUrl: base, fetch, runtime: "server" });
  c.setUser("ali");
  const image = await c.media.upload(new Uint8Array([1, 2, 3]), { contentType: "image/png" });
  assert.equal(image.status, "ready");
  assert.equal(calls[1].url, "https://storage.test/put?sig=1");
  assert.equal(calls[1].method, "PUT");
  assert.equal(calls[1].headers.Authorization, undefined, "the key was sent to storage");
  assert.equal(calls[1].headers["Content-Type"], "image/png");
  assert.equal(calls[2].url, `${base}/v1/media/cm_med_1/complete`);
  await assert.rejects(c.media.upload(new Uint8Array(0)), ValidationError);
  const big = fakeFetch([json(201, { id: "cm_med_2", status: "pending", upload: { method: "PUT", url: "https://storage.test/put", expires_at: "" }, max_bytes: 2 })]);
  const c2 = new Community({ apiKey: SECRET, baseUrl: base, fetch: big.fetch, runtime: "server" });
  c2.setUser("ali");
  await assert.rejects(c2.media.upload(new Uint8Array([1, 2, 3])), ValidationError);
  assert.equal(big.calls.length, 1, "a file over the limit was sent");
});

test("push: a phone is registered, and signing out unregisters it", async () => {
  const expoToken = "ExponentPushToken[abc]";
  const f = fakeFetch([
    session(),
    json(200, { provider: "expo", platform: "ios", registered: true }),
    json(200, { enabled: true, community_enabled: true, devices: 1 }),
    json(200, { enabled: false, community_enabled: true, devices: 1 }),
    json(200, { removed: true }),
    json(200, {}),
  ]);
  const c = new Community({ apiKey: PUBLISHABLE, baseUrl: base, fetch: f.fetch });
  await c.initialize("ali");
  await assert.rejects(c.push.register({ token: "" }), ValidationError);
  const device = await c.push.register({ token: expoToken, platform: "ios" });
  assert.equal(device.provider, "expo");
  assert.equal(c.push.registeredToken, expoToken);
  assert.deepEqual(f.calls[1].body, { token: expoToken, platform: "ios" });
  assert.equal(f.calls[1].method + " " + f.calls[1].url, `PUT ${base}/v1/push/devices`);
  assert.equal((await c.push.preference()).devices, 1);
  assert.equal((await c.push.setEnabled(false)).enabled, false);
  assert.deepEqual(f.calls[3].body, { enabled: false });
  // Signing out forgets the phone first, while the session still works.
  await c.signOut();
  assert.equal(f.calls[4].method + " " + f.calls[4].url, `POST ${base}/v1/push/devices/unregister`);
  assert.deepEqual(f.calls[4].body, { token: expoToken });
  assert.equal(f.calls[4].headers["X-Community-Session"], TOKEN);
  assert.equal(f.calls[5].method + " " + f.calls[5].url, `DELETE ${base}/v1/auth/session`);
  assert.equal(c.push.registeredToken, null);
});

test("push: a failed unregister does not stop sign-out, and nothing is sent with no phone", async () => {
  let f = fakeFetch([session(), json(200, { provider: "fcm", platform: null, registered: true }), failure(500, "internal_error"), json(200, {})]);
  let c = new Community({ apiKey: PUBLISHABLE, baseUrl: base, fetch: f.fetch, retry: false });
  await c.initialize("ali");
  await c.push.register({ token: "fcm-token" });
  await c.signOut();
  assert.equal(c.sessionToken, null);
  assert.equal(f.calls.at(-1).method, "DELETE");
  f = fakeFetch([session(), json(200, {})]);
  c = new Community({ apiKey: PUBLISHABLE, baseUrl: base, fetch: f.fetch });
  await c.initialize("ali");
  assert.equal(await c.push.unregister(), false);
  await c.signOut();
  assert.equal(f.calls.length, 2);
});

test("community.summary returns the member count and a few photos", async () => {
  const f = fakeFetch([session(), json(200, { members_count: 124, avatar_urls: ["https://img/a.webp", "https://img/b.webp"] })]);
  const c = new Community({ apiKey: PUBLISHABLE, baseUrl: base, fetch: f.fetch });
  await c.initialize("ali");
  const summary = await c.community.summary();
  assert.equal(summary.members_count, 124);
  assert.deepEqual(summary.avatar_urls, ["https://img/a.webp", "https://img/b.webp"]);
  assert.equal(f.calls[1].method + " " + f.calls[1].url, `GET ${base}/v1/community/summary`);
});

test("the moderation archive is read with a secret key", async () => {
  const item = { id: "cm_arc_1", kind: "post", target_id: "cm_post_1", body: "spam", reported_by: [] };
  const { fetch, calls } = fakeFetch([
    json(200, { archived: [item], next_cursor: "abc" }),
    json(200, item),
  ]);
  const c = new Community({ apiKey: SECRET, baseUrl: base, fetch, runtime: "server" });
  const page = await c.archive.list({ limit: 2, before: "xyz" });
  assert.equal(page.archived[0].id, "cm_arc_1");
  assert.equal(page.next_cursor, "abc");
  assert.equal(calls[0].url, `${base}/v1/moderation/archive?limit=2&before=xyz`);
  const one = await c.archive.get("cm_arc_1");
  assert.equal(one.body, "spam");
  assert.equal(calls[1].url, `${base}/v1/moderation/archive/cm_arc_1`);
  await assert.rejects(async () => c.archive.get(""), ValidationError);
  assert.equal(calls.length, 2);
});

test("a profile carries the member's post and comment counts", async () => {
  const profile = { external_id: "ali", username: "Annie", posts_count: 12, comments_count: 48 };
  const f = fakeFetch([session(), json(200, { joined: true, profile }), json(200, { ...profile, is_me: false })]);
  const c = new Community({ apiKey: PUBLISHABLE, baseUrl: base, fetch: f.fetch });
  await c.initialize("sara");
  const me = await c.community.me();
  assert.equal(me.profile.posts_count, 12);
  assert.equal(me.profile.comments_count, 48);
  const other = await c.community.member("ali");
  assert.equal(other.posts_count, 12);
  assert.equal(other.comments_count, 48);
});
