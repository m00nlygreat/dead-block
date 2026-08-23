#!/usr/bin/env node

import childProcess from "node:child_process";
import crypto from "node:crypto";
import fs from "node:fs";
import fsp from "node:fs/promises";
import http from "node:http";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { remark } from "remark";
import remarkGfm from "remark-gfm";
import remarkHtml from "remark-html";

const APP_NAME = "codex-canvas";
const HOST = "127.0.0.1";
const START_TIMEOUT_MS = 10_000;
const TEXT_EXTENSIONS = new Set([
  ".css", ".csv", ".html", ".ini", ".js", ".json", ".jsx", ".log", ".mjs",
  ".py", ".sh", ".sql", ".toml", ".ts", ".tsx", ".txt", ".xml", ".yaml", ".yml",
]);

const MONACO_ROOT = fileURLToPath(new URL("../node_modules/monaco-editor/min/vs/", import.meta.url));
const MONACO_LANGUAGES = new Map([
  [".css", "css"], [".csv", "plaintext"], [".html", "html"], [".ini", "ini"],
  [".js", "javascript"], [".json", "json"], [".jsx", "javascript"], [".log", "plaintext"],
  [".markdown", "markdown"], [".md", "markdown"], [".mjs", "javascript"], [".py", "python"],
  [".sh", "shell"], [".sql", "sql"], [".toml", "ini"], [".ts", "typescript"],
  [".tsx", "typescript"], [".txt", "plaintext"], [".xml", "xml"], [".yaml", "yaml"], [".yml", "yaml"],
]);

const MONACO_WORKER_PATH = "/vendor/monaco/vs/assets/canvas-worker.js";
const MONACO_WORKER_PREFIXES = new Map([
  ["css", "css.worker-"],
  ["handlebars", "html.worker-"],
  ["html", "html.worker-"],
  ["javascript", "ts.worker-"],
  ["json", "json.worker-"],
  ["less", "css.worker-"],
  ["razor", "html.worker-"],
  ["scss", "css.worker-"],
  ["typescript", "ts.worker-"],
]);

const MIME_TYPES = new Map([
  [".avif", "image/avif"],
  [".css", "text/css; charset=utf-8"],
  [".csv", "text/csv; charset=utf-8"],
  [".gif", "image/gif"],
  [".html", "text/html; charset=utf-8"],
  [".jpeg", "image/jpeg"],
  [".jpg", "image/jpeg"],
  [".js", "text/javascript; charset=utf-8"],
  [".json", "application/json; charset=utf-8"],
  [".m4a", "audio/mp4"],
  [".md", "text/markdown; charset=utf-8"],
  [".markdown", "text/markdown; charset=utf-8"],
  [".mov", "video/quicktime"],
  [".mp3", "audio/mpeg"],
  [".mp4", "video/mp4"],
  [".ogg", "audio/ogg"],
  [".pdf", "application/pdf"],
  [".png", "image/png"],
  [".svg", "image/svg+xml"],
  [".ttf", "font/ttf"],
  [".txt", "text/plain; charset=utf-8"],
  [".wav", "audio/wav"],
  [".webm", "video/webm"],
  [".webp", "image/webp"],
  [".xml", "application/xml; charset=utf-8"],
]);

const markdownRenderer = {
  name: "markdown",
  supports(file) {
    return file.extension === ".md" || file.extension === ".markdown";
  },
  async render(file, context) {
    const source = await fsp.readFile(file.absolutePath, "utf8");
    const output = await remark()
      .use(remarkGfm)
      .use(rewriteRelativeUrls, { file, context })
      .use(remarkHtml, { sanitize: true })
      .process(source);
    return { kind: "markdown", body: String(output) };
  },
};

// Add future format renderers before the fallback by extending this registry.
export const renderers = [markdownRenderer];

if (isMainModule()) {
  main().catch((error) => {
    console.error(error.message || error);
    process.exit(1);
  });
}

