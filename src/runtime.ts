/** Where the code is running, as far as it can tell. */
export type Runtime = "server" | "browser" | "react-native" | "unknown";

type Globals = {
  process?: { env?: Record<string, string | undefined>; versions?: { node?: string } };
  Deno?: unknown;
  Bun?: unknown;
  navigator?: { product?: string; userAgent?: string };
  document?: unknown;
  WorkerGlobalScope?: unknown;
  self?: unknown;
};

/** Reads an environment variable from a real process.env, where there is one. */
export function env(name: string): string | undefined {
  const value = (globalThis as Globals).process?.env?.[name];
  return typeof value === "string" && value.trim() !== "" ? value.trim() : undefined;
}

/**
 * Decides where the code is running. In order: a pinned answer
 * (COMMUNITY_RUNTIME=server), React Native, a runtime that announces itself
 * (Deno, Bun, Cloudflare Workers, Node without a DOM), then a document, then a
 * worker global with no document, which counts as a browser because it might
 * be one.
 */
export function detectRuntime(): Runtime {
  const g = globalThis as Globals;
  if (env("COMMUNITY_RUNTIME") === "server") return "server";
  if (g.navigator?.product === "ReactNative") return "react-native";
  if (g.Deno !== undefined || g.Bun !== undefined) return "server";
  if (g.navigator?.userAgent === "Cloudflare-Workers") return "server";
  if (g.document !== undefined) return "browser";
  if (g.process?.versions?.node !== undefined) return "server";
  if (g.WorkerGlobalScope !== undefined && g.self !== undefined) return "browser";
  return "unknown";
}
