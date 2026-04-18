import { execFileSync } from "child_process";
import { readFileSync } from "fs";
import { resolve } from "path";
import { loadConfig } from "../lib/config";
import { runFastlane } from "../lib/fastlane";
import type { BuildOpts, BuildResult, StackAdapter, SubmitResult, VersionInfo } from "./types";

function parseIosVersion(projectRoot: string, iosProjectPath: string): VersionInfo {
  const pbx = readFileSync(
    resolve(projectRoot, iosProjectPath, "App.xcodeproj/project.pbxproj"),
    "utf-8"
  );
  const marketing =
    pbx.match(/MARKETING_VERSION = ([^;]+);/)?.[1]?.trim().replace(/"/g, "") ?? "0.0.0";
  const current =
    pbx.match(/CURRENT_PROJECT_VERSION = ([^;]+);/)?.[1]?.trim().replace(/"/g, "") ?? "1";
  return { version: marketing, buildNumber: current };
}

function parseAndroidVersion(projectRoot: string, androidProjectPath: string): VersionInfo {
  const gradle = readFileSync(
    resolve(projectRoot, androidProjectPath, "app/build.gradle"),
    "utf-8"
  );
  const versionName = gradle.match(/versionName\s+["']([^"']+)["']/)?.[1] ?? "0.0.0";
  const versionCode = gradle.match(/versionCode\s+(\d+)/)?.[1] ?? "1";
  return { version: versionName, buildNumber: versionCode };
}

export const capacitorAdapter: StackAdapter = {
  name: "capacitor",

  async detectVersion(): Promise<VersionInfo> {
    const cfg = loadConfig();
    if (!cfg.capacitor?.iosProjectPath || !cfg.capacitor?.androidProjectPath) {
      throw new Error(
        "release.config.json.capacitor.iosProjectPath and androidProjectPath are required"
      );
    }
    const ios = parseIosVersion(cfg.projectRoot, cfg.capacitor.iosProjectPath);
    const android = parseAndroidVersion(cfg.projectRoot, cfg.capacitor.androidProjectPath);
    if (ios.version !== android.version) {
      console.warn(`iOS version ${ios.version} != Android version ${android.version}`);
    }
    return ios;
  },

  async build(platform, opts: BuildOpts = {}): Promise<BuildResult> {
    const cfg = loadConfig();
    const cap = cfg.capacitor!;

    if (platform === "ios" || platform === "all") {
      execFileSync("npx", ["cap", "sync", "ios"], { cwd: cfg.projectRoot, stdio: "inherit" });
      const iosPath = resolve(cfg.projectRoot, cap.iosProjectPath!);
      const scheme = cap.iosScheme ?? "App";
      execFileSync(
        "xcodebuild",
        [
          "-workspace", "App.xcworkspace",
          "-scheme", scheme,
          "-configuration", "Release",
          "-archivePath", "build/App.xcarchive",
          "archive",
        ],
        { cwd: iosPath, stdio: "inherit" }
      );
    }

    if (platform === "android" || platform === "all") {
      execFileSync("npx", ["cap", "sync", "android"], { cwd: cfg.projectRoot, stdio: "inherit" });
      const androidPath = resolve(cfg.projectRoot, cap.androidProjectPath!);
      const task = cap.androidTask ?? "bundleRelease";
      execFileSync("./gradlew", [task], { cwd: androidPath, stdio: "inherit" });
    }

    const submitted = opts.autoSubmit ?? false;
    if (submitted) {
      if (platform === "ios" || platform === "all") runFastlane("ios", "deliver");
      if (platform === "android" || platform === "all") runFastlane("android", "supply");
    }

    return { platform, buildIds: [], submitted };
  },

  async submit(platform, _artifactPath): Promise<SubmitResult> {
    if (platform === "ios") runFastlane("ios", "deliver");
    else runFastlane("android", "supply");
    return { platform, submitted: true };
  },
};
