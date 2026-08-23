#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { createRequire } from "node:module";

function usage() {
  console.error(`Usage:
  node calculate-ssaju.mjs --input birth.json [--format compact|markdown|json|all]

The current working directory must be a Node project with ssaju installed.
`);
}

function parseArgs(argv) {
  const args = { format: "compact" };
  for (let i = 2; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--input") {
      args.input = argv[++i];
    } else if (arg === "--format") {
      args.format = argv[++i];
    } else if (arg === "--help" || arg === "-h") {
      args.help = true;
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }
  return args;
}

function loadInput(filePath) {
  const fullPath = path.resolve(process.cwd(), filePath);
  const input = JSON.parse(fs.readFileSync(fullPath, "utf8").replace(/^\uFEFF/, ""));
  if (typeof input.now === "string") {
    input.now = new Date(input.now);
  }
  return input;
}

async function loadSsaju() {
  const requireFromCwd = createRequire(path.join(process.cwd(), "package.json"));
  try {
    const resolved = requireFromCwd.resolve("ssaju");
    return import(pathToFileURL(resolved).href);
  } catch (error) {
    throw new Error("Cannot resolve package 'ssaju' from the current working directory. Run `npm install ssaju` first.");
  }
}

function replacer(_key, value) {
  if (typeof value === "function") return undefined;
  return value;
}

async function main() {
  const args = parseArgs(process.argv);
  if (args.help || !args.input) {
    usage();
    process.exit(args.help ? 0 : 2);
  }

  if (!["compact", "markdown", "json", "all"].includes(args.format)) {
    throw new Error("--format must be one of: compact, markdown, json, all");
  }

  const { calculateSaju } = await loadSsaju();
  const result = calculateSaju(loadInput(args.input));

  if (args.format === "compact") {
    console.log(result.toCompact());
  } else if (args.format === "markdown") {
    console.log(result.toMarkdown());
  } else if (args.format === "json") {
    console.log(JSON.stringify(result, replacer, 2));
  } else {
    console.log(JSON.stringify({
      compact: result.toCompact(),
      markdown: result.toMarkdown(),
      result,
    }, replacer, 2));
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
