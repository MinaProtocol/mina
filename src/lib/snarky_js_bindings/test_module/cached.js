import path from "node:path";
import fs from "node:fs/promises";
import crypto from "node:crypto";
import findCacheDir from "find-cache-dir";

let cacheDir = findCacheDir({ name: "snarkyjs-test", create: true });

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
  content = createStuff();
  await fs.writeFile(file, JSON.stringify(content));
  return content;
}

function hash(stuff) {
  return crypto.createHash("sha1").update(stuff).digest("base64url");
}
