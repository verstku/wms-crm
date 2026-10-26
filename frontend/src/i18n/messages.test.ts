import { describe, expect, it } from "vitest";

import en from "../../messages/en.json";
import ru from "../../messages/ru.json";

function flattenKeys(messages: object, prefix = ""): string[] {
  return Object.entries(messages).flatMap(([key, value]) =>
    typeof value === "object" && value !== null
      ? flattenKeys(value, `${prefix}${key}.`)
      : [`${prefix}${key}`],
  );
}

describe("messages", () => {
  it("ru and en have the same keys", () => {
    expect(flattenKeys(en).sort()).toEqual(flattenKeys(ru).sort());
  });

  it("flattens nested keys", () => {
    expect(flattenKeys(ru)).toContain("BackendStatus.ok");
  });
});
