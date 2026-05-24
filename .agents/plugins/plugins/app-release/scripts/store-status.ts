import { getAppStoreVersion, getReviewSubmission } from "./lib/asc-client";
import { getInternalTrackInfo, getProductionTrackInfo } from "./lib/play-client";
import { emitJson } from "./lib/logger";

async function getIosStatus() {
  const version = await getAppStoreVersion();
  if (!version) {
    return { version: null, state: "NO_VERSION", reviewState: null, isRejected: false };
  }
  const review = await getReviewSubmission(version.id);
  return {
    version: version.versionString,
    state: version.appStoreState,
    reviewState: review?.state ?? null,
    isRejected: version.appStoreState === "REJECTED",
  };
}

async function getAndroidStatus() {
  const [internal, production] = await Promise.all([
    getInternalTrackInfo().catch(() => null),
    getProductionTrackInfo().catch(() => null),
  ]);
  const latestInternal = internal?.releases?.[0];
  const latestProduction = production?.releases?.[0];
  return {
    internal: {
      versionCode: latestInternal?.versionCodes?.[0] ?? null,
      status: latestInternal?.status ?? "none",
    },
    production: {
      versionCode: latestProduction?.versionCodes?.[0] ?? null,
      status: latestProduction?.status ?? "none",
      userFraction: latestProduction?.userFraction ?? null,
    },
  };
}

async function main() {
  const [ios, android] = await Promise.all([
    getIosStatus().catch((e: any) => ({
      version: null,
      state: `ERROR: ${e.message}`,
      reviewState: null,
      isRejected: false,
    })),
    getAndroidStatus().catch((e: any) => ({
      internal: { versionCode: null, status: `ERROR: ${e.message}` },
      production: { versionCode: null, status: `ERROR: ${e.message}`, userFraction: null },
    })),
  ]);
  emitJson({ ios, android });
}

main();
