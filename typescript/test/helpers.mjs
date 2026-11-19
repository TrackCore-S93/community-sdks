// A fake fetch: answers from a queue of replies and records what was sent.
export const SECRET = "cm_sk_test_" + "a".repeat(43);
export const PUBLISHABLE = "cm_pk_test_" + "b".repeat(43);
export const TOKEN = "cm_st_" + "c".repeat(43);

export function json(status, body, headers = {}) {
  return new Response(body === undefined ? null : JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...headers },
  });
}

export function failure(status, code, extra = {}) {
  return json(status, { error: { code, message: `${code} happened`, request_id: "req_1", retry_after_seconds: null, ...extra } });
}

export function session(externalId = "ali", ttl = 86400) {
  return json(201, {
    token: TOKEN, token_type: "opaque", header: "X-Community-Session", external_id: externalId, environment: "test",
    issued_at: new Date().toISOString(), expires_at: new Date(Date.now() + ttl * 1000).toISOString(), ttl_seconds: ttl,
  });
}

/** replies: an array of Response, Error (thrown), or function(request) -> Response. */
export function fakeFetch(replies) {
  const calls = [];
  const queue = [...replies];
  const fetch = async (url, init = {}) => {
    const call = {
      url, method: init.method ?? "GET", headers: init.headers ?? {},
      body: typeof init.body === "string" ? JSON.parse(init.body) : init.body,
    };
    calls.push(call);
    const next = queue.shift();
    if (next === undefined) throw new Error(`fakeFetch: no reply queued for ${call.method} ${url}`);
    if (next instanceof Error) throw next;
    if (next === "hang") {
      return new Promise((_, reject) => init.signal?.addEventListener("abort", () => reject(new Error("aborted"))));
    }
    return typeof next === "function" ? next(call) : next;
  };
  return { fetch, calls };
}

export const quick = { baseDelayMs: 1, maxDelayMs: 2 };
