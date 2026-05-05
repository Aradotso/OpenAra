#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import {
  chmodSync,
  cpSync,
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  rmSync,
  statSync,
  unlinkSync,
  writeFileSync,
} from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, "..", "..");
const defaultOutDir = path.join(repoRoot, "dist", "npm");
const appBundleName = "OpenAra.app";
const appExecutableName = "OpenAra";
const metaPackageNames = [
  "@openara/cli",
];
const runtimeTargets = [
  {
    os: "darwin",
    cpu: "arm64",
    kind: "macos-app",
    executablePath: ["dist", appBundleName, "Contents", "MacOS", appExecutableName],
  },
  {
    os: "darwin",
    cpu: "x64",
    kind: "macos-app",
    executablePath: ["dist", appBundleName, "Contents", "MacOS", appExecutableName],
  },
];
const packageNames = [
  ...metaPackageNames,
];

function parseArgs(argv) {
  const options = {
    arch: "universal",
    configuration: "release",
    outDir: defaultOutDir,
    packageNames: [...packageNames],
    skipBuild: false,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];

    switch (arg) {
      case "--arch":
        options.arch = argv[index + 1];
        index += 1;
        break;
      case "--configuration":
        options.configuration = argv[index + 1];
        index += 1;
        break;
      case "--out-dir":
        options.outDir = path.resolve(repoRoot, argv[index + 1]);
        index += 1;
        break;
      case "--package":
        options.packageNames = [argv[index + 1]];
        index += 1;
        break;
      case "--skip-build":
        options.skipBuild = true;
        break;
      case "-h":
      case "--help":
        printHelp();
        process.exit(0);
      default:
        throw new Error(`Unknown argument: ${arg}`);
    }
  }

  for (const packageName of options.packageNames) {
    if (!packageNames.includes(packageName)) {
      throw new Error(`Unsupported package name: ${packageName}`);
    }
  }

  return options;
}

function printHelp() {
  process.stdout.write(`Usage: node ./scripts/npm/build-packages.mjs [options]

Options:
  --configuration debug|release
  --arch native|arm64|x86_64|universal  macOS app build arch. Defaults to universal.
  --out-dir <dir>
  --package <package-name>
  --skip-build

Packages:
${packageNames.map((name) => `  - ${name}`).join("\n")}
`);
}

function run(command, args, options = {}) {
  const result = spawnSync(command, args, {
    cwd: repoRoot,
    stdio: "inherit",
    ...options,
  });

  if (result.status !== 0) {
    throw new Error(`${command} ${args.join(" ")} failed with exit code ${result.status ?? "unknown"}`);
  }
}

function readJSON(filePath) {
  return JSON.parse(readFileSync(filePath, "utf-8"));
}

function removeJunkFiles(targetPath) {
  if (!existsSync(targetPath)) {
    return;
  }

  const entryStat = statSync(targetPath);
  if (entryStat.isDirectory()) {
    for (const entry of readdirSync(targetPath)) {
      removeJunkFiles(path.join(targetPath, entry));
    }
    return;
  }

  if (path.basename(targetPath) === ".DS_Store") {
    unlinkSync(targetPath);
  }
}

function ensureBuilt(configuration, arch) {
  run(path.join(repoRoot, "scripts", "build-openara-app.sh"), [
    "--configuration",
    configuration,
    "--arch",
    arch,
  ]);
}

function writeExecutable(filePath, content) {
  writeFileSync(filePath, content, "utf-8");
  chmodSync(filePath, 0o755);
}

function platformLaunchTable() {
  return Object.fromEntries(
    runtimeTargets.map((runtimeTarget) => [
      `${runtimeTarget.os}-${runtimeTarget.cpu}`,
      {
        executablePath: runtimeTarget.executablePath,
      },
    ]),
  );
}

