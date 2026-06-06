#!/usr/bin/env node
import { spawn } from "node:child_process";
import { createServer } from "node:net";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { pathToFileURL } from "node:url";

const args = parseArgs(process.argv.slice(2));
const input = args.input;
const output = args.output;
const width = Number.parseInt(args.width || "1400", 10);
const maxHeight = Number.parseInt(args.maxHeight || args["max-height"] || "30000", 10);

if (
  !input ||
  !output ||
  !Number.isFinite(width) ||
  width <= 0 ||
  !Number.isFinite(maxHeight) ||
  maxHeight <= 0
) {
  console.error("Usage: html-fullpage-screenshot.mjs --input FILE.html --output FILE.png [--width PX] [--max-height PX]");
  process.exit(2);
}

const chromePath = findChrome();
if (!chromePath) {
  console.error("Google Chrome or Chromium was not found. Set CHROME_BIN to the browser executable path.");
  process.exit(1);
}

const port = await getFreePort();
const userDataDir = await mkdtemp(path.join(tmpdir(), "quicklook-preview-chrome."));
const chrome = spawn(chromePath, [
  "--headless=new",
  "--disable-gpu",
  "--disable-background-networking",
  "--disable-component-update",
  "--disable-default-apps",
  "--disable-dev-shm-usage",
  "--disable-extensions",
  "--disable-sync",
  "--hide-scrollbars",
  "--no-default-browser-check",
  "--no-first-run",
  "--remote-debugging-address=127.0.0.1",
  `--remote-debugging-port=${port}`,
  `--user-data-dir=${userDataDir}`,
  "about:blank",
], {
  stdio: ["ignore", "ignore", "pipe"],
});

let stderr = "";
chrome.stderr.on("data", (chunk) => {
  stderr += chunk.toString();
});

try {
  await waitForDevTools(port);
  const target = await createTarget(port);
  const client = await connectCdp(target.webSocketDebuggerUrl);
  const fileUrl = pathToFileURL(path.resolve(input)).href;

  await client.send("Page.enable");
  await client.send("Runtime.enable");

  const loadEvent = client.waitFor("Page.loadEventFired", 15000);
  await client.send("Page.navigate", { url: fileUrl });
  await loadEvent.catch(() => {});

  await client.send("Runtime.evaluate", {
    expression: "document.fonts ? document.fonts.ready : Promise.resolve()",
    awaitPromise: true,
  }).catch(() => {});

  const height = await getDocumentHeight(client, width);
  await client.send("Emulation.setDeviceMetricsOverride", {
    mobile: false,
    width,
    height,
    deviceScaleFactor: 1,
    screenWidth: width,
    screenHeight: height,
  });

  const screenshot = await client.send("Page.captureScreenshot", {
    format: "png",
    fromSurface: true,
    captureBeyondViewport: true,
    clip: { x: 0, y: 0, width, height, scale: 1 },
  });

  await writeFile(output, Buffer.from(screenshot.data, "base64"));
  await client.close();
} catch (error) {
  console.error(error?.message || String(error));
  if (stderr.trim()) {
    console.error(stderr.trim());
  }
  process.exitCode = 1;
} finally {
  chrome.kill("SIGTERM");
  await waitForExit(chrome, 10000).catch(() => {
    chrome.kill("SIGKILL");
  });
  await rm(userDataDir, { recursive: true, force: true }).catch(() => {});
}

function parseArgs(rawArgs) {
  const parsed = {};

  for (let i = 0; i < rawArgs.length; i += 1) {
    const arg = rawArgs[i];
    if (!arg.startsWith("--")) {
      continue;
    }

    const key = arg.slice(2);
    const value = rawArgs[i + 1];
    if (!value || value.startsWith("--")) {
      parsed[key] = "true";
    } else {
      parsed[key] = value;
      i += 1;
    }
  }

  return parsed;
}