async function main() {
  const [command = "help", ...rest] = process.argv.slice(2);
  const args = parseArgs(rest);
  const root = await getRoot(args.root || process.cwd());

  if (command === "help" || args.help) {
    printHelp();
    return;
  }

  if (command === "serve") {
    await serve(root, {
      port: parsePort(args.port),
      launchId: String(args["launch-id"] || crypto.randomUUID()),
    });
    return;
  }

  if (command === "start" || command === "ensure") {
    let relativePath = "";
    if (args.path) {
      const file = await resolveExistingFile(root, String(args.path));
      relativePath = file.relativePath;
    }
    const state = await ensureServer(root, args);
    printJson(openResult(state, relativePath));
    return;
  }

  if (command === "status") {
    const state = await readState(runtimeDirs(root));
    const live = await pingState(state);
    printJson(live ? { running: true, ...live } : { running: false });
    return;
  }

  if (command === "stop") {
    const dirs = runtimeDirs(root);
    const state = await readState(dirs);
    const live = await pingState(state);
    if (!live) {
      await removeFile(dirs.stateFile);
      printJson({ stopped: false, reason: "server is not running" });
      return;
    }
    try {
      process.kill(live.pid, "SIGTERM");
    } catch {
      // The process may have exited between the health check and signal.
    }
    await removeFile(dirs.stateFile);
    printJson({ stopped: true, pid: live.pid });
    return;
  }

  throw new Error(`Unknown command: ${command}`);
}

async function ensureServer(root, args) {
  const dirs = runtimeDirs(root);
  await fsp.mkdir(dirs.dir, { recursive: true });

  const existing = await readState(dirs);
  const live = await pingState(existing);
  if (live && samePath(live.root, root.realPath)) return live;

  await removeFile(dirs.stateFile);
  const launchId = crypto.randomUUID();
  const logHandle = fs.openSync(dirs.logFile, "a");
  const child = childProcess.spawn(process.execPath, [
    fileURLToPath(import.meta.url),
    "serve",
    "--root",
    root.realPath,
    "--port",
    String(parsePort(args.port)),
    "--launch-id",
    launchId,
  ], {
    cwd: root.realPath,
    detached: true,
    windowsHide: true,
    stdio: ["ignore", logHandle, logHandle],
  });
  child.unref();
  fs.closeSync(logHandle);

  const deadline = Date.now() + START_TIMEOUT_MS;
  while (Date.now() < deadline) {
    await sleep(150);
    const state = await readState(dirs);
    if (state?.launchId === launchId) {
      const started = await pingState(state);
      if (started && samePath(started.root, root.realPath)) return started;
    }
  }

  throw new Error(`Canvas server did not start. See ${dirs.logFile}`);
}

async function serve(root, options) {
  const dirs = runtimeDirs(root);
  await fsp.mkdir(dirs.dir, { recursive: true });
  const startedAt = new Date().toISOString();

  const server = http.createServer((req, res) => {
    handleRequest(req, res, root, () => ({
      app: APP_NAME,
      pid: process.pid,
      host: HOST,
      port: server.address().port,
      url: `http://${HOST}:${server.address().port}`,
      root: root.realPath,
      launchId: options.launchId,
      startedAt,
    })).catch((error) => sendError(res, error));
  });

  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(options.port, HOST, resolve);
  });

  const state = {
    app: APP_NAME,
    pid: process.pid,
    host: HOST,
    port: server.address().port,
    url: `http://${HOST}:${server.address().port}`,
    root: root.realPath,
    launchId: options.launchId,
    startedAt,
  };
  await writeJson(dirs.stateFile, state);

  const shutdown = async () => {
    const current = await readState(dirs);
    if (current?.launchId === options.launchId) await removeFile(dirs.stateFile);
    server.close(() => process.exit(0));
  };
  process.on("SIGTERM", shutdown);
  process.on("SIGINT", shutdown);
}