function renderLauncher() {
  return `#!/usr/bin/env node
const { spawn } = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const platformPackages = ${JSON.stringify(platformLaunchTable(), null, 2)};
const packageRoot = path.resolve(__dirname, "..");
const args = process.argv.slice(2);
const command = args[0] || "";
const homeOpenaraRoot = path.join(os.homedir(), ".openara");
const homeCurrentLink = path.join(homeOpenaraRoot, "current");
const installCommands = new Map([
  ["install-claude-mcp", "install-claude-mcp.sh"],
  ["install-clauce-mcp", "install-claude-mcp.sh"],
  ["install-cursor-mcp", "install-cursor-mcp.sh"],
  ["install-gemini-mcp", "install-gemini-mcp.sh"],
  ["install-codex-mcp", "install-codex-mcp.sh"],
  ["install-opencode-mcp", "install-opencode-mcp.sh"],
  ["install-codex-plugin", "install-codex-plugin.sh"],
]);

function printLauncherHelp() {
  console.log(\`OpenAra

Usage:
  openara [command] [options]
  openara

Commands:
  mcp                  Start the stdio MCP server.
  doctor               Print permission status and launch onboarding if needed on macOS.
  list-apps            Print running or recently used apps.
  snapshot <app>       Print the current accessibility snapshot for an app.
  call <tool>          Call one tool, or run a JSON array of tool calls.
  turn-ended           Notify the running MCP process that the host turn ended.
  install-claude-mcp   Install the MCP server into Claude Code (~/.claude.json) and Claude Desktop (~/Library/Application Support/Claude/claude_desktop_config.json).
  install-cursor-mcp   Install the MCP server into ~/.cursor/mcp.json.
  install-gemini-mcp   Install the MCP server into Gemini CLI config.
  install-codex-mcp    Install the MCP server into ~/.codex/config.toml.
  install-opencode-mcp Install the MCP server into ~/.config/opencode.
  install-codex-plugin Install this npm package into the local Codex plugin cache.
  help [command]       Show general or command-specific help.
  version              Print the CLI version.

Global options:
  -h, --help           Show help.
  -v, --version        Show version.

Notes:
  This npm package bundles native runtimes for supported platforms and selects the current os-arch at launch.
  Use 'openara help <command>' for command-specific help.\`);
}

function printInstallHelp(scriptName, usage) {
  console.log(\`Usage:
  \${usage}

This helper updates a local MCP or plugin config to run:
  openara mcp

Script:
  \${scriptName}\`);
}

function fail(message) {
  console.error(message);
  process.exit(1);
}

function spawnAndExit(executable, executableArgs) {
  const child = spawn(executable, executableArgs, {
    stdio: "inherit",
    windowsHide: false,
  });

  child.on("error", (error) => {
    fail(\`Failed to start \${executable}: \${error.message}\`);
  });

  for (const signal of ["SIGINT", "SIGTERM"]) {
    process.on(signal, () => {
      child.kill(signal);
    });
  }

  child.on("exit", (code, signal) => {
    if (signal) {
      process.exit(1);
    }
    process.exit(code ?? 0);
  });
}

function runInstallCommand(scriptName, scriptArgs) {
  if (process.platform !== "darwin") {
    fail(\`\${command} requires macOS. OpenAra is macOS-only.\`);
  }

  const scriptPath = path.join(packageRoot, "scripts", scriptName);
  if (!fs.existsSync(scriptPath)) {
    fail(\`Missing installer helper at \${scriptPath}.\`);
  }

  spawnAndExit(scriptPath, scriptArgs);
}

function resolveNativeExecutable() {
  const platformKey = \`\${process.platform}-\${process.arch}\`;
  const target = platformPackages[platformKey];
  if (!target) {
    const supported = Object.keys(platformPackages).sort().join(", ");
    fail(\`Unsupported platform \${platformKey}. Supported platforms: \${supported}.\`);
  }

  if (process.platform === "darwin") {
    // Prefer /Applications/OpenAra.app — it is the only path that surfaces
    // as a manageable entry in System Settings → Privacy & Security, and
    // the path that \`openara doctor\`'s stale-grant classifier treats as
    // canonical. The background auto-updater (scripts/auto-update.mjs)
    // keeps this copy fresh when /Applications is writable.
    //
    // Fall back to ~/.openara/current only when /Applications is missing
    // (e.g. /Applications is read-only on this account, or postinstall
    // was skipped via --ignore-scripts). Apps under ~/.openara/current
    // never appear in the Privacy panel toggle list and can only obtain
    // TCC permission via responsible-process inheritance from the parent
    // agent, which is fragile.
    const installedAppExecutable = "/Applications/OpenAra.app/Contents/MacOS/OpenAra";
    const homeUpdatedExecutable = path.join(
      homeCurrentLink,
      "dist",
      "OpenAra.app",
      "Contents",
      "MacOS",
      "OpenAra",
    );
    // The auto-updater writes ~/.openara/prefer-home-current when it fails
    // to refresh /Applications/OpenAra.app (read-only volume, denied perms,
    // hardened-bundle protection, …). When the marker is present and the
    // home-current copy actually exists, use it so the user runs the
    // freshly-staged version instead of a stale /Applications/ copy.
    const preferHomeMarker = path.join(homeOpenaraRoot, "prefer-home-current");
    if (fs.existsSync(preferHomeMarker) && fs.existsSync(homeUpdatedExecutable)) {
      return homeUpdatedExecutable;
    }

    if (fs.existsSync(installedAppExecutable)) {
      return installedAppExecutable;
    }

    if (fs.existsSync(homeUpdatedExecutable)) {
      return homeUpdatedExecutable;
    }
  }

  const executablePath = path.join(packageRoot, ...target.executablePath);
  if (!fs.existsSync(executablePath)) {
    fail(\`Missing bundled native runtime for \${platformKey} at \${executablePath}.

Reinstall with:
  npm install -g @openara/cli\`);
  }

  return executablePath;
}

function readPackageVersion() {
  try {
    const pkg = JSON.parse(fs.readFileSync(path.join(packageRoot, "package.json"), "utf-8"));
    return pkg.version || "0.0.0";
  } catch (_error) {
    return "0.0.0";
  }
}

function effectiveInstalledVersion() {
  // If we're already running from ~/.openara/current/<v>/, the version is
  // baked into the symlink target. Otherwise fall back to package.json.
  try {
    const target = fs.readlinkSync(homeCurrentLink);
    const version = path.basename(target);
    if (/^\\d+\\.\\d+\\.\\d+/.test(version)) {
      return version;
    }
  } catch (_error) {}
  return readPackageVersion();
}

function spawnAutoUpdater() {
  if (process.env.OPENARA_AUTO_UPDATE === "off") return;
  if (process.platform !== "darwin") return;
  const updaterPath = path.join(packageRoot, "scripts", "auto-update.mjs");
  if (!fs.existsSync(updaterPath)) return;
  try {
    const child = spawn(
      process.execPath,
      [updaterPath, effectiveInstalledVersion()],
      { detached: true, stdio: "ignore", windowsHide: true },
    );
    child.unref();
  } catch (_error) {
    // Auto-update is best-effort; never let a failure here surface to the user.
  }
}

if (command === "-h" || command === "--help" || (command === "help" && args.length <= 1)) {
  printLauncherHelp();
  process.exit(0);
}

if (command === "help" && args[1] === "install-codex-plugin") {
  printInstallHelp("install-codex-plugin.sh", "openara install-codex-plugin");
  process.exit(0);
}

if (command === "help" && args[1] === "install-codex-mcp") {
  printInstallHelp("install-codex-mcp.sh", "openara install-codex-mcp");
  process.exit(0);
}

if (command === "help" && args[1] === "install-gemini-mcp") {
  printInstallHelp("install-gemini-mcp.sh", "openara install-gemini-mcp [--scope project|user]");
  process.exit(0);
}

if (command === "help" && args[1] === "install-opencode-mcp") {
  printInstallHelp("install-opencode-mcp.sh", "openara install-opencode-mcp");
  process.exit(0);
}

if (command === "help" && args[1] === "install-cursor-mcp") {
  printInstallHelp("install-cursor-mcp.sh", "openara install-cursor-mcp");
  process.exit(0);
}

if (command === "help" && (args[1] === "install-claude-mcp" || args[1] === "install-clauce-mcp")) {
  printInstallHelp("install-claude-mcp.sh", "openara install-claude-mcp");
  process.exit(0);
}

if (installCommands.has(command)) {
  const scriptName = installCommands.get(command);
  runInstallCommand(scriptName, args.slice(1));
} else {
  spawnAutoUpdater();
  spawnAndExit(resolveNativeExecutable(), args);
}
`;
}

