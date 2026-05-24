export type Platform = "ios" | "android" | "all";

export interface BuildOpts {
  profile?: string;
  autoSubmit?: boolean;
  nonInteractive?: boolean;
  noWait?: boolean;
  /** Build locally on this machine instead of remote cloud builder. */
  local?: boolean;
}

export interface BuildResult {
  platform: Platform;
  buildIds: string[];
  submitted: boolean;
}

export interface SubmitResult {
  platform: "ios" | "android";
  submitted: boolean;
  details?: string;
}

export interface VersionInfo {
  version: string;
  buildNumber: string;
}

export interface StackAdapter {
  name: "expo" | "capacitor" | "flutter";
  build(platform: Platform, opts?: BuildOpts): Promise<BuildResult>;
  submit(platform: "ios" | "android", artifactPath: string): Promise<SubmitResult>;
  detectVersion(): Promise<VersionInfo>;
}
