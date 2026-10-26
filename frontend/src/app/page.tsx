import { useTranslations } from "next-intl";

import { BackendStatus } from "@/components/backend-status";
import { Card, CardContent } from "@/components/ui/card";

export default function Home() {
  const t = useTranslations("HomePage");

  return (
    <main className="mx-auto flex w-full max-w-3xl flex-1 flex-col gap-6 px-6 py-16">
      <h1 className="text-3xl font-semibold tracking-tight">{t("title")}</h1>
      <Card>
        <CardContent>
          <BackendStatus />
        </CardContent>
      </Card>
    </main>
  );
}