function renderAutoUpdater(packageName) {
  return `#!/usr/bin/env node
// Background auto-updater for ${packageName}.
// Spawned detached + stdio:ignore from bin/openara, so it never affects the
// foreground process (including MCP stdio). On a fresh release it downloads
// the new tarball into ~/.openara/versions/<v>/, atomically replaces
// /Applications/OpenAra.app with the staged copy when /Applications is
// writable, and updates the ~/.openara/current fallback symlink. The next
// "openara" invocation picks up the new bundle automatically — no sudo,
// no \`npm install -g\` re-run.
//
// Why /Applications first: only that path surfaces as a manageable entry
// in System Settings → Privacy & Security. The ~/.openara/current copy
// kept around as a fallback for users whose /Applications is read-only
// (rare) or whose npm install ran with --ignore-scripts.
//
// Disable via OPENARA_AUTO_UPDATE=off.

import { spawnSync } from "node:child_process";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import * as https from "node:https";

const PACKAGE_NAME = "${packageName}";
const CHECK_INTERVAL_MS = 60 * 60 * 1000;
const REGISTRY_URL = \`https://registry.npmjs.org/\${PACKAGE_NAME.replace("/", "%2F")}/latest\`;

const home = os.homedir();
const root = path.join(home, ".openara");
const versionsDir = path.join(root, "versions");
const downloadsDir = path.join(root, "downloads");
const checkFile = path.join(root, "update-check.json");
const logFile = path.join(root, "update.log");
const currentLink = path.join(root, "current");
// Read by bin/openara to decide whether to prefer ~/.openara/current over
// /Applications/OpenAra.app. Created when refreshApplicationsCopy fails
// (so the user runs the freshly-staged copy instead of a stale one),
// removed on a successful refresh.
const preferHomeMarker = path.join(root, "prefer-home-current");

const installedVersion = process.argv[2] || "0.0.0";

function log(...parts) {
  try {
    fs.mkdirSync(root, { recursive: true });
    fs.appendFileSync(logFile, \`[\${new Date().toISOString()}] \${parts.join(" ")}\\n\`);
  } catch (_) {}
}

function readCheck() {
  try { return JSON.parse(fs.readFileSync(checkFile, "utf-8")); } catch (_) { return {}; }
}

function writeCheck(data) {
  try {
    fs.mkdirSync(root, { recursive: true });
    fs.writeFileSync(checkFile, JSON.stringify(data, null, 2));
  } catch (_) {}
}

function compareSemver(a, b) {
  const pa = String(a).split(".").map((n) => parseInt(n, 10) || 0);
  const pb = String(b).split(".").map((n) => parseInt(n, 10) || 0);
  for (let i = 0; i < 3; i += 1) {
    if ((pa[i] || 0) > (pb[i] || 0)) return 1;
    if ((pa[i] || 0) < (pb[i] || 0)) return -1;
  }
  return 0;
}

function fetchJSON(url, redirects = 0) {
  return new Promise((resolve, reject) => {
    https.get(url, { headers: { "User-Agent": \`\${PACKAGE_NAME}-auto-update\`, Accept: "application/json" } }, (res) => {
      if ((res.statusCode === 301 || res.statusCode === 302) && res.headers.location && redirects < 4) {
        res.resume();
        return fetchJSON(res.headers.location, redirects + 1).then(resolve, reject);
      }
      if (res.statusCode !== 200) {
        res.resume();
        return reject(new Error(\`HTTP \${res.statusCode} for \${url}\`));
      }
      const chunks = [];
      res.on("data", (c) => chunks.push(c));
      res.on("end", () => {
        try { resolve(JSON.parse(Buffer.concat(chunks).toString("utf-8"))); }
        catch (e) { reject(e); }
      });
      res.on("error", reject);
    }).on("error", reject);
  });
}

function fetchBuffer(url, redirects = 0) {
  return new Promise((resolve, reject) => {
    https.get(url, { headers: { "User-Agent": \`\${PACKAGE_NAME}-auto-update\` } }, (res) => {
      if ((res.statusCode === 301 || res.statusCode === 302) && res.headers.location && redirects < 4) {
        res.resume();
        return fetchBuffer(res.headers.location, redirects + 1).then(resolve, reject);
      }
      if (res.statusCode !== 200) {
        res.resume();
        return reject(new Error(\`HTTP \${res.statusCode} for \${url}\`));
      }
      const chunks = [];
      res.on("data", (c) => chunks.push(c));
      res.on("end", () => resolve(Buffer.concat(chunks)));
      res.on("error", reject);
    }).on("error", reject);
  });
}

function swapSymlink(targetVersionDir) {
  const tmpLink = \`\${currentLink}.tmp-\${process.pid}\`;
  try { fs.unlinkSync(tmpLink); } catch (_) {}
  fs.symlinkSync(targetVersionDir, tmpLink);
  fs.renameSync(tmpLink, currentLink);
}

// Best-effort refresh of /Applications/OpenAra.app from a staged bundle.
// Stages a sibling copy via cp -R, then atomically renames the old bundle
// aside, renames the new one in, and removes the old. lsregister is poked
// so Launch Services updates its bundle-id -> path mapping.
//
// All failures (permission denied, hardened-bundle protection, etc.) are
// logged and swallowed: the launcher's ~/.openara/current fallback still
// points at the freshly-extracted bundle, so updates aren't lost.
function setPreferHomeMarker(reason) {
  try {
    fs.mkdirSync(root, { recursive: true });
    fs.writeFileSync(preferHomeMarker, JSON.stringify({ reason, at: Date.now() }, null, 2));
  } catch (_) {}
}

function clearPreferHomeMarker() {
  try { fs.unlinkSync(preferHomeMarker); } catch (_) {}
}

function refreshApplicationsCopy(stagedApp) {
  const target = "/Applications/OpenAra.app";
  const stagingPath = path.join("/Applications", \`.OpenAra.app.staging-\${process.pid}\`);
  const oldPath = path.join("/Applications", \`.OpenAra.app.old-\${process.pid}\`);
  const lsregister = "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister";

  try {
    fs.accessSync("/Applications", fs.constants.W_OK);
  } catch (_) {
    log("/Applications not writable; skipping refresh (launcher will use ~/.openara/current)");
    setPreferHomeMarker("applications-not-writable");
    return;
  }

  let oldRelocated = false;
  try {
    fs.rmSync(stagingPath, { recursive: true, force: true });
    const cpResult = spawnSync("/bin/cp", ["-R", stagedApp, stagingPath], { stdio: "ignore" });
    if (cpResult.status !== 0) {
      log(\`cp -R into /Applications staging failed status=\${cpResult.status}\`);
      fs.rmSync(stagingPath, { recursive: true, force: true });
      setPreferHomeMarker("cp-staging-failed");
      return;
    }

    if (fs.existsSync(target)) {
      try {
        fs.rmSync(oldPath, { recursive: true, force: true });
        fs.renameSync(target, oldPath);
        oldRelocated = true;
      } catch (err) {
        log(\`could not rename existing /Applications/OpenAra.app aside: \${err.message}\`);
        fs.rmSync(stagingPath, { recursive: true, force: true });
        setPreferHomeMarker("rename-existing-failed");
        return;
      }
    }

    try {
      fs.renameSync(stagingPath, target);
    } catch (err) {
      log(\`rename staging -> /Applications/OpenAra.app failed: \${err.message}\`);
      if (oldRelocated) {
        try { fs.renameSync(oldPath, target); } catch (_) {}
      }
      fs.rmSync(stagingPath, { recursive: true, force: true });
      setPreferHomeMarker("rename-staging-failed");
      return;
    }

    if (oldRelocated) {
      fs.rmSync(oldPath, { recursive: true, force: true });
    }

    if (fs.existsSync(lsregister)) {
      spawnSync(lsregister, ["-f", target], { stdio: "ignore" });
    }

    clearPreferHomeMarker();
    log("refreshed /Applications/OpenAra.app");
  } catch (err) {
    log(\`refresh /Applications failed: \${(err && err.message) || err}\`);
    try { fs.rmSync(stagingPath, { recursive: true, force: true }); } catch (_) {}
    if (oldRelocated && !fs.existsSync(target)) {
      try { fs.renameSync(oldPath, target); } catch (_) {}
    }
    setPreferHomeMarker("unexpected-error");
  }
}

function cleanupOldVersions(keepVersion) {
  try {
    for (const entry of fs.readdirSync(versionsDir)) {
      if (entry === keepVersion || entry.endsWith(".tmp")) continue;
      fs.rmSync(path.join(versionsDir, entry), { recursive: true, force: true });
    }
  } catch (_) {}
}

async function main() {
  if (process.env.OPENARA_AUTO_UPDATE === "off") {
    return;
  }
  if (process.platform !== "darwin") {
    return;
  }

  const check = readCheck();
  const lastCheckedAt = Number(check.checkedAt || 0);
  if (
    Date.now() - lastCheckedAt < CHECK_INTERVAL_MS &&
    check.installedVersion === installedVersion &&
    !process.env.OPENARA_AUTO_UPDATE_FORCE
  ) {
    return;
  }

  let metadata;
  try {
    metadata = await fetchJSON(REGISTRY_URL);
  } catch (err) {
    log(\`registry fetch failed: \${err.message}\`);
    writeCheck({ ...check, checkedAt: Date.now(), installedVersion, lastError: err.message });
    return;
  }

  const latestVersion = metadata.version;
  const tarballURL = metadata.dist && metadata.dist.tarball;
  if (!latestVersion || !tarballURL) {
    log(\`malformed registry response\`);
    writeCheck({ ...check, checkedAt: Date.now(), installedVersion });
    return;
  }

  if (compareSemver(latestVersion, installedVersion) <= 0) {
    writeCheck({ checkedAt: Date.now(), installedVersion, latestVersion });
    return;
  }

  const targetVersionDir = path.join(versionsDir, latestVersion);
  const targetApp = path.join(targetVersionDir, "dist", "OpenAra.app");
  if (fs.existsSync(path.join(targetApp, "Contents", "Info.plist"))) {
    swapSymlink(targetVersionDir);
    refreshApplicationsCopy(targetApp);
    writeCheck({ checkedAt: Date.now(), installedVersion, latestVersion, stagedAt: Date.now() });
    log(\`re-linked to already-staged \${latestVersion}\`);
    return;
  }

  log(\`downloading \${PACKAGE_NAME}@\${latestVersion}\`);
  let tarball;
  try {
    tarball = await fetchBuffer(tarballURL);
  } catch (err) {
    log(\`tarball fetch failed: \${err.message}\`);
    writeCheck({ ...check, checkedAt: Date.now(), installedVersion, latestVersion, lastError: err.message });
    return;
  }

  fs.mkdirSync(downloadsDir, { recursive: true });
  fs.mkdirSync(versionsDir, { recursive: true });
  const tarballPath = path.join(downloadsDir, \`openara-cli-\${latestVersion}.tgz\`);
  fs.writeFileSync(tarballPath, tarball);

  const stagingDir = path.join(versionsDir, \`\${latestVersion}.tmp-\${process.pid}\`);
  fs.rmSync(stagingDir, { recursive: true, force: true });
  fs.mkdirSync(stagingDir, { recursive: true });

  const tarResult = spawnSync("/usr/bin/tar", ["-xzf", tarballPath, "-C", stagingDir, "--strip-components=1"], {
    stdio: "ignore",
  });
  if (tarResult.status !== 0) {
    log(\`tar extract failed status=\${tarResult.status}\`);
    fs.rmSync(stagingDir, { recursive: true, force: true });
    writeCheck({ ...check, checkedAt: Date.now(), installedVersion, latestVersion, lastError: "tar failed" });
    return;
  }

  const stagedApp = path.join(stagingDir, "dist", "OpenAra.app");
  if (!fs.existsSync(path.join(stagedApp, "Contents", "Info.plist"))) {
    log("staged tarball missing OpenAra.app");
    fs.rmSync(stagingDir, { recursive: true, force: true });
    writeCheck({ ...check, checkedAt: Date.now(), installedVersion, latestVersion, lastError: "missing app bundle" });
    return;
  }

  spawnSync("/usr/bin/xattr", ["-dr", "com.apple.quarantine", stagedApp], { stdio: "ignore" });

  fs.rmSync(targetVersionDir, { recursive: true, force: true });
  fs.renameSync(stagingDir, targetVersionDir);

  swapSymlink(targetVersionDir);
  refreshApplicationsCopy(path.join(targetVersionDir, "dist", "OpenAra.app"));
  cleanupOldVersions(latestVersion);
  try { fs.unlinkSync(tarballPath); } catch (_) {}

  writeCheck({ checkedAt: Date.now(), installedVersion, latestVersion, stagedAt: Date.now() });
  log(\`staged \${latestVersion}; next launch will use it\`);
}

main().catch((err) => {
  log(\`unexpected error: \${(err && err.stack) || err}\`);
});
`;
}

