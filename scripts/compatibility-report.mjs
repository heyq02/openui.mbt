import { execFileSync } from "node:child_process";
import { appendFileSync, readFileSync, writeFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

const ANSI = /\u001b\[[0-9;]*m/g;

export function parseVitestLog(text) {
  const clean = text.replace(ANSI, "");
  let passed = 0;
  let total = 0;
  let reports = 0;
  for (const match of clean.matchAll(/Tests[ \t]+([^\n\r]*)/g)) {
    const line = match[1].trim();
    const totalMatch = line.match(/\((\d+)\)\s*$/);
    if (!totalMatch) continue;
    const passedMatch = line.match(/(\d+)\s+passed/);
    passed += passedMatch ? Number(passedMatch[1]) : 0;
    total += Number(totalMatch[1]);
    reports += 1;
  }
  return { passed, total, reports };
}

export function buildBadge(version, stages) {
  const workspace = stages.find((stage) => stage.name === "workspace");
  const passed = workspace ? workspace.passed : 0;
  const total = workspace ? workspace.total : 0;
  const ok = stages.every((stage) => stage.reports > 0 && stage.passed === stage.total);
  return {
    schemaVersion: 1,
    label: `OpenUI ${version}`,
    message: `${passed}/${total}`,
    color: ok ? "EDED91" : "e05d44",
    labelColor: "564341",
    isError: !ok,
    style: "flat-square",
    cacheSeconds: 300,
  };
}

export function summary(badge, stages) {
  const lines = [`### ${badge.label}`, "", "| Stage | Result |", "| --- | --- |"];
  for (const stage of stages) {
    lines.push(`| ${stage.name} | ${stage.passed}/${stage.total} |`);
  }
  lines.push("", `Workspace compatibility: ${badge.message}`, "");
  return lines.join("\n");
}

function parseArgs(argv) {
  const args = {
    packagePath: "",
    out: "",
    stages: [],
    check: "",
    publish: "",
  };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--package") {
      args.packagePath = argv[(i += 1)];
    } else if (arg === "--out") {
      args.out = argv[(i += 1)];
    } else if (arg === "--stage") {
      const spec = argv[(i += 1)];
      const eq = spec.indexOf("=");
      args.stages.push({
        name: spec.slice(0, eq),
        file: spec.slice(eq + 1),
      });
    } else if (arg === "--check") {
      args.check = argv[(i += 1)];
    } else if (arg === "--publish") {
      args.publish = argv[(i += 1)];
    } else {
      throw new Error(`Unknown argument ${arg}`);
    }
  }
  return args;
}

function readBadge(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

function publish(path) {
  const repo = process.env.GITHUB_REPOSITORY;
  const token = process.env.GH_TOKEN || process.env.GITHUB_TOKEN;
  if (!repo || !token) {
    throw new Error("GITHUB_REPOSITORY and GH_TOKEN are required to publish");
  }
  const local = readFileSync(path);
  const encoded = local.toString("base64");
  const apiPath = `repos/${repo}/contents/${path}`;
  const current = gh(["api", `${apiPath}?ref=main`]);
  const remote = JSON.parse(current);
  const remoteBytes = Buffer.from(remote.content.replace(/\n/g, ""), "base64");
  if (remoteBytes.equals(local)) {
    console.log("Compatibility badge is unchanged.");
    return;
  }
  gh([
    "api",
    "--method",
    "PUT",
    apiPath,
    "-f",
    "message=chore: update OpenUI compatibility badge [skip ci]",
    "-f",
    `content=${encoded}`,
    "-f",
    `sha=${remote.sha}`,
    "-f",
    "branch=main",
  ]);
  console.log("Published compatibility badge.");
}

function gh(args) {
  return execFileSync("gh", args, {
    encoding: "utf8",
    env: process.env,
  });
}

function report(args) {
  const manifest = JSON.parse(readFileSync(args.packagePath, "utf8"));
  const version = manifest.version;
  if (typeof version !== "string" || version.length === 0) {
    throw new Error(`Missing version in ${args.packagePath}`);
  }
  const stages = args.stages.map((stage) => {
    const parsed = parseVitestLog(readFileSync(stage.file, "utf8"));
    return { name: stage.name, ...parsed };
  });
  const badge = buildBadge(version, stages);
  const text = `${JSON.stringify(badge, null, 2)}\n`;
  writeFileSync(args.out, text);
  const rendered = summary(badge, stages);
  console.log(rendered);
  if (process.env.GITHUB_STEP_SUMMARY) {
    appendFileSync(process.env.GITHUB_STEP_SUMMARY, `${rendered}\n`);
  }
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.check) {
    const badge = readBadge(args.check);
    console.log(`${badge.label} ${badge.message}`);
    if (badge.isError) process.exit(1);
    return;
  }
  if (args.publish) {
    publish(args.publish);
    return;
  }
  report(args);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    main();
  } catch (error) {
    console.error(error instanceof Error ? error.message : error);
    process.exit(1);
  }
}
