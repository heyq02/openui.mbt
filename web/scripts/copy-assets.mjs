import { copyFile, mkdir } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const webRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const repoRoot = resolve(webRoot, "..");
const publicDir = resolve(webRoot, "public");
const wasm = resolve(repoRoot, "_build/wasm-gc/release/build/ffi/ffi.wasm");

await mkdir(publicDir, { recursive: true });
try {
  await copyFile(wasm, resolve(publicDir, "parser.wasm"));
} catch (error) {
  if (error && error.code === "ENOENT") {
    throw new Error(
      "Missing Wasm build. From the repo root, run: moon build --target wasm-gc --release",
    );
  }
  throw error;
}
await copyFile(
  resolve(repoRoot, "examples/signup.openui"),
  resolve(publicDir, "signup.openui"),
);
