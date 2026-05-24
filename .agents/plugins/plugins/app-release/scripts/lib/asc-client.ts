import { readFileSync } from "fs";
import jwt from "jsonwebtoken";
import { loadConfig } from "./config";

const ASC_BASE = "https://api.appstoreconnect.apple.com/v1";

function cfg() {
  return loadConfig();
}

function generateJwt(): string {
  const c = cfg();
  const privateKey = readFileSync(c.ios.ascKeyPath, "utf-8");
  const now = Math.floor(Date.now() / 1000);
  return jwt.sign(
    { iss: c.ios.ascIssuerId, iat: now, exp: now + 20 * 60, aud: "appstoreconnect-v1" },
    privateKey,
    { algorithm: "ES256", header: { alg: "ES256", kid: c.ios.ascKeyId, typ: "JWT" } }
  );
}

async function ascFetch(path: string, options: RequestInit = {}): Promise<any> {
  const token = generateJwt();
  const res = await fetch(`${ASC_BASE}${path}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      ...options.headers,
    },
    signal: AbortSignal.timeout(30_000),
  });
  if (res.status === 429) {
    const retryAfter = parseInt(res.headers.get("Retry-After") ?? "5", 10);
    await new Promise((r) => setTimeout(r, retryAfter * 1000));
    return ascFetch(path, options);
  }
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`ASC API ${res.status}: ${body}`);
  }
  return res.json();
}

export interface AscVersionInfo {
  id: string;
  versionString: string;
  appStoreState: string;
  releaseType: string | null;
}

function compareVersions(a: string, b: string): number {
  const pa = a.split(".").map((n) => parseInt(n, 10) || 0);
  const pb = b.split(".").map((n) => parseInt(n, 10) || 0);
  const len = Math.max(pa.length, pb.length);
  for (let i = 0; i < len; i++) {
    const da = pa[i] ?? 0;
    const db = pb[i] ?? 0;
    if (da !== db) return db - da;
  }
  return 0;
}

export async function getAppStoreVersion(): Promise<AscVersionInfo | null> {
  const c = cfg();
  const data = await ascFetch(
    `/apps/${c.ios.ascAppId}/appStoreVersions?filter[platform]=IOS&limit=20`
  );
  const versions = (data.data ?? []) as any[];
  if (versions.length === 0) return null;
  versions.sort((a, b) =>
    compareVersions(a.attributes.versionString, b.attributes.versionString)
  );
  const ver = versions[0];
  return {
    id: ver.id,
    versionString: ver.attributes.versionString,
    appStoreState: ver.attributes.appStoreState,
    releaseType: ver.attributes.releaseType,
  };
}

export interface AscReviewSubmission {
  id: string;
  state: string;
  submittedDate: string | null;
}

export async function getReviewSubmission(versionId: string): Promise<AscReviewSubmission | null> {
  try {
    const data = await ascFetch(`/appStoreVersions/${versionId}/appStoreReviewDetail`);
    const detail = data.data;
    if (!detail) return null;
    return {
      id: detail.id,
      state: detail.attributes?.appStoreReviewState ?? "UNKNOWN",
      submittedDate: detail.attributes?.submittedDate ?? null,
    };
  } catch {
    return null;
  }
}

export interface AscLocaleUpdate {
  locale: string;
  description?: string;
  keywords?: string;
  whatsNew?: string;
  subtitle?: string;
}

export async function updateVersionLocalizations(
  versionId: string,
  updates: AscLocaleUpdate[]
): Promise<void> {
  const data = await ascFetch(`/appStoreVersions/${versionId}/appStoreVersionLocalizations`);
  const existing = data.data as any[];

  for (const update of updates) {
    const loc = existing.find((l: any) => l.attributes.locale === update.locale);
    if (!loc) continue;

    const attributes: Record<string, string> = {};
    if (update.description) attributes.description = update.description;
    if (update.keywords) attributes.keywords = update.keywords;
    if (update.whatsNew) attributes.whatsNew = update.whatsNew;
    if (update.subtitle) attributes.subtitle = update.subtitle;

    await ascFetch(`/appStoreVersionLocalizations/${loc.id}`, {
      method: "PATCH",
      body: JSON.stringify({
        data: { type: "appStoreVersionLocalizations", id: loc.id, attributes },
      }),
    });
  }
}

export async function createPhasedRelease(versionId: string): Promise<void> {
  await ascFetch(`/appStoreVersionPhasedReleases`, {
    method: "POST",
    body: JSON.stringify({
      data: {
        type: "appStoreVersionPhasedReleases",
        attributes: { phasedReleaseState: "ACTIVE" },
        relationships: {
          appStoreVersion: { data: { type: "appStoreVersions", id: versionId } },
        },
      },
    }),
  });
}

export async function releaseImmediately(versionId: string): Promise<void> {
  await ascFetch(`/appStoreVersions/${versionId}`, {
    method: "PATCH",
    body: JSON.stringify({
      data: {
        type: "appStoreVersions",
        id: versionId,
        attributes: { releaseType: "MANUAL" },
      },
    }),
  });
}
