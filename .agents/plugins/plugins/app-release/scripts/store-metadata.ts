import { readFileSync, writeFileSync, mkdirSync } from "fs";
import { join } from "path";
import {
  getAppStoreVersion,
  updateVersionLocalizations,
  AscLocaleUpdate,
} from "./lib/asc-client";
import { loadConfig } from "./lib/config";
import { emitJson, emitError } from "./lib/logger";

const args = process.argv.slice(2);
const dryRun = !args.includes("--apply");

interface MetadataDiff {
  platform: string;
  locale: string;
  field: string;
  current: string;
  updated: string;
}

function syncAndroidMetadata(): MetadataDiff[] {
  const cfg = loadConfig();
  const diffs: MetadataDiff[] = [];
  const androidInfo = cfg.store.android?.info ?? {};
  const androidMetadataPath = join(cfg.paths.fastlane, "metadata/android");

  for (const [locale, data] of Object.entries(androidInfo) as [string, any][]) {
    const localeDir = join(androidMetadataPath, locale);
    mkdirSync(localeDir, { recursive: true });

    const fields: [string, string, string | undefined][] = [
      ["title.txt", "title", data.title],
      ["short_description.txt", "shortDescription", data.shortDescription],
      ["full_description.txt", "fullDescription", data.fullDescription],
    ];

    for (const [file, field, value] of fields) {
      if (!value) continue;
      const filePath = join(localeDir, file);
      let current = "";
      try {
        current = readFileSync(filePath, "utf-8").trim();
      } catch {}
      if (current !== value.trim()) {
        diffs.push({
          platform: "android",
          locale,
          field,
          current: current.slice(0, 100),
          updated: value.trim().slice(0, 100),
        });
        if (!dryRun) writeFileSync(filePath, value.trim() + "\n", "utf-8");
      }
    }
  }

  return diffs;
}

async function syncIosMetadata(): Promise<MetadataDiff[]> {
  const cfg = loadConfig();
  const diffs: MetadataDiff[] = [];
  const appleInfo = cfg.store.apple?.info ?? {};

  const version = await getAppStoreVersion();
  if (!version) {
    emitError("No iOS version found to update");
    return diffs;
  }

  const updates: AscLocaleUpdate[] = [];
  for (const [locale, data] of Object.entries(appleInfo) as [string, any][]) {
    const update: AscLocaleUpdate = { locale };
    if (data.description) {
      update.description = data.description;
      diffs.push({
        platform: "ios",
        locale,
        field: "description",
        current: "(from ASC)",
        updated: data.description.slice(0, 100),
      });
    }
    if (data.keywords) {
      const kw = Array.isArray(data.keywords) ? data.keywords.join(", ") : data.keywords;
      update.keywords = kw;
      diffs.push({
        platform: "ios",
        locale,
        field: "keywords",
        current: "(from ASC)",
        updated: kw,
      });
    }
    if (data.subtitle) {
      update.subtitle = data.subtitle;
      diffs.push({
        platform: "ios",
        locale,
        field: "subtitle",
        current: "(from ASC)",
        updated: data.subtitle,
      });
    }
    updates.push(update);
  }

  if (!dryRun && updates.length > 0) {
    await updateVersionLocalizations(version.id, updates);
  }

  return diffs;
}

async function main() {
  const androidDiffs = syncAndroidMetadata();
  let iosDiffs: MetadataDiff[] = [];
  let iosError: string | null = null;
  try {
    iosDiffs = await syncIosMetadata();
  } catch (e: any) {
    iosError = e.message;
  }
  const allDiffs = [...androidDiffs, ...iosDiffs];
  emitJson({
    mode: dryRun ? "dry-run" : "applied",
    changes: allDiffs,
    totalChanges: allDiffs.length,
    ...(iosError && { iosError }),
  });
}

main().catch((e: any) => {
  emitError(e.message);
  process.exit(1);
});
