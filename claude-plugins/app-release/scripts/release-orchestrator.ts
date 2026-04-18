import { loadConfig } from "./lib/config";
import { emitJson, emitError } from "./lib/logger";
import { expoAdapter } from "./stack-adapters/expo";
import { capacitorAdapter } from "./stack-adapters/capacitor";
import { flutterAdapter } from "./stack-adapters/flutter";
import type { StackAdapter, Platform } from "./stack-adapters/types";

function pickAdapter(name: string): StackAdapter {
  switch (name) {
    case "expo":
      return expoAdapter;
    case "capacitor":
      return capacitorAdapter;
    case "flutter":
      return flutterAdapter;
    default:
      throw new Error(`Unsupported stack: ${name}`);
  }
}

async function main() {
  const args = process.argv.slice(2);
  const platform = (args.find((a) => ["ios", "android", "all"].includes(a)) ?? "all") as Platform;
  const noSubmit = args.includes("--no-submit");

  const cfg = loadConfig();
  const adapter = pickAdapter(cfg.stack);

  const version = await adapter.detectVersion();
  emitJson({ phase: "detect", stack: adapter.name, ...version });

  const build = await adapter.build(platform, { autoSubmit: !noSubmit });
  emitJson({ phase: "build", ...build });
}

main().catch((e: any) => {
  emitError(e.message);
  process.exit(1);
});
