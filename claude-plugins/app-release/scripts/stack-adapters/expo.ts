import { execFileSync } from "child_process";
import { readFileSync } from "fs";
import { resolve } from "path";
import { loadConfig } from "../lib/config";
import type { BuildOpts, BuildResult, StackAdapter, SubmitResult, VersionInfo } from "./types";

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