async function handleRequest(req, res, root, getState) {
  const requestUrl = new URL(req.url, getState().url);

  if (req.method === "GET" && requestUrl.pathname === "/api/state") {
    sendJson(res, getState());
    return;
  }

  if (req.method === "GET" && requestUrl.pathname === "/events") {
    await streamEvents(req, res, root, requestUrl.searchParams.get("path"));
    return;
  }

  // Served from the assets directory so nested worker imports resolve against the right base URL.
  if (req.method === "GET" && requestUrl.pathname === MONACO_WORKER_PATH) {
    sendText(res, await monacoWorkerBootstrap(requestUrl.searchParams.get("label")), "text/javascript; charset=utf-8");
    return;
  }

  if (req.method === "GET" && requestUrl.pathname.startsWith("/vendor/monaco/vs/")) {
    await sendVendorFile(res, requestUrl.pathname.slice("/vendor/monaco/vs/".length));
    return;
  }

  if (req.method === "GET" && requestUrl.pathname === "/asset") {
    const file = await resolveExistingFile(root, requestUrl.searchParams.get("path"));
    await sendAsset(req, res, file, requestUrl.searchParams.has("download"));
    return;
  }

  if (req.method === "GET" && requestUrl.pathname === "/") {
    const requestedPath = requestUrl.searchParams.get("path");
    if (!requestedPath) {
      sendHtml(res, renderShell({
        title: "Canvas",
        body: '<section class="notice"><h1>Canvas</h1><p>Add <code>?path=relative/path/to/file.md</code> to preview a project file.</p></section>',
      }));
      return;
    }

    const file = await resolveExistingFile(root, requestedPath);
    const rendered = await renderFile(file, root);
    sendHtml(res, renderShell({
      title: path.basename(file.relativePath),
      body: rendered.body,
      targetPath: file.relativePath,
      kind: rendered.kind,
      language: hasSourceView(rendered) ? sourceLanguage(file) : "",
    }));
    return;
  }

  throw new HttpError(404, "Not found");
}

async function renderFile(file, root) {
  const context = {
    root,
    escapeHtml,
    assetUrl(relativePath, download = false) {
      return `/asset?path=${encodeURIComponent(toUrlPath(relativePath))}${download ? "&download=1" : ""}`;
    },
    documentUrl(relativePath) {
      return `/?path=${encodeURIComponent(toUrlPath(relativePath))}`;
    },
  };
  const renderer = renderers.find((candidate) => candidate.supports(file));
  return renderer ? renderer.render(file, context) : renderFallback(file, context);
}

async function renderFallback(file, context) {
  if (isTextFile(file)) {
    const content = await fsp.readFile(file.absolutePath, "utf8");
    return {
      kind: "text",
      body: `<pre class="text-preview"><code>${escapeHtml(content)}</code></pre>`,
    };
  }

  const source = escapeHtml(context.assetUrl(file.relativePath));
  const download = escapeHtml(context.assetUrl(file.relativePath, true));
  const label = escapeHtml(path.basename(file.relativePath));

  if (file.mime.startsWith("image/")) {
    return { kind: "media", body: `<figure class="media-preview"><img src="${source}" alt="${label}"></figure>` };
  }
  if (file.mime.startsWith("audio/")) {
    return { kind: "media", body: `<div class="media-preview"><audio controls src="${source}"></audio></div>` };
  }
  if (file.mime.startsWith("video/")) {
    return { kind: "media", body: `<div class="media-preview"><video controls src="${source}"></video></div>` };
  }
  if (file.mime === "application/pdf") {
    return { kind: "media", body: `<iframe class="pdf-preview" src="${source}" title="${label}"></iframe>` };
  }

  return {
    kind: "binary",
    body: `<section class="notice"><h1>${label}</h1><p>This file type does not have a Canvas renderer yet.</p><a class="download" href="${download}">Download file</a></section>`,
  };
}

function rewriteRelativeUrls(options) {
  return (tree) => {
    visit(tree, (node) => {
      if ((node.type !== "image" && node.type !== "link") || typeof node.url !== "string") return;
      node.url = rewriteUrl(node.url, node.type, options.file, options.context);
    });
  };
}

function visit(node, callback) {
  callback(node);
  if (!Array.isArray(node.children)) return;
  for (const child of node.children) visit(child, callback);
}

