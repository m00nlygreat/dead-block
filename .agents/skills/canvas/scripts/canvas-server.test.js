import assert from "node:assert/strict";
import childProcess from "node:child_process";
import fsp from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";
import { promisify } from "node:util";

const execFile = promisify(childProcess.execFile);
const script = fileURLToPath(new URL("./canvas-server.js", import.meta.url));

test("serves files safely and reloads changed Markdown", async (t) => {
  const root = await fsp.mkdtemp(path.join(os.tmpdir(), "canvas-test-"));
  const secondRoot = await fsp.mkdtemp(path.join(os.tmpdir(), "canvas-test-second-"));
  const outsideRoot = await fsp.mkdtemp(path.join(os.tmpdir(), "canvas-test-outside-"));
  const docs = path.join(root, "문서");
  await fsp.mkdir(docs);
  await fsp.writeFile(
    path.join(docs, "guide file.md"),
    "# Hello\n\n| Skill | Description |\n| --- | --- |\n| canvas | Preview files |\n\n![dot](pixel.png)\n\n[next](note.txt)\n\n<script>alert('unsafe')</script>\n",
    "utf8",
  );
  await fsp.writeFile(path.join(docs, "note.txt"), "<unsafe> plain text", "utf8");
  await fsp.writeFile(path.join(docs, "pixel.png"), Buffer.from([137, 80, 78, 71]));
  await fsp.writeFile(path.join(root, "data.bin"), Buffer.from([0, 1, 2, 3]));
  const outsideFile = path.join(outsideRoot, "secret.txt");
  await fsp.writeFile(outsideFile, "outside", "utf8");

  const run = async (...args) => {
    const { stdout } = await execFile(process.execPath, [script, ...args, "--root", root], { encoding: "utf8" });
    return JSON.parse(stdout);
  };

  const started = await run("start", "--path", "문서/guide file.md");
  const runSecond = async (...args) => {
    const { stdout } = await execFile(process.execPath, [script, ...args, "--root", secondRoot], { encoding: "utf8" });
    return JSON.parse(stdout);
  };
  const second = await runSecond("start");
  t.after(async () => {
    await run("stop").catch(() => {});
    await runSecond("stop").catch(() => {});
    await fsp.rm(root, { recursive: true, force: true });
    await fsp.rm(secondRoot, { recursive: true, force: true });
    await fsp.rm(outsideRoot, { recursive: true, force: true });
  });

  assert.equal(started.running, true);
  assert.ok(started.port > 0);
  assert.notEqual(started.port, second.port);
  assert.match(started.url, /path=/);

  const markdownResponse = await fetch(started.url);
  const markdown = await markdownResponse.text();
  assert.equal(markdownResponse.status, 200);
  assert.match(markdown, /<h1>Hello<\/h1>/);
  assert.match(markdown, /<table>/);
  assert.match(markdown, /<th>Skill<\/th>/);
  assert.match(markdown, /<td>canvas<\/td>/);
  assert.match(markdown, /\/asset\?path=%EB%AC%B8%EC%84%9C%2Fpixel\.png/);
  assert.match(markdown, /\/\?path=%EB%AC%B8%EC%84%9C%2Fnote\.txt/);
  assert.doesNotMatch(markdown, /alert\('unsafe'\)/);

  assert.match(markdown, /id="view-toggle"/);
  assert.match(markdown, /"language":"markdown"/);

  const baseUrl = new URL(started.url).origin;
  const textResponse = await fetch(`${baseUrl}/?path=${encodeURIComponent("문서/note.txt")}`);
  const text = await textResponse.text();
  assert.match(text, /&lt;unsafe&gt; plain text/);
  assert.match(text, /"language":"plaintext"/);

  const loaderResponse = await fetch(`${baseUrl}/vendor/monaco/vs/loader.js`);
  assert.equal(loaderResponse.status, 200);
  assert.match(loaderResponse.headers.get("content-type"), /javascript/);
  await loaderResponse.text();

  const workerResponse = await fetch(`${baseUrl}/vendor/monaco/vs/assets/canvas-worker.js?label=json`);
  assert.equal(workerResponse.status, 200);
  assert.match(await workerResponse.text(), /^import "\.\/json\.worker-[^"]+\.js";/);

  const vendorEscape = await fetch(`${baseUrl}/vendor/monaco/vs/..%2F..%2Fpackage.json`);
  assert.equal(vendorEscape.status, 403);

  const binaryResponse = await fetch(`${baseUrl}/?path=data.bin`);
  assert.match(await binaryResponse.text(), /Download file/);

  const assetResponse = await fetch(`${baseUrl}/asset?path=${encodeURIComponent("문서/pixel.png")}`);
  assert.equal(assetResponse.headers.get("content-type"), "image/png");
  assert.deepEqual(Buffer.from(await assetResponse.arrayBuffer()), Buffer.from([137, 80, 78, 71]));

  const traversalResponse = await fetch(`${baseUrl}/?path=${encodeURIComponent("../outside.md")}`);
  assert.equal(traversalResponse.status, 403);
  const missingResponse = await fetch(`${baseUrl}/?path=missing.md`);
  assert.equal(missingResponse.status, 404);

  try {
    await fsp.symlink(outsideFile, path.join(root, "linked-secret.txt"), "file");
    const symlinkResponse = await fetch(`${baseUrl}/?path=linked-secret.txt`);
    assert.equal(symlinkResponse.status, 403);
  } catch (error) {
    if (error.code !== "EPERM") throw error;
    t.diagnostic("symlink escape check skipped because this Windows account cannot create symlinks");
  }

  const events = await fetch(`${baseUrl}/events?path=${encodeURIComponent("문서/guide file.md")}`);
  const reader = events.body.getReader();
  const decoder = new TextDecoder();
  let streamText = decoder.decode((await reader.read()).value);
  assert.match(streamText, /event: ready/);
  await fsp.writeFile(path.join(docs, "guide file.md"), "# Updated\n", "utf8");
  const deadline = Date.now() + 5_000;
  while (!streamText.includes("event: change") && Date.now() < deadline) {
    const chunk = await reader.read();
    if (chunk.done) break;
    streamText += decoder.decode(chunk.value);
  }
  await reader.cancel();
  assert.match(streamText, /event: change/);

  const updated = await fetch(started.url);
  assert.match(await updated.text(), /<h1>Updated<\/h1>/);

  const status = await run("status");
  assert.equal(status.running, true);
  assert.equal(status.port, started.port);
});