function renderPostinstall(packageName, version) {
  return `#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import * as fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const mcpConfig = ${JSON.stringify({
  mcpServers: {
    "openara": {
      command: "openara",
      args: ["mcp"],
    },
  },
}, null, 2)};

const packageRoot = path.resolve(__dirname, "..");
const sourceApp = path.join(packageRoot, "dist", "OpenAra.app");
const targetApp = "/Applications/OpenAra.app";
const lsregister = "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister";

function safeRun(label, cmd, args) {
  try {
    const result = spawnSync(cmd, args, { stdio: "ignore" });
    return result.status === 0;
  } catch (_error) {
    return false;
  }
}

function installAppBundle() {
  if (process.platform !== "darwin") return false;
  if (!fs.existsSync(sourceApp)) return false;

  try {
    if (fs.existsSync(targetApp)) {
      fs.rmSync(targetApp, { recursive: true, force: true });
    }
    spawnSync("/bin/cp", ["-R", sourceApp, targetApp], { stdio: "ignore" });
    if (!fs.existsSync(path.join(targetApp, "Contents", "Info.plist"))) {
      return false;
    }
    if (fs.existsSync(lsregister)) {
      safeRun("lsregister", lsregister, ["-f", targetApp]);
    }
    return true;
  } catch (_error) {
    return false;
  }
}

const installed = installAppBundle();

const lines = [
  "",
  "Installed ${packageName}@${version}.",
  "Package: https://www.npmjs.com/package/${packageName}",
  "Command: openara",
];
if (process.platform === "darwin") {
  if (installed) {
    lines.push("Installed " + targetApp + " for permission attribution.");
  } else {
    lines.push("Note: could not copy OpenAra.app to /Applications/. macOS System Settings may show a blank icon for the OpenAra TCC entry. Manual fix: cp -R " + sourceApp + " " + targetApp);
  }
}
lines.push(
  "",
  "Next:",
  "1. Run: openara",
  "2. Grant Accessibility + Screen Recording in the onboarding window",
  "3. Wire it into your agent: openara install-claude-mcp (or cursor-mcp / codex-mcp / gemini-mcp / opencode-mcp)",
  "",
  "Manual MCP config (if your client doesn't have an installer):",
  JSON.stringify(mcpConfig, null, 2),
  "",
);
for (const line of lines) {
  console.log(line);
}
`;
}

