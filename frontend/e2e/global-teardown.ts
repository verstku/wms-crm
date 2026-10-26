import { rm } from "node:fs/promises";
import path from "node:path";

// The e2e build is recreated on every run; stale types in .next-e2e/types could break typecheck.
export default async function globalTeardown(): Promise<void> {
  await rm(path.resolve(__dirname, "../.next-e2e"), {
    recursive: true,
    force: true,
  });
}
