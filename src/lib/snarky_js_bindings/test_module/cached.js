import path from "path";
import fs from "fs/promises";
import { fileURLToPath } from "url";
import crypto from "crypto";

let selfDir = path.dirname(fileURLToPath(import.meta.url));
let cacheDir = path.resolve(selfDir, "node_modules/.cache/snarkyjs-test");
await fs.mkdir(cacheDir, { recursive: true });

/**
 * @template T
 * @param {() => T} createStuff
 * @returns {Promise<T>}
 */
export default async function cached(createStuff) {
  let key = hash("" + createStuff);
  let file = path.resolve(cacheDir, `${key}.json`);

  // try reading from cache and return early
  let content = await fs
    .readFile(file, "utf8")
    .then(JSON.parse)
    .catch(() => {});
  if (content !== undefined) return content;

  // otherwise run the function and write to cache
  content = await createStuff();
  await fs.writeFile(file, JSON.stringify(content));
  return content;
}

function hash(stuff) {
  return crypto.createHash("sha1").update(stuff).digest("base64url");
}
