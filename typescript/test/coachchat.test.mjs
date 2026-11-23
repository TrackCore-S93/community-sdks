import { test } from "node:test";
import assert from "node:assert/strict";
import { Community, ConfigurationError, ConnectionError, ValidationError } from "../dist/esm/index.js";
import { SECRET, PUBLISHABLE, json, session, fakeFetch } from "./helpers.mjs";

const base = "http://api.test";
const message = (over = {}) => ({
  id: "cm_msg_1", author: { external_id: "ali", username: "Annie", avatar_url: "", role: "user" }, from_coach: false,
  body: "Hi Coach!", images: [], files: [], is_mine: true, is_read: false, edited_at: null, created_at: "2026-11-20T10:00:00Z", ...over,
});
const page = (messages) => ({ messages, older_cursor: "old", newer_cursor: "new", has_older: true, has_newer: false });

async function memberClient(replies) {
  const { fetch, calls } = fakeFetch([session(), ...replies]);
  const c = new Community({ apiKey: PUBLISHABLE, baseUrl: base, fetch, runtime: "browser" });
  await c.initialize("ali");
  calls.length = 0;
  return { c, calls };
}

test("a member reads their coaching chat", async () => {
  const { c, calls } = await memberClient([
    json(200, { unread_count: 2, last_message_at: "2026-11-20T10:00:00Z" }),
    json(200, page([message()])),
    json(200, page([])),
    json(200, { unread_count: 0, last_message_at: "2026-11-20T10:00:00Z" }),
  ]);
  const chat = await c.coachChat.get();
  assert.equal(chat.unread_count, 2);
  assert.equal(calls[0].url, `${base}/v1/coach-chat`);

  const first = await c.coachChat.messages();
  assert.equal(first.messages[0].body, "Hi Coach!");
  assert.equal(first.older_cursor, "old");
  assert.equal(calls[1].url, `${base}/v1/coach-chat/messages`);

  await c.coachChat.messages({ limit: 20, around: "cm_msg_9" });
  assert.equal(calls[2].url, `${base}/v1/coach-chat/messages?limit=20&around=cm_msg_9`);

  const read = await c.coachChat.markRead();
  assert.equal(read.unread_count, 0);
  assert.equal(calls[3].method, "POST");
  assert.equal(calls[3].url, `${base}/v1/coach-chat/read`);

  // Two directions at once is refused before anything is sent.
  assert.throws(() => c.coachChat.messages({ before: "a", after: "b" }), ValidationError);
  assert.equal(calls.length, 4);
});

test("a member sends, edits and deletes a message", async () => {
  const { c, calls } = await memberClient([
    json(201, message({ images: [{ id: "cm_med_1" }] })),
    json(201, message()),
    json(200, message({ body: "Hi!", edited_at: "2026-11-20T10:05:00Z" })),
    json(200, { id: "cm_msg_1", deleted: true }),
  ]);
  await c.coachChat.send({ body: "Hi Coach!", mediaIds: ["cm_med_1"] });
  assert.equal(calls[0].method, "POST");
  assert.equal(calls[0].url, `${base}/v1/coach-chat/messages`);
  assert.deepEqual(calls[0].body, { body: "Hi Coach!", media_ids: ["cm_med_1"] });
  assert.ok(calls[0].headers["Idempotency-Key"], "a send carries an idempotency key of its own");

  await c.coachChat.send({ body: "Once", idempotencyKey: "k1" });
  assert.equal(calls[1].headers["Idempotency-Key"], "k1");

  const edited = await c.coachChat.edit("cm_msg_1", "Hi!");
  assert.equal(edited.edited_at, "2026-11-20T10:05:00Z");
  assert.equal(calls[2].method, "PATCH");
  assert.equal(calls[2].url, `${base}/v1/coach-chat/messages/cm_msg_1`);
  assert.deepEqual(calls[2].body, { body: "Hi!" });

  const gone = await c.coachChat.delete("cm_msg_1");
  assert.equal(gone.deleted, true);
  assert.equal(calls[3].method, "DELETE");

  assert.throws(() => c.coachChat.edit("", "x"), ValidationError);
  assert.throws(() => c.coachChat.deleteImage("cm_msg_1", ""), ValidationError);
  assert.throws(() => c.coachChat.deleteImage("", "cm_med_1"), ValidationError);
  assert.throws(() => c.coachChat.delete(""), ValidationError);
  assert.equal(calls.length, 4);
});

