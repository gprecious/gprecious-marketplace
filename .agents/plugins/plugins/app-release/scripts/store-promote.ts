import {
  getAppStoreVersion,
  createPhasedRelease,
  releaseImmediately,
} from "./lib/asc-client";
import { getInternalTrackInfo, promoteToProduction } from "./lib/play-client";
import { emitJson, emitError } from "./lib/logger";

const args = process.argv.slice(2);
const platform = args.find((a) => a.startsWith("--platform="))?.split("=")[1] ?? "all";
const releaseType = args.find((a) => a.startsWith("--release-type="))?.split("=")[1] ?? "immediate";
const fraction = parseFloat(
  args.find((a) => a.startsWith("--fraction="))?.split("=")[1] ?? "1.0"
);

async function promoteIos() {
  const version = await getAppStoreVersion();
  if (!version) {
    emitError("No app store version found");
    process.exit(1);
  }

  if (version.appStoreState !== "PENDING_DEVELOPER_RELEASE") {
    emitError(`Cannot promote: current state is ${version.appStoreState}`, {
      hint: "Version must be in PENDING_DEVELOPER_RELEASE state",
    });
    process.exit(1);
  }

  if (releaseType === "phased") {
    await createPhasedRelease(version.id);
    emitJson({ platform: "ios", action: "phased_release", version: version.versionString });
  } else {
    await releaseImmediately(version.id);
    emitJson({ platform: "ios", action: "immediate_release", version: version.versionString });
  }
}

async function promoteAndroid() {
  const internal = await getInternalTrackInfo();
  const latest = internal.releases?.[0];

  if (!latest || !latest.versionCodes?.[0]) {
    emitError("No internal track release found");
    process.exit(1);
  }

  const versionCode = latest.versionCodes[0];
  const userFraction = fraction < 1.0 ? fraction : undefined;

  await promoteToProduction(versionCode, userFraction);
  emitJson({
    platform: "android",
    action: userFraction ? "staged_rollout" : "full_release",
    versionCode,
    userFraction: userFraction ?? 1.0,
  });
}

async function main() {
  if (platform === "ios" || platform === "all") await promoteIos();
  if (platform === "android" || platform === "all") await promoteAndroid();
}

main().catch((e: any) => {
  emitError(e.message);
  process.exit(1);
});
