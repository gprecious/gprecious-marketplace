import { google } from "googleapis";
import { loadConfig } from "./config";

const androidpublisher = google.androidpublisher("v3");

let authClient: any = null;

async function getAuth() {
  if (authClient) return authClient;
  const c = loadConfig();
  const auth = new google.auth.GoogleAuth({
    keyFile: c.android.serviceAccountPath,
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });
  authClient = await auth.getClient();
  google.options({ auth: authClient });
  return authClient;
}

export interface PlayTrackRelease {
  name: string | null;
  versionCodes: string[];
  status: string;
  userFraction: number | null;
}

export interface PlayTrackInfo {
  track: string;
  releases: PlayTrackRelease[];
}

export async function getTrackInfo(track?: string): Promise<PlayTrackInfo> {
  await getAuth();
  const c = loadConfig();
  const targetTrack = track ?? c.android.track;
  const res = await androidpublisher.edits.insert({ packageName: c.android.packageName });
  const editId = res.data.id!;

  try {
    const trackRes = await androidpublisher.edits.tracks.get({
      packageName: c.android.packageName,
      editId,
      track: targetTrack,
    });
    return {
      track: targetTrack,
      releases: (trackRes.data.releases ?? []).map((r) => ({
        name: r.name ?? null,
        versionCodes: (r.versionCodes ?? []).map(String),
        status: r.status ?? "unknown",
        userFraction: r.userFraction ?? null,
      })),
    };
  } finally {
    await androidpublisher.edits.delete({
      packageName: c.android.packageName,
      editId,
    });
  }
}

export async function promoteToProduction(
  versionCode: string,
  userFraction?: number
): Promise<void> {
  await getAuth();
  const c = loadConfig();
  const res = await androidpublisher.edits.insert({ packageName: c.android.packageName });
  const editId = res.data.id!;

  const releaseConfig: any = {
    versionCodes: [versionCode],
    status: userFraction ? "inProgress" : "completed",
  };
  if (userFraction) releaseConfig.userFraction = userFraction;

  await androidpublisher.edits.tracks.update({
    packageName: c.android.packageName,
    editId,
    track: "production",
    requestBody: { track: "production", releases: [releaseConfig] },
  });
  await androidpublisher.edits.commit({ packageName: c.android.packageName, editId });
}

export async function getProductionTrackInfo(): Promise<PlayTrackInfo> {
  return getTrackInfo("production");
}

export async function getInternalTrackInfo(): Promise<PlayTrackInfo> {
  return getTrackInfo("internal");
}