test("a member searches their chat", async () => {
  const { c, calls } = await memberClient([json(200, { messages: [message()], next_cursor: null, has_more: false })]);
  const found = await c.coachChat.search({ q: "  transformation plan ", limit: 10 });
  assert.equal(found.messages.length, 1);
  assert.equal(calls[0].url, `${base}/v1/coach-chat/search?q=transformation+plan&limit=10`);
  assert.throws(() => c.coachChat.search({ q: "a" }), ValidationError);
  assert.equal(calls.length, 1);
});

test("a member deletes one image from a message", async () => {
  const { c, calls } = await memberClient([
    json(200, { deleted: true, message_deleted: false, message: message({ body: "My meals" }) }),
    json(200, { deleted: true, message_deleted: true, message: null }),
  ]);
  const kept = await c.coachChat.deleteImage("cm_msg_1", "cm_med_1");
  assert.equal(kept.deleted, true);
  assert.equal(kept.message.body, "My meals");
  assert.equal(calls[0].method, "DELETE");
  assert.equal(calls[0].url, `${base}/v1/coach-chat/messages/cm_msg_1/images/cm_med_1`);

  const gone = await c.coachChat.deleteImage("cm_msg_2", "cm_med_2");
  assert.equal(gone.message_deleted, true);
  assert.equal(gone.message, null);
});

test("the coach's messages carry voice notes and files", async () => {
  const voice = { id: "cm_att_1", kind: "voice", name: "note.m4a", content_type: "audio/mp4", bytes: 9000, duration_ms: 15000, url: "https://files.test/n" };
  const { c } = await memberClient([json(200, page([message({ id: "cm_msg_2", from_coach: true, is_mine: false, body: "", files: [voice], author: null })]))]);
  const got = (await c.coachChat.messages()).messages[0];
  assert.equal(got.from_coach, true);
  assert.equal(got.author, null);
  assert.equal(got.files[0].kind, "voice");
  assert.equal(got.files[0].duration_ms, 15000);
});

test("the coach's side needs a secret key and a named coach", async () => {
  const device = await memberClient([]);
  for (const call of [
    () => device.c.coachChat.sendAsCoach({ memberId: "ali", body: "x" }),
    () => device.c.coachChat.startFile({ kind: "file", fileName: "a.pdf", contentType: "application/pdf" }),
    () => device.c.coachChat.completeFile("cm_att_1"),
  ]) {
    await assert.rejects(async () => call(), (e) => e instanceof ConfigurationError && e.reason === "secret_key_required");
  }
  assert.equal(device.calls.length, 0);

  const { fetch, calls } = fakeFetch([]);
  const server = new Community({ apiKey: SECRET, baseUrl: base, fetch, runtime: "server" });
  await assert.rejects(async () => server.coachChat.sendAsCoach({ memberId: "ali", body: "x" }), (e) => e instanceof ConfigurationError && e.reason === "no_user");
  assert.equal(calls.length, 0);
});

test("the coach answers a member, with a file", async () => {
  const file = { id: "cm_att_1", kind: "file", name: "plan.pdf", content_type: "application/pdf", bytes: 4, duration_ms: null, url: "https://files.test/p" };
  const { fetch, calls } = fakeFetch([
    json(201, { id: "cm_att_1", kind: "file", name: "plan.pdf", upload: { method: "PUT", url: "https://bucket.test/put", expires_at: "2026-11-20T10:15:00Z" }, max_bytes: 100 }),
    new Response(null, { status: 200 }),
    json(200, file),
    json(201, message({ id: "cm_msg_3", from_coach: true, body: "Your plan", files: [file] })),
  ]);
  const c = new Community({ apiKey: SECRET, baseUrl: base, fetch, runtime: "server" });
  await c.initialize("coach_1");

  const uploaded = await c.coachChat.uploadFile(new Uint8Array([1, 2, 3, 4]), { kind: "file", fileName: "plan.pdf", contentType: "application/pdf" });
  assert.equal(uploaded.id, "cm_att_1");
  assert.equal(calls[0].url, `${base}/v1/coach-chat/files`);
  assert.equal(calls[0].headers["X-External-Id"], "coach_1");
  assert.deepEqual(calls[0].body, { kind: "file", file_name: "plan.pdf", content_type: "application/pdf" });
  // The file goes to the link with its type and without the key.
  assert.equal(calls[1].url, "https://bucket.test/put");
  assert.equal(calls[1].method, "PUT");
  assert.equal(calls[1].headers["Content-Type"], "application/pdf");
  assert.equal(calls[1].headers.Authorization, undefined);
  assert.equal(calls[2].url, `${base}/v1/coach-chat/files/cm_att_1/complete`);

  const sent = await c.coachChat.sendAsCoach({ memberId: "ali", body: "Your plan", fileIds: ["cm_att_1"] });
  assert.equal(sent.files[0].name, "plan.pdf");
  assert.equal(calls[3].url, `${base}/v1/coach-chat/members/ali/messages`);
  assert.equal(calls[3].headers["X-External-Id"], "coach_1");
  assert.deepEqual(calls[3].body, { body: "Your plan", file_ids: ["cm_att_1"] });
  assert.ok(calls[3].headers["Idempotency-Key"]);
});

