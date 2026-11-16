// Builds the package twice from the same source: ES modules into dist/esm and
// CommonJS into dist/cjs. No bundler: the output is the source, file for file.
import { execFileSync } from "node:child_process";
import { rmSync, writeFileSync, mkdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const tsc = join(root, "node_modules", "typescript", "bin", "tsc");
const run = (...args) => execFileSync(process.execPath, [tsc, ...args], { cwd: root, stdio: "inherit" });

rmSync(join(root, "dist"), { recursive: true, force: true });
run("-p", "tsconfig.json");
run("-p", "tsconfig.json", "--module", "CommonJS", "--moduleResolution", "Node10", "--outDir", "dist/cjs");
// Each half says which module system it is, whatever the package's own "type".
mkdirSync(join(root, "dist", "esm"), { recursive: true });
writeFileSync(join(root, "dist", "esm", "package.json"), '{ "type": "module" }\n');
writeFileSync(join(root, "dist", "cjs", "package.json"), '{ "type": "commonjs" }\n');
