import {
  handleStoreAppleRefreshToken,
  jsonResponse,
  liveStoreDeps,
  withWebCors,
} from "../_shared/apple_account.ts";

Deno.serve(async (req) => {
  try {
    return await handleStoreAppleRefreshToken(req, liveStoreDeps());
  } catch {
    console.error("store-apple-refresh-token failed");
    return withWebCors(req, jsonResponse({ stored: false }, 200));
  }
});