function renderReadme(packageName, version) {
  return `# ${packageName}

npm distribution for **OpenAra** — the open-source macOS Computer Use MCP server.

This package bundles a universal macOS runtime and the Node launcher selects the current \`process.platform\` / \`process.arch\` at runtime:

${runtimeTargets.map((runtimeTarget) => `- \`${runtimeTarget.os}-${runtimeTarget.cpu}\``).join("\n")}

Exposes a single global command:

- \`openara\`

## Install

\`\`\`bash
npm install -g ${packageName}
\`\`\`

The root launcher resolves the current \`process.platform\` / \`process.arch\` pair and runs the matching bundled native runtime.

## MCP config

If your MCP client accepts a stdio-style \`mcpServers\` JSON config, this is the default setup:

\`\`\`json
{
  "mcpServers": {
    "openara": {
      "command": "openara",
      "args": ["mcp"]
    }
  }
}
\`\`\`

Package page: https://www.npmjs.com/package/${packageName}

## Use

\`\`\`bash
openara --version
openara --help
openara mcp
openara call list_apps

# macOS permission check and onboarding
openara doctor

# Installer helpers for MCP-capable CLIs
openara install-claude-mcp
openara install-cursor-mcp
openara install-gemini-mcp
openara install-gemini-mcp --scope user
openara install-codex-mcp
openara install-opencode-mcp
openara install-codex-plugin
\`\`\`

## Notes

- Version: \`${version}\`
- Supported npm platforms: \`darwin-arm64\`, \`darwin-x64\` (macOS only).
- Requires \`Accessibility\` and \`Screen Recording\` permissions; \`openara doctor\` walks you through granting them.

Source repository: https://github.com/Aradotso/OpenAra
`;
}