test("the coach lists the chats, opens one and marks it read", async () => {
  const row = {
    member: { external_id: "ali", username: "Annie", avatar_url: "", role: "user" }, unread_count: 2,
    last_message_at: "2026-11-20T10:00:00Z",
    last_message: { id: "cm_msg_1", body: "Hi Coach!", from_coach: false, images_count: 0, files_count: 0 },
  };
  const { fetch, calls } = fakeFetch([
    json(200, { chats: [row], next_cursor: "more", has_more: true }),
    json(200, { chats: [], next_cursor: null, has_more: false }),
    json(200, page([message({ is_mine: false })])),
    json(200, { unread_count: 0, last_message_at: "2026-11-20T10:00:00Z" }),
  ]);
  const c = new Community({ apiKey: SECRET, baseUrl: base, fetch, runtime: "server" });
  await c.initialize("coach_1");

  const list = await c.coachChat.chats();
  assert.equal(list.chats[0].member.external_id, "ali");
  assert.equal(list.chats[0].unread_count, 2);
  assert.equal(list.chats[0].last_message.body, "Hi Coach!");
  assert.equal(calls[0].url, `${base}/v1/coach-chat/members`);
  assert.equal(calls[0].headers["X-External-Id"], "coach_1");

  await c.coachChat.chats({ limit: 10, before: list.next_cursor, unreadOnly: true });
  assert.equal(calls[1].url, `${base}/v1/coach-chat/members?limit=10&before=more&unread=true`);

  const chat = await c.coachChat.memberMessages("ali", { limit: 20 });
  assert.equal(chat.messages[0].is_mine, false);
  assert.equal(calls[2].url, `${base}/v1/coach-chat/members/ali/messages?limit=20`);
  assert.equal(calls[2].headers["X-External-Id"], "coach_1");

  const read = await c.coachChat.markMemberRead("ali");
  assert.equal(read.unread_count, 0);
  assert.equal(calls[3].method, "POST");
  assert.equal(calls[3].url, `${base}/v1/coach-chat/members/ali/read`);

  assert.throws(() => c.coachChat.memberMessages("ali", { before: "a", around: "b" }), ValidationError);
  assert.throws(() => c.coachChat.memberMessages(""), ConfigurationError);
  assert.throws(() => c.coachChat.markMemberRead(""), ConfigurationError);
  assert.equal(calls.length, 4);
});

test("a file that is empty, too large or refused by storage never reaches a message", async () => {
  const started = () => json(201, { id: "cm_att_1", kind: "voice", name: "n.m4a", upload: { method: "PUT", url: "https://bucket.test/put", expires_at: "2026-11-20T10:15:00Z" }, max_bytes: 2 });
  const params = { kind: "voice", fileName: "n.m4a", contentType: "audio/mp4", durationMs: 1500 };
  const { fetch, calls } = fakeFetch([started, started, new Response(null, { status: 403 })]);
  const c = new Community({ apiKey: SECRET, baseUrl: base, fetch, runtime: "server" });
  await c.initialize("coach_1");

  await assert.rejects(c.coachChat.uploadFile(new Uint8Array(0), params), ValidationError);
  assert.equal(calls.length, 0);
  await assert.rejects(c.coachChat.uploadFile(new Uint8Array(3), params), ValidationError);
  assert.equal(calls.length, 1);
  assert.equal(calls[0].body.duration_ms, 1500);
  await assert.rejects(c.coachChat.uploadFile(new Uint8Array(1), params), ConnectionError);
  assert.equal(calls.length, 3);
  assert.throws(() => c.coachChat.startFile({ ...params, kind: "video" }), ValidationError);
});
