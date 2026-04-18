import { execFileSync } from "child_process";
import { mkdirSync, readFileSync } from "fs";
import { resolve } from "path";
import { loadConfig } from "../lib/config";
import type { BuildOpts, BuildResult, Platform, StackAdapter, SubmitResult, VersionInfo } from "./types";

function localBuild(
  projectRoot: string,
  platform: Platform,
  profile: string,
  autoSubmit: boolean
): BuildResult {
  const buildDir = resolve(projectRoot, "build");
  mkdirSync(buildDir, { recursive: true });

  const targets: Array<{ plat: "ios" | "android"; ext: "ipa" | "aab" }> =
    platform === "all"
      ? [
          { plat: "ios", ext: "ipa" },
          { plat: "android", ext: "aab" },
        ]
      : platform === "ios"
        ? [{ plat: "ios", ext: "ipa" }]
        : [{ plat: "android", ext: "aab" }];

  for (const { plat, ext } of targets) {
    const out = resolve(buildDir, `app.${ext}`);
    execFileSync(
      "eas",
      [
        "build",
        "--local",
        "--platform", plat,
        "--profile", profile,
        "--non-interactive",
        "--output", out,
      ],
      { cwd: projectRoot, stdio: "inherit" }
    );
    if (autoSubmit) {
      execFileSync(
        "eas",
        ["submit", "--platform", plat, "--path", out, "--non-interactive"],
        { cwd: projectRoot, stdio: "inherit" }
      );
    }
  }

  return { platform, buildIds: [], submitted: autoSubmit };
}

export const expoAdapter: StackAdapter = {
  name: "expo",

  async detectVersion(): Promise<VersionInfo> {
    const cfg = loadConfig();
    const appJsonPath = resolve(cfg.projectRoot, cfg.expo?.appJsonPath ?? "app.json");
    const appJson = JSON.parse(readFileSync(appJsonPath, "utf-8"));
    return {
      version: appJson.expo?.version ?? "0.0.0",
      buildNumber:
        appJson.expo?.ios?.buildNumber ?? String(appJson.expo?.android?.versionCode ?? "0"),
    };
  },

  async build(platform, opts: BuildOpts = {}): Promise<BuildResult> {
    const cfg = loadConfig();
    const profile = opts.profile ?? cfg.expo?.submit?.profile ?? "production";
    const autoSubmit = opts.autoSubmit ?? cfg.expo?.submit?.autoSubmit ?? true;

    if (opts.local) {
      return localBuild(cfg.projectRoot, platform, profile, autoSubmit);
    }

    const args = ["build", "--platform", platform, "--profile", profile];
    if (autoSubmit) args.push("--auto-submit");
    if (opts.nonInteractive ?? true) args.push("--non-interactive");
    if (opts.noWait ?? true) args.push("--no-wait");
    args.push("--json");

    const out = execFileSync("eas", args, {
      cwd: cfg.projectRoot,
      encoding: "utf-8",
    });

    let buildIds: string[] = [];
    try {
      const parsed = JSON.parse(out);
      buildIds = Array.isArray(parsed) ? parsed.map((b: any) => b.id).filter(Boolean) : [];
    } catch {
      // eas --no-wait may not return parseable JSON on all versions
    }

    return { platform, buildIds, submitted: autoSubmit };
  },

  async submit(platform, artifactPath): Promise<SubmitResult> {
    const cfg = loadConfig();
    const args = ["submit", "--platform", platform, "--non-interactive"];
    if (artifactPath !== "auto") args.push("--path", artifactPath);
    execFileSync("eas", args, { cwd: cfg.projectRoot, stdio: "inherit" });
    return { platform, submitted: true };
  },
};