function packageKeywords(extraKeywords = []) {
  return [
    "openara",
    "computer-use",
    "codex",
    "mcp",
    "macos",
    "automation",
    ...extraKeywords,
  ];
}

function renderMetaPackageJson(packageName, version) {
  return {
    name: packageName,
    version,
    description: "OpenAra — open-source macOS Computer Use MCP server. After install, run openara mcp.",
    license: "MIT",
    homepage: "https://github.com/Aradotso/OpenAra",
    repository: {
      type: "git",
      url: "git+https://github.com/Aradotso/OpenAra.git",
    },
    bugs: {
      url: "https://github.com/Aradotso/OpenAra/issues",
    },
    keywords: packageKeywords(),
    preferGlobal: true,
    publishConfig: {
      access: "public",
    },
    bin: {
      "openara": "bin/openara",
    },
    scripts: {
      postinstall: "node ./scripts/postinstall.mjs",
    },
    files: [
      ".agents/plugins/marketplace.json",
      "bin/",
      "dist/OpenAra.app/",
      "plugins/openara/.codex-plugin/",
      "plugins/openara/.mcp.json",
      "plugins/openara/assets/",
      "plugins/openara/scripts/",
      "scripts/install-claude-mcp.sh",
      "scripts/install-cursor-mcp.sh",
      "scripts/install-gemini-mcp.sh",
      "scripts/install-config-helper.mjs",
      "scripts/install-codex-mcp.sh",
      "scripts/install-opencode-mcp.sh",
      "scripts/install-codex-plugin.sh",
      "scripts/postinstall.mjs",
      "scripts/auto-update.mjs",
      "README.md",
      "LICENSE",
    ],
  };
}

