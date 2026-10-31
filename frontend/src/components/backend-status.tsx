"use client";

import { useTranslations } from "next-intl";
import { useEffect, useState } from "react";

import { Badge } from "@/components/ui/badge";
import { api } from "@/lib/api/client";
import { type BackendState, resolveBackendStatus } from "@/lib/backend-status";

const BADGE_VARIANTS = {
  checking: "outline",
  ok: "default",
  unavailable: "destructive",
} as const satisfies Record<BackendState, string>;

export function BackendStatus() {
  const t = useTranslations("BackendStatus");
  const [status, setStatus] = useState<BackendState>("checking");

  useEffect(() => {
    let cancelled = false;

    async function check() {
      let next: BackendState;
      try {
        const { response } = await api.GET("/api/health");
        next = resolveBackendStatus({ status: response.status });
      } catch {
        // openapi-fetch throws on network errors instead of returning `error`.
        next = resolveBackendStatus({ networkError: true });
      }
      if (!cancelled) {
        setStatus(next);
      }
    }

    void check();

    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <Badge aria-live="polite" variant={BADGE_VARIANTS[status]}>
      {t(status)}
    </Badge>
  );
}
