import type { StackAdapter } from "./types";

const NOT_IMPLEMENTED =
  "Flutter stack adapter is not implemented yet. Contribute at https://github.com/gprecious/gprecious-marketplace/issues.";

export const flutterAdapter: StackAdapter = {
  name: "flutter",
  async detectVersion() {
    throw new Error(NOT_IMPLEMENTED);
  },
  async build() {
    throw new Error(NOT_IMPLEMENTED);
  },
  async submit() {
    throw new Error(NOT_IMPLEMENTED);
  },
};