function copyInstallerScripts(packageRoot) {
  cpSync(path.join(repoRoot, "scripts", "install-claude-mcp.sh"), path.join(packageRoot, "scripts", "install-claude-mcp.sh"));
  cpSync(path.join(repoRoot, "scripts", "install-cursor-mcp.sh"), path.join(packageRoot, "scripts", "install-cursor-mcp.sh"));
  cpSync(path.join(repoRoot, "scripts", "install-gemini-mcp.sh"), path.join(packageRoot, "scripts", "install-gemini-mcp.sh"));
  cpSync(path.join(repoRoot, "scripts", "install-config-helper.mjs"), path.join(packageRoot, "scripts", "install-config-helper.mjs"));
  cpSync(path.join(repoRoot, "scripts", "install-codex-mcp.sh"), path.join(packageRoot, "scripts", "install-codex-mcp.sh"));
  cpSync(path.join(repoRoot, "scripts", "install-opencode-mcp.sh"), path.join(packageRoot, "scripts", "install-opencode-mcp.sh"));
  cpSync(path.join(repoRoot, "scripts", "install-codex-plugin.sh"), path.join(packageRoot, "scripts", "install-codex-plugin.sh"));

  for (const scriptName of [
    "install-claude-mcp.sh",
    "install-cursor-mcp.sh",
    "install-gemini-mcp.sh",
    "install-codex-mcp.sh",
    "install-opencode-mcp.sh",
    "install-codex-plugin.sh",
  ]) {
    chmodSync(path.join(packageRoot, "scripts", scriptName), 0o755);
  }
}

