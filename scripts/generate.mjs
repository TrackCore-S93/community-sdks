// Renders src/generated/*.ts from contract/openapi.yaml, the API contract
// copied from the community repository. The models, the error catalogue and
// the list of operations are derived, never retyped.
//
//   node scripts/generate.mjs          write the files
//   node scripts/generate.mjs --check  fail if they would change (CI)
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { parse } from "yaml";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const doc = parse(readFileSync(join(root, "contract", "openapi.yaml"), "utf8"));
const schemas = doc.components.schemas;
const banner = "// GENERATED from contract/openapi.yaml by scripts/generate.mjs. Do not edit.\n\n";

const refName = (ref) => ref.slice(ref.lastIndexOf("/") + 1);

/** The TypeScript type of a schema fragment. */
function tsType(s) {
  if (!s) return "unknown";
  if (s.$ref) return refName(s.$ref);
  if (s.allOf && s.allOf.length === 1) return tsType(s.allOf[0]);
  if (s.anyOf) return s.anyOf.map(tsType).join(" | ");
  if (s.enum) return s.enum.map((v) => JSON.stringify(v)).join(" | ");
  const types = Array.isArray(s.type) ? s.type : [s.type];
  return types
    .map((t) => {
      switch (t) {
        case "string": return "string";
        case "integer": case "number": return "number";
        case "boolean": return "boolean";
        case "null": return "null";
        case "array": return `${wrap(tsType(s.items))}[]`;
        case "object":
          return s.additionalProperties ? `Record<string, ${tsType(s.additionalProperties)}>` : "Record<string, unknown>";
        default: return "unknown";
      }
    })
    .join(" | ");
}
const wrap = (t) => (t.includes("|") ? `(${t})` : t);
const comment = (text, indent = "") =>
  text ? `${indent}/** ${String(text).replace(/\*\//g, "* /").replace(/\s*\n\s*/g, " ")} */\n` : "";

let types = banner;
for (const [name, s] of Object.entries(schemas)) {
  if (s.type === "object" && s.properties) {
    const required = new Set(s.required ?? []);
    types += comment(s.description) + `export interface ${name} {\n`;
    for (const [prop, p] of Object.entries(s.properties)) {
      types += comment(p.description, "  ") + `  ${prop}${required.has(prop) ? "" : "?"}: ${tsType(p)};\n`;
    }
    types += "}\n\n";
  } else if (s.enum) {
    types += comment(s.description) + `export type ${name} = ${s.enum.map((v) => JSON.stringify(v)).join(" | ")};\n\n`;
  }
}

const catalogue = doc["x-community-error-catalogue"];
let errors = banner;
errors += "/** Every error code the API can answer with. */\n";
errors += `export const ALL_ERROR_CODES = ${JSON.stringify(catalogue.map((c) => c.code), null, 2)} as const;\n\n`;
errors += "/** One of the API's error codes. */\nexport type CommunityErrorCode = (typeof ALL_ERROR_CODES)[number];\n\n";
errors += "/** What the API says about one error code. */\nexport interface ErrorCodeSpec {\n  code: CommunityErrorCode;\n  /** The HTTP status it is sent with. */\n  status: number;\n  /** The default sentence. */\n  message: string;\n  /** Whether trying the same request again later can succeed. */\n  retryable: boolean;\n}\n\n";
errors += `export const ERROR_CODE_SPECS: Readonly<Record<CommunityErrorCode, ErrorCodeSpec>> = {\n`;
for (const c of catalogue) {
  errors += `  ${c.code}: { code: ${JSON.stringify(c.code)}, status: ${c.status}, message: ${JSON.stringify(c.message)}, retryable: ${c.retryable} },\n`;
}
errors += "};\n";

let operations = banner;
operations += "/** One route of the API, as the contract describes it. */\nexport interface OperationSpec {\n  /** The SDK call that wraps it, as namespace.method. */\n  sdk: string;\n  operationId: string;\n  method: string;\n  path: string;\n  /** Who may call it. */\n  auth: \"any_key\" | \"member\" | \"creator\" | \"member_or_creator\" | \"session\";\n}\n\n";
operations += "export const OPERATIONS: readonly OperationSpec[] = [\n";
for (const [path, item] of Object.entries(doc.paths)) {
  for (const method of ["get", "post", "put", "patch", "delete"]) {
    const op = item[method];
    if (!op) continue;
    operations += `  { sdk: ${JSON.stringify(op["x-community-sdk"])}, operationId: ${JSON.stringify(op.operationId)}, method: ${JSON.stringify(method.toUpperCase())}, path: ${JSON.stringify(path)}, auth: ${JSON.stringify(op["x-community-auth"])} },\n`;
  }
}
operations += "];\n\n";
operations += `/** The version of the API contract this SDK was generated from. */\nexport const CONTRACT_VERSION = ${JSON.stringify(doc.info.version)};\n`;

const files = { "types.ts": types, "errors.ts": errors, "operations.ts": operations };
const dir = join(root, "src", "generated");
const check = process.argv.includes("--check");
let stale = false;
mkdirSync(dir, { recursive: true });
for (const [name, text] of Object.entries(files)) {
  const path = join(dir, name);
  if (check) {
    if (!existsSync(path) || readFileSync(path, "utf8") !== text) {
      console.error(`src/generated/${name} is out of date; run: npm run generate`);
      stale = true;
    }
  } else {
    writeFileSync(path, text);
  }
}
if (stale) process.exit(1);
if (!check) console.log(`generated ${Object.keys(files).length} files from contract ${doc.info.version}`);
