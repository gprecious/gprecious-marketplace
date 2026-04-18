import { existsSync, readFileSync } from "fs";
import { dirname, isAbsolute, resolve } from "path";

export interface LocaleInfo {
  title?: string;
  subtitle?: string;
  description?: string;
  shortDescription?: string;
  fullDescription?: string;
  keywords?: string | string[];
  privacyPolicyUrl?: string;
  supportUrl?: string;
  screenshotCaptions?: string[];
}

export interface StoreConfig {
  apple?: {
    info: Record<string, LocaleInfo>;
    categories?: string[];
    ageRating?: Record<string, unknown>;
    advisory?: Record<string, unknown>;
  };
  android?: {
    info: Record<string, LocaleInfo>;
  };
  screenshots?: {
    template?: string;
    backgroundColor?: string;
    accentColor?: string;
    fontFamily?: string;
    sizes?: Record<string, [number, number]>;
  };
}

export interface ReleaseConfig {
  stack: "expo" | "capacitor" | "flutter";
  appName: string;
  projectRoot: string;
  ios: {
    bundleId: string;
    ascAppId: string;
    ascKeyId: string;
    ascIssuerId: string;
    ascKeyPath: string;
  };
  android: {
    packageName: string;
    serviceAccountPath: string;
    track: string;
  };
  paths: {
    fastlane: string;
    screenshotsSource: string;
    screenshotsOutput: string;
    screenshotTemplates: string;
    logs: string;
  };
  store: StoreConfig;
  expoAppJson?: { name: string; version: string };
  expo?: {
    appJsonPath?: string;
    easJsonPath?: string;
    submit?: { platform?: string; profile?: string; autoSubmit?: boolean };
  };
  capacitor?: {
    iosProjectPath?: string;
    iosScheme?: string;
    androidProjectPath?: string;
    androidTask?: string;
  };
}

export function findProjectRoot(startDir: string = process.cwd()): string | null {
  const override = process.env.RELEASE_PROJECT_ROOT;
  if (override) return resolve(override);

  let dir = resolve(startDir);
  while (true) {
    if (existsSync(resolve(dir, "release.config.json"))) return dir;
    const parent = dirname(dir);
    if (parent === dir) return null;
    dir = parent;
  }
}

function resolveUnder(root: string, p: string | undefined, fallback: string): string {
  const target = p ?? fallback;
  return isAbsolute(target) ? target : resolve(root, target);
}

export function loadConfig(startDir: string = process.cwd()): ReleaseConfig {
  const root = findProjectRoot(startDir);
  if (!root) {
    throw new Error(
      `release.config.json not found (searched from ${startDir}). ` +
        `Create one at your project root or set RELEASE_PROJECT_ROOT.`
    );
  }

  const raw = JSON.parse(readFileSync(resolve(root, "release.config.json"), "utf-8"));

  let expoAppJson: { name: string; version: string } | undefined;
  if (raw.stack === "expo") {
    const appJsonPath = resolve(root, raw.expo?.appJsonPath ?? "app.json");
    if (existsSync(appJsonPath)) {
      const appJson = JSON.parse(readFileSync(appJsonPath, "utf-8"));
      expoAppJson = {
        name: appJson.expo?.name ?? raw.appName,
        version: appJson.expo?.version ?? "0.0.0",
      };
      raw.appName ??= appJson.expo?.name;
      raw.ios ??= {};
      raw.ios.bundleId ??= appJson.expo?.ios?.bundleIdentifier;
      raw.android ??= {};
      raw.android.packageName ??= appJson.expo?.android?.package;
    }
  }

  const paths = raw.paths ?? {};
  const ios = raw.ios ?? {};
  const android = raw.android ?? {};

  const required: [string, unknown][] = [
    ["stack", raw.stack],
    ["appName", raw.appName],
    ["ios.bundleId", ios.bundleId],
    ["ios.ascAppId", ios.ascAppId],
    ["ios.ascKeyId", ios.ascKeyId],
    ["ios.ascIssuerId", ios.ascIssuerId],
    ["ios.ascKeyPath", ios.ascKeyPath],
    ["android.packageName", android.packageName],
    ["android.serviceAccountPath", android.serviceAccountPath],
  ];
  for (const [key, val] of required) {
    if (!val) throw new Error(`release.config.json: missing required field '${key}'`);
  }

  return {
    stack: raw.stack,
    appName: raw.appName,
    projectRoot: root,
    ios: {
      bundleId: ios.bundleId,
      ascAppId: ios.ascAppId,
      ascKeyId: ios.ascKeyId,
      ascIssuerId: ios.ascIssuerId,
      ascKeyPath: resolveUnder(root, ios.ascKeyPath, "./keys/asc-api-key.p8"),
    },
    android: {
      packageName: android.packageName,
      serviceAccountPath: resolveUnder(
        root,
        android.serviceAccountPath,
        "./keys/google-play-service-account.json"
      ),
      track: android.track ?? "internal",
    },
    paths: {
      fastlane: resolveUnder(root, paths.fastlane, "./fastlane"),
      screenshotsSource: resolveUnder(root, paths.screenshotsSource, "./screenshots/raw"),
      screenshotsOutput: resolveUnder(root, paths.screenshotsOutput, "./fastlane/screenshots"),
      screenshotTemplates: resolveUnder(root, paths.screenshotTemplates, "./screenshots/templates"),
      logs: resolveUnder(root, paths.logs, "./.release-logs"),
    },
    store: raw.store ?? {},
    expoAppJson,
    expo: raw.expo,
    capacitor: raw.capacitor,
  };
}