function assertFileExists(filePath, packageName) {
  if (!existsSync(filePath)) {
    throw new Error(`Missing artifact for ${packageName}: ${filePath}. Run without --skip-build first.`);
  }
}

function copyBundledRuntimes(packageRoot, packageName) {
  const distRoot = path.join(packageRoot, "dist");
  mkdirSync(distRoot, { recursive: true });

  const macosSourcePath = path.join(repoRoot, "dist", appBundleName);
  const macosDestinationPath = path.join(distRoot, appBundleName);
  assertFileExists(macosSourcePath, packageName);
  cpSync(macosSourcePath, macosDestinationPath, { recursive: true });

  for (const runtimeTarget of runtimeTargets) {
    const executablePath = path.join(packageRoot, ...runtimeTarget.executablePath);
    assertFileExists(executablePath, packageName);
  }
}

function stageDirNameFor(packageName) {
  return packageName.replace(/^@/, "").replace(/\//g, "-");
}

function stageMetaPackage(packageName, version, outDir) {
  const packageRoot = path.join(outDir, stageDirNameFor(packageName));
  rmSync(packageRoot, { recursive: true, force: true });

  mkdirSync(path.join(packageRoot, ".agents", "plugins"), { recursive: true });
  mkdirSync(path.join(packageRoot, "bin"), { recursive: true });
  mkdirSync(path.join(packageRoot, "dist"), { recursive: true });
  mkdirSync(path.join(packageRoot, "plugins"), { recursive: true });
  mkdirSync(path.join(packageRoot, "scripts"), { recursive: true });

  cpSync(path.join(repoRoot, ".agents", "plugins", "marketplace.json"), path.join(packageRoot, ".agents", "plugins", "marketplace.json"));
  cpSync(path.join(repoRoot, "plugins", "openara"), path.join(packageRoot, "plugins", "openara"), {
    recursive: true,
  });
  cpSync(path.join(repoRoot, "LICENSE"), path.join(packageRoot, "LICENSE"));
  copyBundledRuntimes(packageRoot, packageName);
  copyInstallerScripts(packageRoot);

  const launcher = renderLauncher();
  writeExecutable(path.join(packageRoot, "bin", "openara"), launcher);
  writeFileSync(path.join(packageRoot, "scripts", "postinstall.mjs"), renderPostinstall(packageName, version), "utf-8");
  writeFileSync(path.join(packageRoot, "scripts", "auto-update.mjs"), renderAutoUpdater(packageName), "utf-8");
  writeFileSync(path.join(packageRoot, "README.md"), renderReadme(packageName, version), "utf-8");
  writeFileSync(path.join(packageRoot, "package.json"), `${JSON.stringify(renderMetaPackageJson(packageName, version), null, 2)}\n`, "utf-8");

  removeJunkFiles(packageRoot);
}

function stagePackage(packageName, version, outDir) {
  if (!metaPackageNames.includes(packageName)) {
    throw new Error(`Unsupported package name: ${packageName}`);
  }

  stageMetaPackage(packageName, version, outDir);
}

function main() {
  const options = parseArgs(process.argv.slice(2));
  const pluginManifestPath = path.join(repoRoot, "plugins", "openara", ".codex-plugin", "plugin.json");
  const { version } = readJSON(pluginManifestPath);

  if (!options.skipBuild) {
    ensureBuilt(options.configuration, options.arch);
  }

  rmSync(options.outDir, { recursive: true, force: true });
  mkdirSync(options.outDir, { recursive: true });

  for (const packageName of options.packageNames) {
    stagePackage(packageName, version, options.outDir);
  }

  process.stdout.write(`${options.outDir}\n`);
}

main();
