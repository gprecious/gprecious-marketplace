import { execFileSync } from "child_process";
import { loadConfig } from "./config";

export function runFastlane(platform: "ios" | "android", lane: string, args: string[] = []): void {
  const c = loadConfig();
  execFileSync("bundle", ["exec", "fastlane", platform, lane, ...args], {
    cwd: c.projectRoot,
    stdio: "inherit",
    env: { ...process.env, FASTLANE_HIDE_CHANGELOG: "1" },
  });
}
