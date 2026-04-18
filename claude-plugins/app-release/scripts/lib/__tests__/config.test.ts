import { describe, it, expect } from "vitest";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";
import { findProjectRoot, loadConfig } from "../config";

const __dirname = dirname(fileURLToPath(import.meta.url));
const FIXTURES = resolve(__dirname, "fixtures");

describe("findProjectRoot", () => {
  it("finds release.config.json in the given directory", () => {
    const root = findProjectRoot(resolve(FIXTURES, "expo-project"));
    expect(root).toBe(resolve(FIXTURES, "expo-project"));
  });

  it("walks up until it finds release.config.json", () => {
    const deep = resolve(FIXTURES, "expo-project", "nested", "deeper");
    const root = findProjectRoot(deep);
    expect(root).toBe(resolve(FIXTURES, "expo-project"));
  });

  it("returns null if no release.config.json exists", () => {
    const root = findProjectRoot(resolve(FIXTURES, "no-config"));
    expect(root).toBe(null);
  });

  it("honours RELEASE_PROJECT_ROOT env override", () => {
    const override = resolve(FIXTURES, "expo-project");
    process.env.RELEASE_PROJECT_ROOT = override;
    try {
      expect(findProjectRoot(resolve(FIXTURES, "no-config"))).toBe(override);
    } finally {
      delete process.env.RELEASE_PROJECT_ROOT;
    }
  });
});

describe("loadConfig", () => {
  it("loads explicit fields from release.config.json", () => {
    const cfg = loadConfig(resolve(FIXTURES, "expo-project"));
    expect(cfg.stack).toBe("expo");
    expect(cfg.ios.ascAppId).toBe("1234567890");
    expect(cfg.android.packageName).toBe("com.test.app");
  });

  it("resolves key paths as absolute", () => {
    const cfg = loadConfig(resolve(FIXTURES, "expo-project"));
    expect(cfg.ios.ascKeyPath).toBe(resolve(FIXTURES, "expo-project", "keys/asc-api-key.p8"));
    expect(cfg.android.serviceAccountPath).toBe(
      resolve(FIXTURES, "expo-project", "keys/play.json")
    );
  });

  it("applies defaults for paths when not set", () => {
    const cfg = loadConfig(resolve(FIXTURES, "expo-project"));
    expect(cfg.paths.fastlane).toBe(resolve(FIXTURES, "expo-project", "fastlane"));
  });

  it("exposes app.json info via expoAppJson for expo stack", () => {
    const cfg = loadConfig(resolve(FIXTURES, "expo-project"));
    expect(cfg.expoAppJson?.name).toBe("TestAppFromAppJson");
    expect(cfg.expoAppJson?.version).toBe("2.0.0");
  });

  it("throws a clear error when release.config.json is missing", () => {
    expect(() => loadConfig(resolve(FIXTURES, "no-config"))).toThrow(
      /release\.config\.json not found/
    );
  });
});
