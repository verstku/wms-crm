import createClient from "openapi-fetch";

import type { paths } from "./schema";

// No baseUrl: the browser calls relative /api/... paths, Next.js rewrites them to the backend.
export const api = createClient<paths>();