function findChrome() {
  const candidates = [
    process.env.CHROME_BIN,
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
  ].filter(Boolean);

  return candidates.find((candidate) => existsSync(candidate));
}

async function getFreePort() {
  const server = createServer();
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", resolve);
  });

  const address = server.address();
  const portNumber = address.port;
  await new Promise((resolve) => server.close(resolve));
  return portNumber;
}

async function waitForDevTools(portNumber) {
  const deadline = Date.now() + 60000;
  let lastError;

  while (Date.now() < deadline) {
    try {
      const response = await fetch(`http://127.0.0.1:${portNumber}/json/version`);
      if (response.ok) {
        return;
      }
    } catch (error) {
      lastError = error;
    }

    await delay(100);
  }

  throw new Error(`Chrome DevTools did not start in time: ${lastError?.message || "timeout"}`);
}

async function createTarget(portNumber) {
  const response = await fetch(`http://127.0.0.1:${portNumber}/json/new?about:blank`, {
    method: "PUT",
  });

  if (!response.ok) {
    throw new Error(`Could not create Chrome target: HTTP ${response.status}`);
  }

  return response.json();
}

async function connectCdp(wsUrl) {
  const ws = new WebSocket(wsUrl);
  const callbacks = new Map();
  const waiters = new Map();
  let nextId = 1;

  await new Promise((resolve, reject) => {
    ws.addEventListener("open", resolve, { once: true });
    ws.addEventListener("error", reject, { once: true });
  });

  ws.addEventListener("message", (event) => {
    const message = JSON.parse(event.data);

    if (message.id && callbacks.has(message.id)) {
      const { resolve, reject } = callbacks.get(message.id);
      callbacks.delete(message.id);

      if (message.error) {
        reject(new Error(message.error.message));
      } else {
        resolve(message.result || {});
      }
      return;
    }

    if (message.method && waiters.has(message.method)) {
      for (const waiter of waiters.get(message.method)) {
        waiter.resolve(message.params || {});
      }
      waiters.delete(message.method);
    }
  });

  return {
    send(method, params = {}) {
      const id = nextId;
      nextId += 1;
      ws.send(JSON.stringify({ id, method, params }));
      return new Promise((resolve, reject) => {
        callbacks.set(id, { resolve, reject });
      });
    },
    waitFor(method, timeoutMs) {
      return new Promise((resolve, reject) => {
        const timeout = setTimeout(() => {
          const current = waiters.get(method) || [];
          waiters.set(method, current.filter((waiter) => waiter.resolve !== resolve));
          reject(new Error(`Timed out waiting for ${method}`));
        }, timeoutMs);

        const current = waiters.get(method) || [];
        current.push({
          resolve(value) {
            clearTimeout(timeout);
            resolve(value);
          },
        });
        waiters.set(method, current);
      });
    },
    close() {
      ws.close();
    },
  };
}

async function getDocumentHeight(client, viewportWidth) {
  await client.send("Emulation.setDeviceMetricsOverride", {
    mobile: false,
    width: viewportWidth,
    height: 1000,
    deviceScaleFactor: 1,
    screenWidth: viewportWidth,
    screenHeight: 1000,
  });

  const result = await client.send("Runtime.evaluate", {
    returnByValue: true,
    expression: `(() => {
      const body = document.body || {};
      const html = document.documentElement || {};
      const height = Math.ceil(Math.max(
        body.scrollHeight || 0,
        body.offsetHeight || 0,
        html.clientHeight || 0,
        html.scrollHeight || 0,
        html.offsetHeight || 0
      ));
      return Math.max(1, Math.min(height, ${maxHeight}));
    })()`,
  });

  return result.result.value;
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function waitForExit(process, timeoutMs) {
  if (process.exitCode !== null || process.signalCode !== null) {
    return Promise.resolve();
  }

  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => reject(new Error("Timed out waiting for Chrome to exit")), timeoutMs);
    process.once("exit", () => {
      clearTimeout(timeout);
      resolve();
    });
  });
}
