export type BackendState = "checking" | "ok" | "unavailable";

export type HealthCheckResult = { status: number } | { networkError: true };

export function resolveBackendStatus(
  result: HealthCheckResult,
): Exclude<BackendState, "checking"> {
  return "status" in result && result.status === 200 ? "ok" : "unavailable";
}
