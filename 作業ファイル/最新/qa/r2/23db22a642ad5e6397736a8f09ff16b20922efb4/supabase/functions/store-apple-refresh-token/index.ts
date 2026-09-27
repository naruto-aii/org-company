import {
  handleStoreAppleRefreshToken,
  jsonResponse,
  liveStoreDeps,
} from "../_shared/apple_account.ts";

Deno.serve(async (req) => {
  try {
    return await handleStoreAppleRefreshToken(req, liveStoreDeps());
  } catch {
    console.error("store-apple-refresh-token failed");
    return jsonResponse({ stored: false }, 200);
  }
});
