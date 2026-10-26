import { describe, expect, it } from "vitest";

import { resolveBackendStatus } from "./backend-status";

describe("resolveBackendStatus", () => {
  it("returns ok for HTTP 200", () => {
    expect(resolveBackendStatus({ status: 200 })).toBe("ok");
  });

  it.each([404, 500, 503])("returns unavailable for HTTP %i", (status) => {
    expect(resolveBackendStatus({ status })).toBe("unavailable");
  });

  it("returns unavailable for a network error", () => {
    expect(resolveBackendStatus({ networkError: true })).toBe("unavailable");
  });
});
