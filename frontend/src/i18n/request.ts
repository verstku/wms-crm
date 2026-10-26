import { getRequestConfig } from "next-intl/server";

import { defaultLocale } from "./config";

// No locale in the URL yet: every request uses the default locale.
export default getRequestConfig(async () => ({
  locale: defaultLocale,
  messages: (await import(`../../messages/${defaultLocale}.json`)).default,
}));
