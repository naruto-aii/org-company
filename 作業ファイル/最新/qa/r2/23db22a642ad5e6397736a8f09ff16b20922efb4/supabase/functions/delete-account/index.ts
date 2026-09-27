import {
  handleDeleteAccount,
  jsonResponse,
  liveDeleteDeps,
} from "../_shared/apple_account.ts";

Deno.serve(async (req) => {
  try {
    return await handleDeleteAccount(req, liveDeleteDeps());
  } catch {
    console.error("delete-account failed");
    return jsonResponse({ ok: false }, 500);
  }
});
