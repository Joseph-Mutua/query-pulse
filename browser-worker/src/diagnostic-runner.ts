import { chromium, type Request } from "playwright";
import { mkdir } from "node:fs/promises";
import { randomUUID } from "node:crypto";
import path from "node:path";
import { UrlPolicy } from "./url-policy.js";

export type Classification =
  | "NORMAL"
  | "EMPTY_RESULTS"
  | "UNEXPECTED_LAYOUT"
  | "CHALLENGE_DETECTED"
  | "TIMEOUT"
  | "NETWORK_FAILURE"
  | "HTTP_ERROR";

export interface DiagnosticResult {
  status: Classification;
  http_status: number | null;
  load_time_ms: number;
  page_title: string;
  screenshot_path: string | null;
  html_snapshot_path: string | null;
  challenge_detected: boolean;
  network_errors: string[];
}

export class DiagnosticRunner {
  constructor(
    private readonly policy: UrlPolicy,
    private readonly artifactRoot = path.resolve("artifacts"),
  ) {}

  async run(rawUrl: string): Promise<DiagnosticResult> {
    const url = await this.policy.validate(rawUrl);
    const runId = randomUUID();
    const outputDir = path.join(this.artifactRoot, runId);
    await mkdir(outputDir, { recursive: true });
    const browser = await chromium.launch({ headless: true });
    const page = await browser.newPage({
      viewport: { width: 1440, height: 1000 },
    });
    const networkErrors: string[] = [];
    await page.route("**/*", async (route) => {
      try {
        await this.policy.validate(route.request().url());
        await route.continue();
      } catch {
        networkErrors.push(`BLOCKED ${safeOrigin(route.request().url())}`);
        await route.abort("blockedbyclient");
      }
    });
    page.on("requestfailed", (request: Request) =>
      networkErrors.push(
        `${request.method()} ${safeOrigin(request.url())}: ${request.failure()?.errorText ?? "failed"}`,
      ),
    );
    const started = performance.now();

    try {
      const response = await page.goto(url.toString(), {
        waitUntil: "domcontentloaded",
        timeout: 15_000,
      });
      const loadTime = Math.round(performance.now() - started);
      const httpStatus = response?.status() ?? null;
      const title = await page.title();
      const bodyText = (await page.locator("body").innerText())
        .slice(0, 20_000)
        .toLowerCase();
      const challenge =
        /captcha|verify you are human|unusual traffic|access denied/.test(
          bodyText,
        );
      const screenshotPath = path.join(outputDir, "page.png");
      const htmlPath = path.join(outputDir, "page.html");
      await page.screenshot({ path: screenshotPath, fullPage: true });
      await BunlessWrite(htmlPath, await page.content());
      const resultCount = await page
        .locator("[data-organic-result], .organic-result, #search .g")
        .count();
      const status: Classification = challenge
        ? "CHALLENGE_DETECTED"
        : httpStatus && httpStatus >= 400
          ? "HTTP_ERROR"
          : resultCount === 0
            ? bodyText.includes("no results")
              ? "EMPTY_RESULTS"
              : "UNEXPECTED_LAYOUT"
            : "NORMAL";
      return {
        status,
        http_status: httpStatus,
        load_time_ms: loadTime,
        page_title: title,
        screenshot_path: screenshotPath,
        html_snapshot_path: htmlPath,
        challenge_detected: challenge,
        network_errors: networkErrors.slice(0, 50),
      };
    } catch (error) {
      const message =
        error instanceof Error ? error.message : "unknown browser error";
      const status: Classification = message.includes("Timeout")
        ? "TIMEOUT"
        : "NETWORK_FAILURE";
      return {
        status,
        http_status: null,
        load_time_ms: Math.round(performance.now() - started),
        page_title: "",
        screenshot_path: null,
        html_snapshot_path: null,
        challenge_detected: false,
        network_errors: [...networkErrors, message].slice(0, 50),
      };
    } finally {
      await browser.close();
    }
  }
}

async function BunlessWrite(file: string, content: string): Promise<void> {
  const { writeFile } = await import("node:fs/promises");
  await writeFile(file, content, { encoding: "utf8", flag: "wx" });
}

function safeOrigin(input: string): string {
  try {
    return new URL(input).origin;
  } catch {
    return "invalid-url";
  }
}