function rewriteUrl(value, nodeType, file, context) {
  const trimmed = value.trim();
  if (
    !trimmed ||
    trimmed.startsWith("#") ||
    trimmed.startsWith("?") ||
    trimmed.startsWith("//") ||
    /^[a-z][a-z\d+.-]*:/i.test(trimmed)
  ) {
    return value;
  }

  const match = trimmed.match(/^([^?#]*)([?#].*)?$/);
  const rawPath = match?.[1] || "";
  const suffix = match?.[2] || "";
  let decoded;
  try {
    decoded = decodeURIComponent(rawPath);
  } catch {
    decoded = rawPath;
  }

  const relative = rawPath.startsWith("/")
    ? decoded.replace(/^[/\\]+/, "")
    : path.join(path.dirname(file.relativePath), decoded);
  const url = nodeType === "image"
    ? context.assetUrl(relative)
    : context.documentUrl(relative);
  return `${url}${suffix.startsWith("#") ? suffix : ""}`;
}

async function streamEvents(req, res, root, requestedPath) {
  const target = await resolveWatchTarget(root, requestedPath);
  res.writeHead(200, {
    "content-type": "text/event-stream; charset=utf-8",
    "cache-control": "no-store",
    "connection": "keep-alive",
  });
  res.write("event: ready\ndata: {}\n\n");

  let timer = null;
  const watcher = fs.watch(target.directory, (eventType, filename) => {
    const changed = filename === null || sameName(String(filename), target.basename);
    if (!changed) return;
    clearTimeout(timer);
    timer = setTimeout(() => {
      res.write(`event: change\ndata: ${JSON.stringify({ eventType })}\n\n`);
    }, 75);
  });
  const heartbeat = setInterval(() => res.write(": keep-alive\n\n"), 15_000);
  const close = () => {
    clearTimeout(timer);
    clearInterval(heartbeat);
    watcher.close();
  };
  req.on("close", close);
  res.on("close", close);
}

// Serves the bundled Monaco editor so the source view works without network access.
async function sendVendorFile(res, requestedPath) {
  let decoded;
  try {
    decoded = decodeURIComponent(requestedPath);
  } catch {
    throw new HttpError(400, "Invalid vendor path");
  }
  if (decoded.includes("\0") || path.isAbsolute(decoded)) throw new HttpError(403, "Invalid vendor path");

  const candidate = path.resolve(MONACO_ROOT, decoded);
  if (!isWithin(MONACO_ROOT, candidate)) throw new HttpError(403, "Path escapes the vendor root");

  let stat;
  try {
    stat = await fsp.stat(candidate);
  } catch {
    throw new HttpError(404, "Monaco assets are not installed");
  }
  if (!stat.isFile()) throw new HttpError(404, "Not found");

  res.writeHead(200, securityHeaders({
    "content-type": MIME_TYPES.get(path.extname(candidate).toLowerCase()) || "application/octet-stream",
    "content-length": stat.size,
    "cache-control": "no-cache",
  }));
  await new Promise((resolve, reject) => {
    const stream = fs.createReadStream(candidate);
    stream.on("error", reject);
    stream.on("end", resolve);
    stream.pipe(res);
  });
}

// Monaco ships hashed worker bundles, so the matching asset is resolved at request time.
async function monacoWorkerBootstrap(label) {
  const prefix = MONACO_WORKER_PREFIXES.get(String(label || "")) || "editor.worker-";
  const asset = await findMonacoAsset(prefix);
  if (!asset) throw new HttpError(404, "Monaco worker assets are not installed");
  return `import "./${asset}";\n`;
}

async function findMonacoAsset(prefix) {
  let entries;
  try {
    entries = await fsp.readdir(path.join(MONACO_ROOT, "assets"));
  } catch {
    return null;
  }
  return entries.find((entry) => entry.startsWith(prefix) && entry.endsWith(".js")) || null;
}

async function sendAsset(req, res, file, download) {
  const range = parseRange(req.headers.range, file.stat.size);
  const status = range ? 206 : 200;
  const start = range?.start ?? 0;
  const end = range?.end ?? Math.max(0, file.stat.size - 1);
  const headers = {
    "accept-ranges": "bytes",
    "cache-control": "no-store",
    "content-type": file.mime,
    "content-length": file.stat.size === 0 ? 0 : end - start + 1,
    "x-content-type-options": "nosniff",
  };
  if (range) headers["content-range"] = `bytes ${start}-${end}/${file.stat.size}`;
  if (download) {
    headers["content-disposition"] = `attachment; filename*=UTF-8''${encodeURIComponent(path.basename(file.relativePath))}`;
  }
  res.writeHead(status, headers);
  if (file.stat.size === 0) {
    res.end();
    return;
  }
  await new Promise((resolve, reject) => {
    const stream = fs.createReadStream(file.absolutePath, { start, end });
    stream.on("error", reject);
    stream.on("end", resolve);
    stream.pipe(res);
  });
}

function parseRange(value, size) {
  if (!value || size <= 0) return null;
  const match = /^bytes=(\d*)-(\d*)$/.exec(value);
  if (!match) return null;
  let start = match[1] ? Number(match[1]) : 0;
  let end = match[2] ? Number(match[2]) : size - 1;
  if (!match[1] && match[2]) {
    start = Math.max(0, size - Number(match[2]));
    end = size - 1;
  }
  if (!Number.isInteger(start) || !Number.isInteger(end) || start < 0 || start > end || start >= size) return null;
  return { start, end: Math.min(end, size - 1) };
}

async function getRoot(value) {
  const resolved = path.resolve(String(value));
  const realPath = await fsp.realpath(resolved);
  const stat = await fsp.stat(realPath);
  if (!stat.isDirectory()) throw new Error(`Canvas root is not a directory: ${value}`);
  return { realPath };
}

async function resolveExistingFile(root, requestedPath) {
  const candidate = resolveCandidate(root, requestedPath);
  let absolutePath;
  try {
    absolutePath = await fsp.realpath(candidate);
  } catch (error) {
    if (error.code === "ENOENT") throw new HttpError(404, `File not found: ${requestedPath}`);
    throw error;
  }
  if (!isWithin(root.realPath, absolutePath)) throw new HttpError(403, "Path escapes the Canvas root");
  const stat = await fsp.stat(absolutePath);
  if (!stat.isFile()) throw new HttpError(400, "Canvas can only preview files");
  const relativePath = toUrlPath(path.relative(root.realPath, absolutePath));
  const extension = path.extname(absolutePath).toLowerCase();
  return {
    absolutePath,
    relativePath,
    extension,
    mime: MIME_TYPES.get(extension) || "application/octet-stream",
    stat,
  };
}

async function resolveWatchTarget(root, requestedPath) {
  const candidate = resolveCandidate(root, requestedPath);
  const directory = await fsp.realpath(path.dirname(candidate));
  if (!isWithin(root.realPath, directory)) throw new HttpError(403, "Path escapes the Canvas root");
  return { directory, basename: path.basename(candidate) };
}

function resolveCandidate(root, requestedPath) {
  if (typeof requestedPath !== "string" || !requestedPath.trim()) {
    throw new HttpError(400, "A project-relative path is required");
  }
  if (requestedPath.includes("\0") || path.isAbsolute(requestedPath)) {
    throw new HttpError(403, "Only project-relative paths are allowed");
  }
  const candidate = path.resolve(root.realPath, requestedPath);
  if (!isWithin(root.realPath, candidate)) throw new HttpError(403, "Path escapes the Canvas root");
  return candidate;
}

function isWithin(root, candidate) {
  const relative = path.relative(root, candidate);
  return relative === "" || (!relative.startsWith(`..${path.sep}`) && relative !== ".." && !path.isAbsolute(relative));
}

// The source view only applies to files whose bytes are readable as text.
function hasSourceView(rendered) {
  return rendered.kind === "markdown" || rendered.kind === "text";
}

function sourceLanguage(file) {
  return MONACO_LANGUAGES.get(file.extension) || "plaintext";
}

function isTextFile(file) {
  return file.mime.startsWith("text/") ||
    file.mime.includes("json") ||
    file.mime.includes("xml") ||
    TEXT_EXTENSIONS.has(file.extension);
}

function renderShell({ title, body, targetPath = "", kind = "landing", language = "" }) {
  const safeTitle = escapeHtml(title);
  const boot = safeJson({ path: targetPath, language });
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${safeTitle} · Canvas</title>
  <style>
    :root { color-scheme: light dark; font-family: Inter, ui-sans-serif, system-ui, sans-serif; background: #f6f5f2; color: #20201f; }
    * { box-sizing: border-box; }
    body { margin: 0; min-height: 100vh; }
    .topbar { position: sticky; top: 0; z-index: 2; display: flex; align-items: center; gap: 12px; min-height: 44px; padding: 8px 18px; border-bottom: 1px solid #dedbd4; background: color-mix(in srgb, #f6f5f2 92%, transparent); backdrop-filter: blur(12px); }
    .brand { font-weight: 750; letter-spacing: -.02em; }
    .path { overflow: hidden; color: #68645d; font: 12px ui-monospace, SFMono-Regular, Consolas, monospace; text-overflow: ellipsis; white-space: nowrap; }
    .view-toggle { margin-left: auto; flex: none; border: 1px solid #d5d1c9; border-radius: 7px; background: #fff; color: #20201f; padding: 5px 11px; font: inherit; font-size: 12.5px; cursor: pointer; }
    .view-toggle:hover { border-color: #b6b1a7; }
    main { width: min(900px, calc(100% - 36px)); margin: 0 auto; padding: 44px 0 80px; }
    .source { display: none; }
    body[data-view="source"] main { width: 100%; padding: 0; }
    body[data-view="source"] .rendered { display: none; }
    body[data-view="source"] .source { display: block; }
    .editor { height: calc(100vh - 45px); }
    .source pre { height: calc(100vh - 45px); margin: 0; border: 0; border-radius: 0; }
    .markdown { font-size: 17px; line-height: 1.72; }
    .markdown h1, .markdown h2, .markdown h3 { margin: 1.7em 0 .65em; line-height: 1.22; letter-spacing: -.025em; }
    .markdown h1:first-child { margin-top: 0; }
    .markdown a { color: #1267a5; }
    .markdown img { display: block; max-width: 100%; height: auto; margin: 1.5em auto; border-radius: 8px; }
    .markdown blockquote { margin-left: 0; padding-left: 1em; border-left: 3px solid #aaa59b; color: #625f58; }
    code { border-radius: 4px; background: #e9e7e1; padding: .12em .35em; font: .9em ui-monospace, SFMono-Regular, Consolas, monospace; }
    pre { overflow: auto; padding: 18px; border: 1px solid #dedbd4; border-radius: 8px; background: #efede8; line-height: 1.55; }
    pre code { padding: 0; background: transparent; }
    table { display: block; overflow-x: auto; width: 100%; border-collapse: collapse; }
    th, td { padding: 8px 12px; border: 1px solid #d5d1c9; }
    .media-preview { display: grid; place-items: center; min-height: 50vh; margin: 0; }
    .media-preview img, .media-preview video { max-width: 100%; max-height: 78vh; }
    .media-preview audio { width: min(600px, 100%); }
    .pdf-preview { width: 100%; height: calc(100vh - 130px); border: 1px solid #d5d1c9; border-radius: 8px; }
    .notice { padding: 28px; border: 1px solid #d5d1c9; border-radius: 10px; background: #fff; }
    .notice h1 { margin-top: 0; }
    .download { display: inline-block; margin-top: 8px; border-radius: 7px; background: #20201f; color: #fff; padding: 10px 14px; text-decoration: none; }
    @media (prefers-color-scheme: dark) {
      :root { background: #181817; color: #e8e6e1; }
      .topbar { border-color: #393734; background: color-mix(in srgb, #181817 90%, transparent); }
      .path, .markdown blockquote { color: #aaa69e; }
      code, pre { border-color: #3b3935; background: #242321; }
      th, td, .pdf-preview, .notice { border-color: #3b3935; }
      .notice { background: #20201e; }
      .markdown a { color: #75b9ed; }
      .download { background: #e8e6e1; color: #181817; }
      .view-toggle { border-color: #3b3935; background: #242321; color: #e8e6e1; }
      .view-toggle:hover { border-color: #575450; }
    }
    @media (max-width: 600px) { main { width: min(100% - 28px, 900px); padding-top: 28px; } .markdown { font-size: 16px; } }
  </style>
</head>
<body data-kind="${escapeHtml(kind)}" data-view="rendered">
  <header class="topbar">
    <span class="brand">Canvas</span>${targetPath ? `<span class="path">${escapeHtml(targetPath)}</span>` : ""}
    ${language ? '<button type="button" id="view-toggle" class="view-toggle" title="Toggle rendered preview and source (Ctrl+U)">Source</button>' : ""}
  </header>
  <main>
    <div class="rendered ${kind === "markdown" ? "markdown" : kind}">${body}</div>
    ${language ? '<div class="source"><div class="editor" id="editor"></div></div>' : ""}
  </main>
  <script>
    const boot = ${boot};

    if (boot.path) {
      const events = new EventSource("/events?path=" + encodeURIComponent(boot.path));
      events.addEventListener("change", () => location.reload());
    }

    const toggle = document.getElementById("view-toggle");
    if (toggle) {
      const VIEW_KEY = "canvas:view";
      const host = document.getElementById("editor");
      let monacoPromise = null;
      let ready = false;

      const loadMonaco = () => {
        if (monacoPromise) return monacoPromise;
        monacoPromise = new Promise((resolve, reject) => {
          const script = document.createElement("script");
          script.src = "/vendor/monaco/vs/loader.js";
          script.onerror = () => reject(new Error("Monaco assets are not available"));
          script.onload = () => {
            // getWorker keeps the classic worker bootstrap below; getWorkerUrl would force a module worker.
            window.MonacoEnvironment = {
              getWorker: (id, label) => new Worker(
                "/vendor/monaco/vs/assets/canvas-worker.js?label=" + encodeURIComponent(label),
                { name: label, type: "module" },
              ),
            };
            window.require.config({ paths: { vs: "/vendor/monaco/vs" } });
            window.require(["vs/editor/editor.main"], () => resolve(window.monaco), reject);
          };
          document.head.appendChild(script);
        });
        return monacoPromise;
      };

      const readSource = async () => {
        const response = await fetch("/asset?path=" + encodeURIComponent(boot.path));
        if (!response.ok) throw new Error("Could not read the source file");
        return response.text();
      };

      // Falls back to plain text when the bundled editor is missing or fails to load.
      const showPlainSource = (text) => {
        const pre = document.createElement("pre");
        const code = document.createElement("code");
        code.textContent = text;
        pre.appendChild(code);
        host.replaceWith(pre);
      };

      const mountSource = async () => {
        if (ready) return;
        ready = true;
        const text = await readSource();
        try {
          const monaco = await loadMonaco();
          const dark = window.matchMedia("(prefers-color-scheme: dark)");
          const editor = monaco.editor.create(host, {
            value: text,
            language: boot.language,
            theme: dark.matches ? "vs-dark" : "vs",
            readOnly: true,
            domReadOnly: true,
            automaticLayout: true,
            wordWrap: "on",
            minimap: { enabled: false },
            scrollBeyondLastLine: false,
            renderWhitespace: "selection",
            fontSize: 13,
            padding: { top: 12, bottom: 12 },
          });
          dark.addEventListener("change", (event) => {
            monaco.editor.setTheme(event.matches ? "vs-dark" : "vs");
          });
          if (document.body.dataset.view === "source") editor.layout();
        } catch {
          showPlainSource(text);
        }
      };

      const setView = (view) => {
        document.body.dataset.view = view;
        toggle.textContent = view === "source" ? "Preview" : "Source";
        try { localStorage.setItem(VIEW_KEY, view); } catch {}
        if (view === "source") mountSource().catch(() => {});
      };

      toggle.addEventListener("click", () => {
        setView(document.body.dataset.view === "source" ? "rendered" : "source");
      });
      document.addEventListener("keydown", (event) => {
        if ((event.ctrlKey || event.metaKey) && !event.shiftKey && !event.altKey && event.key.toLowerCase() === "u") {
          event.preventDefault();
          toggle.click();
        }
      });

      let stored = "rendered";
      try { stored = localStorage.getItem(VIEW_KEY) || "rendered"; } catch {}
      setView(stored === "source" ? "source" : "rendered");
    }
  </script>
</body>
</html>`;
}

function sendHtml(res, html, status = 200) {
  res.writeHead(status, securityHeaders({
    "content-type": "text/html; charset=utf-8",
    "cache-control": "no-store",
  }));
  res.end(html);
}

function sendText(res, body, contentType, status = 200) {
  res.writeHead(status, securityHeaders({
    "content-type": contentType,
    "cache-control": "no-cache",
  }));
  res.end(body);
}

function sendJson(res, value, status = 200) {
  res.writeHead(status, securityHeaders({
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store",
  }));
  res.end(JSON.stringify(value));
}

function sendError(res, error) {
  if (res.headersSent) {
    res.destroy(error);
    return;
  }
  const status = error instanceof HttpError ? error.status : 500;
  const message = status === 500 ? "Canvas could not render this file." : error.message;
  sendHtml(res, renderShell({
    title: `Error ${status}`,
    body: `<section class="notice"><h1>Error ${status}</h1><p>${escapeHtml(message)}</p></section>`,
  }), status);
}

function securityHeaders(headers) {
  return {
    ...headers,
    "content-security-policy": "default-src 'self'; connect-src 'self'; font-src 'self' data:; frame-src 'self'; img-src 'self' data:; media-src 'self'; object-src 'none'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; worker-src 'self' blob:",
    "referrer-policy": "no-referrer",
    "x-content-type-options": "nosniff",
  };
}

function openResult(state, relativePath) {
  const url = relativePath ? `${state.url}/?path=${encodeURIComponent(relativePath)}` : `${state.url}/`;
  return {
    running: true,
    pid: state.pid,
    root: state.root,
    port: state.port,
    url,
    markdownLink: `[Open Canvas](${url})`,
  };
}

function runtimeDirs(root) {
  const keySource = process.platform === "win32" ? root.realPath.toLowerCase() : root.realPath;
  const key = crypto.createHash("sha256").update(keySource).digest("hex").slice(0, 16);
  const dir = path.join(os.tmpdir(), APP_NAME, key);
  return {
    dir,
    stateFile: path.join(dir, "state.json"),
    logFile: path.join(dir, "server.log"),
  };
}

async function readState(dirs) {
  try {
    return JSON.parse(await fsp.readFile(dirs.stateFile, "utf8"));
  } catch {
    return null;
  }
}

async function writeJson(file, value) {
  await fsp.mkdir(path.dirname(file), { recursive: true });
  await fsp.writeFile(file, `${JSON.stringify(value, null, 2)}\n`, "utf8");
}

async function removeFile(file) {
  try {
    await fsp.rm(file, { force: true });
  } catch {
    // Ignore stale-state cleanup failures.
  }
}

async function pingState(state) {
  if (!state?.url) return null;
  try {
    const response = await fetch(`${state.url}/api/state`, { signal: AbortSignal.timeout(1000) });
    if (!response.ok) return null;
    const live = await response.json();
    return live.app === APP_NAME ? live : null;
  } catch {
    return null;
  }
}

function parseArgs(argv) {
  const args = {};
  for (let index = 0; index < argv.length; index += 1) {
    const item = argv[index];
    if (!item.startsWith("--")) continue;
    const key = item.slice(2);
    const next = argv[index + 1];
    if (!next || next.startsWith("--")) {
      args[key] = true;
    } else {
      args[key] = next;
      index += 1;
    }
  }
  return args;
}

function parsePort(value) {
  if (value === undefined) return 0;
  const port = Number(value);
  if (!Number.isInteger(port) || port < 0 || port > 65535) throw new Error(`Invalid port: ${value}`);
  return port;
}

function samePath(left, right) {
  if (!left || !right) return false;
  return process.platform === "win32"
    ? path.resolve(left).toLowerCase() === path.resolve(right).toLowerCase()
    : path.resolve(left) === path.resolve(right);
}

function sameName(left, right) {
  return process.platform === "win32" ? left.toLowerCase() === right.toLowerCase() : left === right;
}

function toUrlPath(value) {
  return String(value).split(path.sep).join("/");
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function safeJson(value) {
  return JSON.stringify(value).replaceAll("<", "\\u003c").replaceAll(">", "\\u003e").replaceAll("&", "\\u0026");
}

function sleep(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

function printJson(value) {
  process.stdout.write(`${JSON.stringify(value, null, 2)}\n`);
}

function printHelp() {
  process.stdout.write(`Usage:
  node canvas-server.js start --path <relative-file> [--root <directory>]
  node canvas-server.js status [--root <directory>]
  node canvas-server.js stop [--root <directory>]

Canvas binds to 127.0.0.1 on an available port and renders ?path=<relative-file>.
`);
}

function isMainModule() {
  return process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
}

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}
