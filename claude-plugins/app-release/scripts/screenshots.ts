import sharp from "sharp";
import { readdirSync, mkdirSync, existsSync } from "fs";
import { join } from "path";
import { loadConfig } from "./lib/config";
import { runFastlane } from "./lib/fastlane";
import { emitJson, emitError } from "./lib/logger";

const args = process.argv.slice(2);
const shouldGenerate = args.includes("--generate") || !args.includes("--upload");
const shouldUpload = args.includes("--upload");

interface ScreenshotSize {
  name: string;
  width: number;
  height: number;
}

const DEFAULT_SIZES: ScreenshotSize[] = [
  { name: "iphone67", width: 1290, height: 2796 },
  { name: "iphone65", width: 1242, height: 2688 },
  { name: "android", width: 1080, height: 1920 },
];

function getScreenshotSettings() {
  const cfg = loadConfig();
  const settings = cfg.store.screenshots ?? {};
  const fontFamily = settings.fontFamily ?? "Pretendard";
  const backgroundColor = settings.backgroundColor ?? "#0a0a1a";

  const sizes: ScreenshotSize[] = settings.sizes
    ? Object.entries(settings.sizes).map(([name, [w, h]]) => ({ name, width: w, height: h }))
    : DEFAULT_SIZES;

  const captions: Record<string, string[]> = {};
  const appleInfo = cfg.store.apple?.info ?? {};
  const androidInfo = cfg.store.android?.info ?? {};
  for (const [locale, data] of Object.entries(appleInfo) as [string, any][]) {
    if (data.screenshotCaptions) captions[locale] = data.screenshotCaptions;
  }
  for (const [locale, data] of Object.entries(androidInfo) as [string, any][]) {
    if (!captions[locale] && data.screenshotCaptions) captions[locale] = data.screenshotCaptions;
  }
  return { fontFamily, backgroundColor, sizes, captions };
}

function escapeXml(str: string): string {
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function createCaptionSvg(text: string, width: number, fontFamily: string): string {
  const fontSize = Math.round(width * 0.045);
  const svgHeight = Math.round(fontSize * 2.5);
  return `<svg width="${width}" height="${svgHeight}" xmlns="http://www.w3.org/2000/svg">
    <style>.caption { font-family: '${fontFamily}', sans-serif; font-size: ${fontSize}px; font-weight: 700; fill: white; text-anchor: middle; }</style>
    <text x="${width / 2}" y="${svgHeight * 0.65}" class="caption">${escapeXml(text)}</text>
  </svg>`;
}

function hexToRgb(hex: string): { r: number; g: number; b: number } {
  const n = parseInt(hex.replace("#", ""), 16);
  return { r: (n >> 16) & 255, g: (n >> 8) & 255, b: n & 255 };
}

async function generateOne(
  sourcePath: string,
  outputPath: string,
  size: ScreenshotSize,
  caption: string,
  fontFamily: string,
  backgroundColor: string
) {
  const bg = hexToRgb(backgroundColor);
  const captionAreaHeight = Math.round(size.height * 0.15);
  const appScreenHeight = size.height - captionAreaHeight;
  const appScreenWidth = Math.round(size.width * 0.85);
  const appScreenX = Math.round((size.width - appScreenWidth) / 2);

  const resized = await sharp(sourcePath)
    .resize(appScreenWidth, appScreenHeight, { fit: "contain", background: bg })
    .png()
    .toBuffer();

  const captionSvg = createCaptionSvg(caption, size.width, fontFamily);

  await sharp({
    create: {
      width: size.width,
      height: size.height,
      channels: 4,
      background: { ...bg, alpha: 1 },
    },
  })
    .composite([
      { input: Buffer.from(captionSvg), top: Math.round(captionAreaHeight * 0.1), left: 0 },
      { input: resized, top: captionAreaHeight, left: appScreenX },
    ])
    .png()
    .toFile(outputPath);
}

async function generate() {
  const cfg = loadConfig();
  const { fontFamily, backgroundColor, sizes, captions } = getScreenshotSettings();
  const sourceDir = join(cfg.paths.screenshotsSource, "ko");

  if (!existsSync(sourceDir)) {
    emitError(`Source screenshots not found: ${sourceDir}`);
    process.exit(1);
  }

  const sources = readdirSync(sourceDir).filter((f) => f.endsWith(".png")).sort();
  const results: any[] = [];
  const androidMetadata = join(cfg.paths.fastlane, "metadata/android");

  for (const size of sizes) {
    for (const [locale, localeCaptions] of Object.entries(captions)) {
      const outputDir =
        size.name === "android"
          ? join(androidMetadata, locale, "images", "phoneScreenshots")
          : join(cfg.paths.screenshotsOutput, locale);
      mkdirSync(outputDir, { recursive: true });

      for (let i = 0; i < sources.length; i++) {
        const caption = localeCaptions[i] ?? "";
        const outputFile = join(outputDir, `${i + 1}_${locale}.png`);
        await generateOne(
          join(sourceDir, sources[i]),
          outputFile,
          size,
          caption,
          fontFamily,
          backgroundColor
        );
        results.push({ size: size.name, locale, source: sources[i], output: outputFile, caption });
      }
    }
  }
  emitJson({ generated: results.length, files: results });
}

function upload() {
  console.log("Uploading iOS screenshots via Fastlane...");
  runFastlane("ios", "upload_screenshots");
  console.log("Uploading Android screenshots via Fastlane...");
  runFastlane("android", "upload_screenshots");
  emitJson({ uploaded: true });
}

async function main() {
  if (shouldGenerate) await generate();
  if (shouldUpload) upload();
}

main().catch((e: any) => {
  emitError(e.message);
  process.exit(1);
});
