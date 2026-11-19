import { ConfigurationError } from "./errors.js";
import type { WebSocketFactory, WebSocketLike } from "./options.js";
import type { Transport } from "./transport.js";
import type { LiveEvent } from "./generated/types.js";

/** Where a live connection is in its life. */
export type LiveStatus = "connecting" | "open" | "reconnecting" | "closed";

/** How to listen for live updates. */
export interface LiveOptions {
  /** Follow only this topic. Left out, every topic. */
  topicId?: string;
  /** Called for each change. */
  onEvent: (event: LiveEvent) => void;
  /** Called when the connection opens, drops, retries or closes. */
  onStatus?: (status: LiveStatus) => void;
  /** Called when a connection attempt fails. The SDK keeps retrying. */
  onError?: (error: unknown) => void;
}

/** An open live connection. */
export interface LiveConnection {
  /** Where the connection is now. */
  readonly status: LiveStatus;
  /** Follows one topic, or every topic when called with nothing. */
  watch(topicId?: string): void;
  /** Stops listening and stops reconnecting. */
  close(): void;
}

const FIRST_RETRY_MS = 1000;
const LONGEST_RETRY_MS = 30_000;

type RuntimeWebSocket = new (url: string, options?: unknown, legacy?: unknown) => WebSocketLike;

/**
 * Live updates: a WebSocket that receives each change as it happens. The
 * connection only listens; posting, reacting and commenting use their own
 * calls. A dropped connection is reopened with backoff. After a reconnect,
 * read the feed since your newest post to catch up on what was missed.
 */
export class LiveAPI {
  constructor(
    private readonly transport: Transport,
    private readonly factory: WebSocketFactory | undefined,
  ) {}

  /** Opens the connection and keeps it open until `close()`. */
  connect(options: LiveOptions): LiveConnection {
    const open = this.factory ?? defaultFactory(this.transport.runtime);
    const base = this.transport.baseUrl.replace(/^http/, "ws");
    const transport = this.transport;
    let socket: WebSocketLike | null = null;
    let status: LiveStatus = "connecting";
    let topic = options.topicId ?? "";
    let attempt = 0;
    let timer: ReturnType<typeof setTimeout> | null = null;
    let closed = false;

    const setStatus = (next: LiveStatus): void => {
      status = next;
      transport.emit({ type: "live", status: next, attempt });
      try {
        options.onStatus?.(next);
      } catch {
        // A listener must not break the connection.
      }
    };

    const retry = (): void => {
      if (closed || timer !== null) return;
      attempt++;
      const ceiling = Math.min(LONGEST_RETRY_MS, FIRST_RETRY_MS * 2 ** (attempt - 1));
      setStatus("reconnecting");
      timer = setTimeout(() => {
        timer = null;
        void dial();
      }, ceiling / 2 + Math.random() * (ceiling / 2));
    };

    const dial = async (): Promise<void> => {
      if (closed) return;
      try {
        const headers = await transport.liveHeaders();
        if (closed) return;
        const url = `${base}/v1/live${topic ? `?topic_id=${encodeURIComponent(topic)}` : ""}`;
        const ws = open(url, headers);
        socket = ws;
        ws.onmessage = (message) => {
          let event: { type?: string };
          try {
            event = JSON.parse(String(message.data));
          } catch {
            return;
          }
          if (event.type === "ready") {
            attempt = 0;
            setStatus("open");
            return;
          }
          if (event.type === "watching") return;
          try {
            options.onEvent(event as LiveEvent);
          } catch {
            // A listener must not break the connection.
          }
        };
        ws.onerror = (error) => {
          try {
            options.onError?.(error);
          } catch {
            // ignored
          }
        };
        ws.onclose = () => {
          if (socket === ws) socket = null;
          retry();
        };
      } catch (error) {
        try {
          options.onError?.(error);
        } catch {
          // ignored
        }
        // A client that cannot connect at all (no user, no WebSocket) stops.
        if (error instanceof ConfigurationError) {
          closed = true;
          setStatus("closed");
          return;
        }
        retry();
      }
    };

    setStatus("connecting");
    void dial();

    return {
      get status() {
        return status;
      },
      watch(topicId?: string) {
        topic = topicId ?? "";
        if (status === "open") socket?.send(JSON.stringify({ type: "watch", topic_id: topic }));
      },
      close() {
        if (closed) return;
        closed = true;
        if (timer !== null) clearTimeout(timer);
        timer = null;
        const ws = socket;
        socket = null;
        if (ws) {
          ws.onclose = null;
          ws.close(1000, "closed by the app");
        }
        setStatus("closed");
      },
    };
  }
}

/**
 * The runtime's own WebSocket, where it can send request headers: Node 22 and
 * later, Bun and Deno. A browser's cannot, so a browser needs the `webSocket`
 * option; React Native is handled by the React Native SDK.
 */
function defaultFactory(runtime: string): WebSocketFactory {
  const WS = (globalThis as { WebSocket?: RuntimeWebSocket }).WebSocket;
  if (runtime === "browser") {
    throw new ConfigurationError(
      "live_unsupported",
      "Live updates are not available in a browser: a browser's WebSocket cannot send the headers the API needs.",
    );
  }
  if (typeof WS !== "function") {
    throw new ConfigurationError(
      "live_unsupported",
      "This runtime has no WebSocket. Pass one as the webSocket option (on Node before 22, the ws package).",
    );
  }
  if (runtime === "react-native") return (url, headers) => new WS(url, undefined, { headers });
  return (url, headers) => new WS(url, { headers });
}
